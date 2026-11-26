import Foundation

public struct DirectoryStore: Sendable {
    public let fileURL: URL
    public let home: URL

    public init(fileURL: URL, home: URL) {
        self.fileURL = fileURL
        self.home = home.standardizedFileURL
    }

    public static func `default`(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> DirectoryStore {
        DirectoryStore(
            fileURL: home
                .appendingPathComponent("Library/Application Support/CleanDiskTrash", isDirectory: true)
                .appendingPathComponent("custom-directories.json"),
            home: home
        )
    }

    public func load() throws -> [UserDirectory] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([UserDirectory].self, from: data)
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    public func save(_ directories: [UserDirectory]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(directories).write(to: fileURL, options: .atomic)
    }

    @discardableResult
    public func add(_ proposedURL: URL, to directories: [UserDirectory]) throws -> [UserDirectory] {
        let url = try SafetyPolicy.validateCustomDirectory(proposedURL, home: home)
        guard !RuleCatalog.containsBuiltInRoot(url, home: home) else {
            throw CleanDiskError.builtInDirectory
        }
        guard !directories.contains(where: { $0.url.standardizedFileURL.path == url.path }) else {
            throw CleanDiskError.duplicateDirectory
        }
        var updated = directories
        updated.append(UserDirectory(path: url.path))
        updated.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        try save(updated)
        return updated
    }
}
