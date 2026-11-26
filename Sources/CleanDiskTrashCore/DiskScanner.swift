import Foundation

public struct ScanConfiguration: Sendable {
    public let home: URL
    public let projectRoots: [URL]
    public let maximumProjectDepth: Int
    public let discoversProjectArtifacts: Bool

    public init(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        projectRoots: [URL]? = nil,
        maximumProjectDepth: Int = 10,
        discoversProjectArtifacts: Bool = true
    ) {
        self.home = home.standardizedFileURL
        self.projectRoots = (projectRoots ?? [home]).map(\.standardizedFileURL)
        self.maximumProjectDepth = maximumProjectDepth
        self.discoversProjectArtifacts = discoversProjectArtifacts
    }
}

public struct DiskScanner: Sendable {
    public init() {}

    public func scan(
        configuration: ScanConfiguration = ScanConfiguration(),
        customDirectories: [UserDirectory] = [],
        cancellation: ScanCancellation = ScanCancellation(),
        progress: (@Sendable (ScanProgress) -> Void)? = nil
    ) throws -> [ScanItem] {
        let home = configuration.home
        var candidates: [ScanCandidate] = customDirectories.filter(\.isEnabled).map { directory in
            ScanCandidate(
                rootURL: directory.url,
                title: directory.url.lastPathComponent,
                groupID: "custom.\(directory.id.uuidString)",
                groupTitle: directory.url.lastPathComponent,
                detail: directory.path,
                category: .custom,
                policy: .contents
            )
        }

        if configuration.discoversProjectArtifacts {
            let discovered = try ProjectDiscovery(
                maximumDepth: configuration.maximumProjectDepth,
                home: home
            ).discover(roots: configuration.projectRoots, cancellation: cancellation) { path in
                progress?(ScanProgress(path: path, candidateCount: 0))
            }
            candidates.append(contentsOf: discovered)
        }

        candidates.append(contentsOf: RuleCatalog.rules.filter { !$0.path.contains("*") }.map { rule in
            ScanCandidate(
                rootURL: RuleCatalog.url(for: rule, home: home),
                title: rule.title,
                groupID: rule.id,
                groupTitle: rule.title,
                detail: rule.path,
                category: rule.category,
                policy: rule.policy
            )
        })
        candidates.append(contentsOf: containerCandidates(home: home))

        var items: [ScanItem] = []
        var seenPaths: Set<String> = []
        for candidate in candidates {
            try cancellation.check()
            progress?(ScanProgress(path: candidate.rootURL.path, candidateCount: items.count))
            for url in try candidateURLs(for: candidate) {
                try cancellation.check()
                let path = url.standardizedFileURL.path
                guard !seenPaths.contains(path), !isOwnCache(url, candidate: candidate) else { continue }
                let candidateCount = items.count
                let size = try FileSizer.measure(url, cancellation: cancellation) { visitedPath in
                    progress?(ScanProgress(path: visitedPath, candidateCount: candidateCount))
                }
                guard size.byteCount > 0 || size.fileCount > 0 else { continue }
                seenPaths.insert(path)
                items.append(ScanItem(
                    url: url,
                    rootURL: candidate.rootURL,
                    title: candidate.policy == .wholeDirectory ? candidate.title : url.lastPathComponent,
                    groupID: candidate.groupID,
                    groupTitle: candidate.groupTitle,
                    detail: candidate.detail,
                    category: candidate.category,
                    policy: candidate.policy,
                    projectKind: candidate.projectKind,
                    byteCount: size.byteCount,
                    fileCount: size.fileCount
                ))
            }
        }
        return items.sorted {
            if $0.byteCount != $1.byteCount { return $0.byteCount > $1.byteCount }
            return $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending
        }
    }

    private func candidateURLs(for candidate: ScanCandidate) throws -> [URL] {
        let url = candidate.rootURL
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              values.isDirectory == true, values.isSymbolicLink != true else { return [] }
        if candidate.policy == .wholeDirectory { return [url] }
        if candidate.policy == .nativeShellOutput {
            return nativeShellOutputURLs(at: url)
        }

        let children = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: []
        )) ?? []
        return children.filter { child in
            guard let values = try? child.resourceValues(forKeys: [.isSymbolicLinkKey]),
                  values.isSymbolicLink != true else { return false }
            return true
        }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func nativeShellOutputURLs(at root: URL) -> [URL] {
        let children = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: []
        )) ?? []
        return children.sorted(by: {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }).flatMap { child -> [URL] in
            guard let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isSymbolicLink != true, !SafetyPolicy.isPackagedOutput(child) else { return [] }
            if values.isDirectory == true, SafetyPolicy.containsPackagedOutput(at: child) {
                return nativeShellOutputURLs(at: child)
            }
            return [child]
        }
    }

    private func containerCandidates(home: URL) -> [ScanCandidate] {
        let containers = home.appendingPathComponent("Library/Containers", isDirectory: true)
        let children = (try? FileManager.default.contentsOfDirectory(
            at: containers,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return children.flatMap { container -> [ScanCandidate] in
            guard let values = try? container.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isDirectory == true, values.isSymbolicLink != true else { return [] }
            return [
                ("Caches", "system.container-caches", "应用容器缓存"),
                ("Logs", "system.container-logs", "应用容器日志"),
            ].map { name, id, title in
                ScanCandidate(
                    rootURL: container.appendingPathComponent("Data/Library/\(name)", isDirectory: true),
                    title: title,
                    groupID: id,
                    groupTitle: title,
                    detail: container.lastPathComponent,
                    category: .system,
                    policy: .contents
                )
            }
        }
    }

    private func isOwnCache(_ url: URL, candidate: ScanCandidate) -> Bool {
        guard candidate.groupID == "system.library-caches" || candidate.groupID == "system.container-caches" else {
            return false
        }
        return ["com.cleandisktrash.app", "CleanDiskTrash"].contains(url.lastPathComponent)
    }
}
