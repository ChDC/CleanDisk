import Foundation

struct ProjectContext: OptionSet {
    let rawValue: Int

    static let android = ProjectContext(rawValue: 1 << 0)
    static let apple = ProjectContext(rawValue: 1 << 1)
    static let rust = ProjectContext(rawValue: 1 << 2)
    static let cmake = ProjectContext(rawValue: 1 << 3)
    static let nativeShell = ProjectContext(rawValue: 1 << 4)
    static let node = ProjectContext(rawValue: 1 << 5)
    static let python = ProjectContext(rawValue: 1 << 6)
    static let go = ProjectContext(rawValue: 1 << 7)
    static let java = ProjectContext(rawValue: 1 << 8)
    static let dotnet = ProjectContext(rawValue: 1 << 9)
    static let flutter = ProjectContext(rawValue: 1 << 10)

    var primaryKind: ProjectKind? {
        if contains(.nativeShell) { return .nativeShell }
        if contains(.android) { return .android }
        if contains(.apple) { return .apple }
        if contains(.flutter) { return .flutter }
        if contains(.node) { return .node }
        if contains(.python) { return .python }
        if contains(.dotnet) { return .dotnet }
        if contains(.java) { return .java }
        if contains(.go) { return .go }
        if contains(.rust) { return .rust }
        if contains(.cmake) { return .cmake }
        return nil
    }
}

public struct ProjectDiscovery: Sendable {
    public let maximumDepth: Int
    public let home: URL

    public init(maximumDepth: Int = 10, home: URL) {
        self.maximumDepth = maximumDepth
        self.home = home.standardizedFileURL
    }

    func discover(
        roots: [URL],
        cancellation: ScanCancellation,
        progress: @Sendable (String) -> Void
    ) throws -> [ScanCandidate] {
        var candidates: [ScanCandidate] = []
        var visited: Set<String> = []
        let mediaDirectories = ["Movies", "Music", "Pictures", "Public", "Applications", "Library"]
            .map { home.appendingPathComponent($0, isDirectory: true).path }

        for root in roots {
            var pending: [(url: URL, depth: Int, context: ProjectContext)] = [
                (root.standardizedFileURL, 0, [])
            ]
            while let (directory, depth, inheritedContext) = pending.popLast() {
                try cancellation.check()
                guard depth <= maximumDepth else { continue }
                let path = directory.standardizedFileURL.path
                guard visited.insert(path).inserted else { continue }
                guard let values = try? directory.resourceValues(forKeys: [
                    .isDirectoryKey, .isSymbolicLinkKey,
                ]), values.isDirectory == true, values.isSymbolicLink != true else { continue }

                progress(path)
                guard let entries = try? FileManager.default.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .nameKey],
                    options: []
                ) else { continue }

                let names = Set(entries.map(\.lastPathComponent))
                var context = inheritedContext
                if names.contains("nsh.json") { context.insert(.nativeShell) }
                if names.contains("settings.gradle") || names.contains("settings.gradle.kts")
                    || names.contains("build.gradle") || names.contains("build.gradle.kts")
                    || names.contains("gradlew") {
                    context.insert(.android)
                }
                if names.contains("Package.swift") || names.contains(where: {
                    $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace")
                }) {
                    context.insert(.apple)
                }
                if names.contains("Cargo.toml") { context.insert(.rust) }
                if names.contains("CMakeLists.txt") { context.insert(.cmake) }
                if names.contains("package.json") || names.contains("package-lock.json")
                    || names.contains("pnpm-lock.yaml") || names.contains("yarn.lock")
                    || names.contains("bun.lock") || names.contains("bun.lockb") {
                    context.insert(.node)
                }
                if names.contains("pyproject.toml") || names.contains("setup.py")
                    || names.contains("setup.cfg") || names.contains("requirements.txt")
                    || names.contains("Pipfile") {
                    context.insert(.python)
                }
                if names.contains("go.mod") || names.contains("go.work") { context.insert(.go) }
                if names.contains("pom.xml") || names.contains("mvnw") { context.insert(.java) }
                if names.contains(where: {
                    $0.hasSuffix(".sln") || $0.hasSuffix(".csproj")
                        || $0.hasSuffix(".fsproj") || $0.hasSuffix(".vbproj")
                }) {
                    context.insert(.dotnet)
                }
                if names.contains("pubspec.yaml") { context.insert(.flutter) }

                if let kind = context.primaryKind {
                    let groupID = "project.\(directory.path)"
                    let groupTitle = directory.lastPathComponent
                    func add(
                        _ name: String,
                        policy: TargetPolicy = .wholeDirectory,
                        kind explicitKind: ProjectKind? = nil
                    ) {
                        let url = directory.appendingPathComponent(name, isDirectory: true)
                        candidates.append(ScanCandidate(
                            rootURL: url,
                            title: name,
                            groupID: groupID,
                            groupTitle: groupTitle,
                            detail: directory.path,
                            category: .developer,
                            policy: policy,
                            projectKind: explicitKind ?? kind
                        ))
                    }

                    if context.contains(.nativeShell) {
                        add("target")
                        add("native/target")
                        add(".nsh/out", policy: .nativeShellOutput)
                    } else {
                        if context.contains(.rust) { add("target") }
                        if context.contains(.apple) {
                            add(".build")
                            add("DerivedData")
                        }
                        if context.contains(.android) {
                            add(".gradle")
                            add(".cxx")
                        }
                        if context.contains(.android) || context.contains(.apple) || context.contains(.cmake) {
                            add("build")
                        }
                        for name in names where name.hasPrefix("cmake-build-") {
                            add(name)
                        }
                        if context.contains(.node) {
                            for name in Self.nodeGeneratedDirectories { add(name, kind: .node) }
                            add(".yarn/cache", kind: .node)
                        }
                        if context.contains(.python) {
                            for name in Self.pythonGeneratedDirectories { add(name, kind: .python) }
                            for name in names where name.hasSuffix(".egg-info") {
                                add(name, kind: .python)
                            }
                        }
                        if context.contains(.go) { add("bin", kind: .go) }
                        if context.contains(.java) { add("target", kind: .java) }
                        if context.contains(.dotnet) {
                            for name in ["bin", "obj", "TestResults"] { add(name, kind: .dotnet) }
                        }
                        if context.contains(.flutter) {
                            add("build", kind: .flutter)
                            add(".dart_tool", kind: .flutter)
                        }
                    }
                    if context.contains(.nativeShell), context.contains(.node) {
                        for name in Self.nodeGeneratedDirectories { add(name, kind: .node) }
                        add(".yarn/cache", kind: .node)
                    }
                }

                guard depth < maximumDepth else { continue }
                for child in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).reversed() {
                    let name = child.lastPathComponent
                    guard let childValues = try? child.resourceValues(forKeys: [
                        .isDirectoryKey, .isSymbolicLinkKey,
                    ]), childValues.isDirectory == true, childValues.isSymbolicLink != true else { continue }
                    guard !name.hasPrefix("."), !Self.generatedOrDependencyDirectories.contains(name),
                          !mediaDirectories.contains(child.standardizedFileURL.path),
                          !name.hasSuffix(".app"), !name.hasSuffix(".xcodeproj"),
                          !name.hasSuffix(".xcworkspace"), !name.hasPrefix("cmake-build-") else { continue }
                    pending.append((child, depth + 1, context))
                }
            }
        }
        return candidates
    }

    private static let generatedOrDependencyDirectories: Set<String> = [
        "build", "DerivedData", "target", "node_modules", "Carthage", "Pods", "vendor",
        "dist", "coverage", "htmlcov", "__pycache__", "bin", "obj", "TestResults",
    ]

    private static let nodeGeneratedDirectories = [
        "node_modules", "dist", "build", "coverage", ".next", ".nuxt", ".output",
        ".turbo", ".vite", ".parcel-cache", ".rollup.cache", ".swc", ".cache",
        ".expo", ".angular", ".astro", ".svelte-kit", ".docusaurus",
    ]

    private static let pythonGeneratedDirectories = [
        "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache", ".tox", ".nox",
        "build", "dist", "htmlcov",
    ]
}
