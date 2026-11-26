import Foundation

public struct TrashCleaner: Sendable {
    public typealias MoveToTrash = @Sendable (URL) throws -> URL

    private let home: URL
    private let moveToTrash: MoveToTrash

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home.standardizedFileURL
        self.moveToTrash = { url in
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
            return resultingURL as URL? ?? url
        }
    }

    public init(home: URL, moveToTrash: @escaping MoveToTrash) {
        self.home = home.standardizedFileURL
        self.moveToTrash = moveToTrash
    }

    public func clean(
        items: [ScanItem],
        progress: (@Sendable (Int, Int, String) -> Void)? = nil
    ) -> CleanReport {
        var cleaned: [ScanItem] = []
        var failures: [CleanFailure] = []
        for (index, item) in items.enumerated() {
            progress?(index, items.count, item.url.path)
            do {
                try SafetyPolicy.validateDeletion(of: item, home: home)
                _ = try moveToTrash(item.url)
                cleaned.append(item)
            } catch {
                failures.append(CleanFailure(
                    path: item.url.path,
                    message: error.localizedDescription
                ))
            }
        }
        progress?(items.count, items.count, "")
        return CleanReport(cleanedItems: cleaned, failures: failures)
    }
}
