import Foundation

public struct FileSize: Equatable, Sendable {
    public let byteCount: Int64
    public let fileCount: Int
}

public enum FileSizer {
    public static func measure(
        _ url: URL,
        cancellation: ScanCancellation? = nil,
        onVisit: (@Sendable (String) -> Void)? = nil
    ) throws -> FileSize {
        let values = try url.resourceValues(forKeys: [
            .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey,
        ])
        guard values.isSymbolicLink != true else { return FileSize(byteCount: 0, fileCount: 0) }
        if values.isRegularFile == true {
            return FileSize(byteCount: Int64(values.totalFileAllocatedSize ?? 0), fileCount: 1)
        }
        guard values.isDirectory == true else { return FileSize(byteCount: 0, fileCount: 0) }

        var bytes: Int64 = 0
        var count = 0
        var pending = [url]
        while let directory = pending.popLast() {
            // Background Foundation enumeration otherwise accumulates autoreleased URLs until
            // the entire scan finishes, which creates avoidable memory spikes on large caches.
            try autoreleasepool {
                try cancellation?.check()
                onVisit?(directory.path)
                let children = (try? FileManager.default.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [
                        .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey,
                    ],
                    options: []
                )) ?? []
                for child in children {
                    try cancellation?.check()
                    guard let childValues = try? child.resourceValues(forKeys: [
                        .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey,
                    ]), childValues.isSymbolicLink != true else { continue }
                    if childValues.isRegularFile == true {
                        bytes += Int64(childValues.totalFileAllocatedSize ?? 0)
                        count += 1
                    } else if childValues.isDirectory == true {
                        pending.append(child)
                    }
                }
            }
        }
        return FileSize(byteCount: bytes, fileCount: count)
    }
}
