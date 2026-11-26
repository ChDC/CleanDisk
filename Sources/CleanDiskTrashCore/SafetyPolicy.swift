import Foundation

public enum SafetyPolicy {
    public static let packagedOutputExtensions: Set<String> = [
        "app", "ipa", "apk", "aab", "dmg", "pkg", "exe", "msi", "msix", "nshpkg",
    ]

    public static func protectedDirectories(home: URL) -> Set<String> {
        let home = home.standardizedFileURL
        return [
            "/",
            "/System",
            "/Library",
            "/Applications",
            "/Users",
            "/Volumes",
            "/private",
            "/etc",
            "/var",
            home.path,
            home.appendingPathComponent("Desktop").path,
            home.appendingPathComponent("Documents").path,
            home.appendingPathComponent("Downloads").path,
            home.appendingPathComponent("Library").path,
            home.appendingPathComponent("Library/Application Support").path,
            home.appendingPathComponent("Library/Containers").path,
            home.appendingPathComponent("Library/Developer").path,
        ]
    }

    public static func validateCustomDirectory(_ url: URL, home: URL) throws -> URL {
        let url = url.standardizedFileURL
        let path = url.path
        guard !protectedDirectories(home: home).contains(path),
              !url.pathComponents.contains(where: { $0.hasSuffix(".app") }) else {
            throw CleanDiskError.protectedDirectory(path)
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw CleanDiskError.directoryNotFound(path)
        }
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values?.isDirectory == true, values?.isSymbolicLink != true else {
            throw CleanDiskError.invalidDirectory(path)
        }
        return url
    }

    public static func isPackagedOutput(_ url: URL) -> Bool {
        packagedOutputExtensions.contains(url.pathExtension.lowercased())
    }

    static func containsPackagedOutput(at url: URL) -> Bool {
        if isPackagedOutput(url) { return true }
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              values.isDirectory == true, values.isSymbolicLink != true else { return false }
        let children = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: []
        )) ?? []
        return children.contains(where: containsPackagedOutput(at:))
    }

    public static func validateDeletion(of item: ScanItem, home: URL) throws {
        let path = item.url.standardizedFileURL.path
        guard !protectedDirectories(home: home).contains(path), path != "/" else {
            throw CleanDiskError.protectedDirectory(path)
        }
        guard item.policy != .contents || item.url.path != item.rootURL.path else {
            throw CleanDiskError.protectedDirectory(path)
        }
        if item.policy == .nativeShellOutput {
            guard item.url.path.contains("/.nsh/out/"),
                  !containsPackagedOutput(at: item.url) else {
                throw CleanDiskError.protectedDirectory(path)
            }
        }
        let values = try item.url.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CleanDiskError.protectedDirectory(path)
        }
    }
}
