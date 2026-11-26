import XCTest
@testable import CleanDiskTrashCore

final class CleanDiskTrashCoreTests: XCTestCase {
    private var temporaryURL = URL(fileURLWithPath: "/")

    override func setUpWithError() throws {
        temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CleanDiskTrashTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryURL)
    }

    func testRequestedCacheRulesAreBuiltIn() {
        let paths = Set(RuleCatalog.rules.map(\.path))
        XCTAssertTrue(paths.contains("~/.npm/_cacache"))
        XCTAssertTrue(paths.contains("~/.cache"))
        XCTAssertTrue(paths.contains("~/Library/Containers/com.apple.wallpaper.agent/Data/Library/Caches"))
        XCTAssertTrue(paths.contains("~/Library/Caches"))
        XCTAssertTrue(paths.contains("~/Library/Developer/Xcode/DerivedData"))
        XCTAssertFalse(paths.contains("~/Library/Developer/Xcode/Archives"))
    }

    func testNativeShellScansIntermediatesButNotPackagedApps() throws {
        let project = temporaryURL.appendingPathComponent("Projects/ShellApp", isDirectory: true)
        try write("nsh.json", "{}", at: project)
        try write("App.tsx", "export {}", at: project)
        try write("target/debug/shell-app", "binary", at: project)
        try write("native/Cargo.toml", "[package]", at: project)
        try write("native/target/debug/native", "binary", at: project)
        try write(".nsh/out/bundle.js", "bundle", at: project)
        try write(".nsh/out/bundle.js.map", "map", at: project)
        try write(".nsh/out/assets/logo.png", "image", at: project)
        try write(".nsh/out/ShellApp.app/Contents/MacOS/ShellApp", "app", at: project)
        try write(".nsh/out/ShellApp.ipa", "ipa", at: project)
        try write(".nsh/out/ShellApp.apk", "apk", at: project)
        try write(".nsh/out/macos/ShellApp.app/Contents/MacOS/ShellApp", "app", at: project)
        try write(".nsh/out/macos/build-info.json", "json", at: project)

        let items = try scan(projectsAt: project)
        let paths = Set(items.map(\.url.path))

        XCTAssertTrue(paths.contains(project.appendingPathComponent("target").path))
        XCTAssertTrue(paths.contains(project.appendingPathComponent("native/target").path))
        XCTAssertTrue(paths.contains(project.appendingPathComponent(".nsh/out/bundle.js").path))
        XCTAssertTrue(paths.contains(project.appendingPathComponent(".nsh/out/bundle.js.map").path))
        XCTAssertTrue(paths.contains(project.appendingPathComponent(".nsh/out/assets").path))
        XCTAssertTrue(paths.contains(project.appendingPathComponent(".nsh/out/macos/build-info.json").path))
        XCTAssertFalse(paths.contains(project.appendingPathComponent(".nsh/out/macos").path))
        XCTAssertFalse(paths.contains { $0.hasSuffix(".app") || $0.hasSuffix(".ipa") || $0.hasSuffix(".apk") })
        XCTAssertEqual(items.filter { $0.url.lastPathComponent == "target" }.count, 2)
        XCTAssertTrue(items.allSatisfy { $0.projectKind == .nativeShell })
    }

    func testAndroidAppleRustAndCMakeBuildDirectories() throws {
        let android = temporaryURL.appendingPathComponent("Projects/AndroidApp", isDirectory: true)
        try write("settings.gradle.kts", "include(\":app\")", at: android)
        try write("app/build/intermediates/classes.dex", "dex", at: android)
        try write(".gradle/configuration-cache/state", "state", at: android)

        let apple = temporaryURL.appendingPathComponent("Projects/AppleApp", isDirectory: true)
        try makeDirectory("Demo.xcodeproj", at: apple)
        try write("build/Intermediates.noindex/object.o", "object", at: apple)
        try write(".build/arm64-apple-macosx/debug/module.swiftmodule", "module", at: apple)

        let rust = temporaryURL.appendingPathComponent("Projects/RustApp", isDirectory: true)
        try write("Cargo.toml", "[package]", at: rust)
        try write("target/debug/rust-app", "binary", at: rust)

        let cmake = temporaryURL.appendingPathComponent("Projects/NativeApp", isDirectory: true)
        try write("CMakeLists.txt", "project(NativeApp)", at: cmake)
        try write("cmake-build-debug/CMakeFiles/object.o", "object", at: cmake)

        let unrelated = temporaryURL.appendingPathComponent("Projects/Notes", isDirectory: true)
        try write("build/important.txt", "keep", at: unrelated)

        let items = try scan(projectsAt: temporaryURL.appendingPathComponent("Projects"))
        let paths = Set(items.map(\.url.path))

        XCTAssertTrue(paths.contains(android.appendingPathComponent("app/build").path))
        XCTAssertTrue(paths.contains(android.appendingPathComponent(".gradle").path))
        XCTAssertTrue(paths.contains(apple.appendingPathComponent("build").path))
        XCTAssertTrue(paths.contains(apple.appendingPathComponent(".build").path))
        XCTAssertTrue(paths.contains(rust.appendingPathComponent("target").path))
        XCTAssertTrue(paths.contains(cmake.appendingPathComponent("cmake-build-debug").path))
        XCTAssertFalse(paths.contains(unrelated.appendingPathComponent("build").path))
        XCTAssertEqual(Set(items.compactMap(\.projectKind)), [.android, .apple, .rust, .cmake])
    }

    func testNodeBuildAndDependencyDirectories() throws {
        let node = temporaryURL.appendingPathComponent("Projects/WebApp", isDirectory: true)
        try write("package.json", #"{"scripts":{"build":"vite build"}}"#, at: node)
        try write("package-lock.json", "{}", at: node)
        try write("node_modules/package/index.js", "dependency", at: node)
        try write("dist/assets/index.js", "bundle", at: node)
        try write(".next/cache/build-cache", "cache", at: node)
        try write(".turbo/cache/output", "cache", at: node)
        try write(".yarn/cache/package.zip", "zip", at: node)
        try write("coverage/lcov.info", "coverage", at: node)
        try write("packages/admin/.svelte-kit/output/app.js", "bundle", at: node)

        let items = try scan(projectsAt: temporaryURL.appendingPathComponent("Projects"))
        let paths = Set(items.map(\.url.path))

        for path in [
            "node_modules", "dist", ".next", ".turbo", ".yarn/cache", "coverage",
            "packages/admin/.svelte-kit",
        ] {
            XCTAssertTrue(paths.contains(node.appendingPathComponent(path).path), "Missing \(path)")
        }
        XCTAssertFalse(paths.contains(node.appendingPathComponent("package-lock.json").path))
        XCTAssertTrue(items.allSatisfy { $0.projectKind == .node })
        XCTAssertEqual(items.filter { $0.url.lastPathComponent == "node_modules" }.count, 1)
    }

    func testPythonGoMavenDotnetAndFlutterBuildDirectories() throws {
        let python = temporaryURL.appendingPathComponent("Projects/PythonApp", isDirectory: true)
        try write("pyproject.toml", "[project]", at: python)
        try write("src/__pycache__/module.pyc", "pyc", at: python)
        try write(".pytest_cache/state", "cache", at: python)
        try write("Example.egg-info/PKG-INFO", "metadata", at: python)

        let go = temporaryURL.appendingPathComponent("Projects/GoApp", isDirectory: true)
        try write("go.mod", "module example.com/app", at: go)
        try write("bin/go-app", "binary", at: go)

        let maven = temporaryURL.appendingPathComponent("Projects/JavaApp", isDirectory: true)
        try write("pom.xml", "<project />", at: maven)
        try write("target/classes/App.class", "class", at: maven)

        let dotnet = temporaryURL.appendingPathComponent("Projects/DotnetApp", isDirectory: true)
        try write("App.csproj", "<Project />", at: dotnet)
        try write("bin/Debug/net10.0/App.dll", "dll", at: dotnet)
        try write("obj/project.assets.json", "assets", at: dotnet)

        let flutter = temporaryURL.appendingPathComponent("Projects/FlutterApp", isDirectory: true)
        try write("pubspec.yaml", "name: app", at: flutter)
        try write("build/app/intermediates/output", "output", at: flutter)
        try write(".dart_tool/package_config.json", "packages", at: flutter)

        let items = try scan(projectsAt: temporaryURL.appendingPathComponent("Projects"))
        let paths = Set(items.map(\.url.path))

        XCTAssertTrue(paths.contains(python.appendingPathComponent("src/__pycache__").path))
        XCTAssertTrue(paths.contains(python.appendingPathComponent(".pytest_cache").path))
        XCTAssertTrue(paths.contains(python.appendingPathComponent("Example.egg-info").path))
        XCTAssertTrue(paths.contains(go.appendingPathComponent("bin").path))
        XCTAssertTrue(paths.contains(maven.appendingPathComponent("target").path))
        XCTAssertTrue(paths.contains(dotnet.appendingPathComponent("bin").path))
        XCTAssertTrue(paths.contains(dotnet.appendingPathComponent("obj").path))
        XCTAssertTrue(paths.contains(flutter.appendingPathComponent("build").path))
        XCTAssertTrue(paths.contains(flutter.appendingPathComponent(".dart_tool").path))
        XCTAssertEqual(
            Set(items.compactMap(\.projectKind)),
            [.python, .go, .java, .dotnet, .flutter]
        )
    }

    func testAdditionalGlobalDeveloperCaches() {
        let paths = Set(RuleCatalog.rules.map(\.path))
        XCTAssertTrue(paths.contains("~/Library/Caches/Yarn"))
        XCTAssertTrue(paths.contains("~/.yarn/cache"))
        XCTAssertTrue(paths.contains("~/Library/pnpm/store"))
        XCTAssertTrue(paths.contains("~/.pnpm-store"))
        XCTAssertTrue(paths.contains("~/.bun/install/cache"))
        XCTAssertTrue(paths.contains("~/Library/Caches/pip"))
        XCTAssertTrue(paths.contains("~/Library/Caches/go-build"))
    }

    func testNativeShellTypeScriptProjectAlsoScansNodeArtifacts() throws {
        let project = temporaryURL.appendingPathComponent("Projects/MixedShellApp", isDirectory: true)
        try write("nsh.json", "{}", at: project)
        try write("package.json", "{}", at: project)
        try write("target/debug/app", "binary", at: project)
        try write("node_modules/nsh/package.json", "{}", at: project)
        try write(".nsh/out/bundle.js", "bundle", at: project)

        let items = try scan(projectsAt: project)
        let paths = Set(items.map(\.url.path))
        XCTAssertTrue(paths.contains(project.appendingPathComponent("target").path))
        XCTAssertTrue(paths.contains(project.appendingPathComponent("node_modules").path))
        XCTAssertTrue(paths.contains(project.appendingPathComponent(".nsh/out/bundle.js").path))
        XCTAssertEqual(Set(items.compactMap(\.projectKind)), [.nativeShell, .node])
    }

    func testCustomDirectoryScansChildrenAndPreservesRoot() throws {
        let custom = temporaryURL.appendingPathComponent("Work/Cache", isDirectory: true)
        try write("one.cache", "one", at: custom)
        try write("nested/two.cache", "two", at: custom)
        let directory = UserDirectory(path: custom.path)

        let items = try DiskScanner().scan(
            configuration: ScanConfiguration(home: temporaryURL, discoversProjectArtifacts: false),
            customDirectories: [directory]
        )

        XCTAssertEqual(Set(items.map(\.url.lastPathComponent)), ["one.cache", "nested"])
        XCTAssertTrue(items.allSatisfy { $0.category == .custom && $0.policy == .contents })
        XCTAssertTrue(FileManager.default.fileExists(atPath: custom.path))
    }

    func testCustomDirectoryRejectsMissingProtectedAndDuplicatePaths() throws {
        let home = temporaryURL
        let store = DirectoryStore(
            fileURL: home.appendingPathComponent("Settings/directories.json"),
            home: home
        )
        XCTAssertThrowsError(try store.add(home, to: [])) { error in
            XCTAssertEqual(error as? CleanDiskError, .protectedDirectory(home.path))
        }
        XCTAssertThrowsError(try store.add(home.appendingPathComponent("Library"), to: []))
        XCTAssertThrowsError(try store.add(URL(fileURLWithPath: "/"), to: []))

        let custom = home.appendingPathComponent("Work/cache", isDirectory: true)
        try makeDirectory("", at: custom)
        let updated = try store.add(custom, to: [])
        XCTAssertThrowsError(try store.add(custom, to: updated)) { error in
            XCTAssertEqual(error as? CleanDiskError, .duplicateDirectory)
        }
    }

    func testDirectoryStorePersistsEnabledState() throws {
        let home = temporaryURL
        let file = home.appendingPathComponent("Settings/directories.json")
        let store = DirectoryStore(fileURL: file, home: home)
        let custom = home.appendingPathComponent("Work/cache", isDirectory: true)
        try makeDirectory("", at: custom)

        var directories = try store.add(custom, to: [])
        directories[0].isEnabled = false
        try store.save(directories)

        let loaded = try DirectoryStore(fileURL: file, home: home).load()
        XCTAssertEqual(loaded.map(\.path), [custom.path])
        XCTAssertEqual(loaded.map(\.isEnabled), [false])
    }

    func testBuiltInDirectoryCannotBeAddedAgain() throws {
        let home = temporaryURL
        let npm = home.appendingPathComponent(".npm/_cacache", isDirectory: true)
        try makeDirectory("", at: npm)
        let store = DirectoryStore(fileURL: home.appendingPathComponent("settings.json"), home: home)
        XCTAssertThrowsError(try store.add(npm, to: [])) { error in
            XCTAssertEqual(error as? CleanDiskError, .builtInDirectory)
        }
    }

    func testSymbolicLinksAreNotScannedOrFollowed() throws {
        let custom = temporaryURL.appendingPathComponent("Custom", isDirectory: true)
        let outside = temporaryURL.appendingPathComponent("Outside", isDirectory: true)
        try write("local", "local", at: custom)
        try write("secret", "secret", at: outside)
        try makeDirectory("nested", at: custom)
        try write("nested/local-too", "local", at: custom)
        try FileManager.default.createSymbolicLink(
            at: custom.appendingPathComponent("linked"),
            withDestinationURL: outside
        )
        try FileManager.default.createSymbolicLink(
            at: custom.appendingPathComponent("nested/linked-again"),
            withDestinationURL: outside
        )

        let items = try DiskScanner().scan(
            configuration: ScanConfiguration(home: temporaryURL, discoversProjectArtifacts: false),
            customDirectories: [UserDirectory(path: custom.path)]
        )
        XCTAssertEqual(Set(items.map(\.url.lastPathComponent)), ["local", "nested"])
        XCTAssertEqual(items.first(where: { $0.title == "nested" })?.fileCount, 1)
        XCTAssertFalse(items.contains { $0.title == "linked" })
    }

    func testTrashCleanerMovesOnlyValidatedItems() throws {
        let home = temporaryURL
        let root = home.appendingPathComponent("Cache", isDirectory: true)
        let file = root.appendingPathComponent("old.cache")
        try write("old.cache", "old", at: root)
        let trash = home.appendingPathComponent("TestTrash", isDirectory: true)
        let item = makeItem(file, root: root, policy: .contents)
        let cleaner = TrashCleaner(home: home) { url in
            try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
            let destination = trash.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: destination)
            return destination
        }

        let report = cleaner.clean(items: [item])
        XCTAssertEqual(report.cleanedItems.map(\.id), [item.id])
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: trash.appendingPathComponent("old.cache").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.path))
    }

    func testTrashCleanerRejectsNativeShellAppEvenWhenCallerSelectsIt() throws {
        let home = temporaryURL
        let app = home.appendingPathComponent("Project/.nsh/out/Demo.app", isDirectory: true)
        try write("Contents/MacOS/Demo", "binary", at: app)
        let item = makeItem(app, root: app.deletingLastPathComponent(), policy: .nativeShellOutput)
        let probe = MoveProbe()
        let cleaner = TrashCleaner(home: home) { url in
            probe.urls.append(url)
            return url
        }

        let report = cleaner.clean(items: [item])
        XCTAssertTrue(report.cleanedItems.isEmpty)
        XCTAssertEqual(report.failures.count, 1)
        XCTAssertTrue(probe.urls.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: app.path))
    }

    func testTrashCleanerRejectsParentContainingNativeShellApp() throws {
        let home = temporaryURL
        let output = home.appendingPathComponent("Project/.nsh/out/macos", isDirectory: true)
        try write("Demo.app/Contents/MacOS/Demo", "binary", at: output)
        let item = makeItem(output, root: output.deletingLastPathComponent(), policy: .nativeShellOutput)
        let probe = MoveProbe()
        let cleaner = TrashCleaner(home: home) { url in
            probe.urls.append(url)
            return url
        }

        let report = cleaner.clean(items: [item])
        XCTAssertTrue(report.cleanedItems.isEmpty)
        XCTAssertEqual(report.failures.count, 1)
        XCTAssertTrue(probe.urls.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
    }

    func testCancellationStopsDiscovery() throws {
        let project = temporaryURL.appendingPathComponent("Project", isDirectory: true)
        try write("Cargo.toml", "[package]", at: project)
        try write("target/debug/app", "binary", at: project)
        let cancellation = ScanCancellation()
        cancellation.cancel()
        XCTAssertThrowsError(try scan(projectsAt: project, cancellation: cancellation)) { error in
            XCTAssertEqual(error as? CleanDiskError, .cancelled)
        }
    }

    private func scan(
        projectsAt root: URL,
        cancellation: ScanCancellation = ScanCancellation()
    ) throws -> [ScanItem] {
        try DiskScanner().scan(
            configuration: ScanConfiguration(
                home: temporaryURL,
                projectRoots: [root],
                maximumProjectDepth: 10
            ),
            cancellation: cancellation
        )
    }

    private func makeItem(_ url: URL, root: URL, policy: TargetPolicy) -> ScanItem {
        ScanItem(
            url: url,
            rootURL: root,
            title: url.lastPathComponent,
            groupID: "test",
            groupTitle: "Test",
            detail: "Test",
            category: .custom,
            policy: policy,
            projectKind: nil,
            byteCount: 4,
            fileCount: 1
        )
    }

    private func write(_ relativePath: String, _ contents: String, at root: URL) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(contents.utf8).write(to: url)
    }

    private func makeDirectory(_ relativePath: String, at root: URL) throws {
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(relativePath, isDirectory: true),
            withIntermediateDirectories: true
        )
    }
}

private final class MoveProbe: @unchecked Sendable {
    var urls: [URL] = []
}
