import Foundation

public enum ScanCategory: String, Codable, CaseIterable, Sendable {
    case system
    case developer
    case custom
}

public enum ProjectKind: String, Codable, Sendable {
    case android = "Android"
    case apple = "iOS / macOS"
    case rust = "Rust"
    case cmake = "原生 C/C++"
    case nativeShell = "Native Shell"
    case node = "Node.js"
    case python = "Python"
    case go = "Go"
    case java = "Java / Maven"
    case dotnet = ".NET"
    case flutter = "Flutter / Dart"
}

public enum TargetPolicy: String, Codable, Sendable {
    /// The generated directory itself can be moved to the Trash.
    case wholeDirectory
    /// Only direct children are candidates; the user-selected root is preserved.
    case contents
    /// NSH build intermediates, excluding packaged applications and installers.
    case nativeShellOutput
}

public struct BuiltInRule: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let path: String
    public let detail: String
    public let category: ScanCategory
    public let policy: TargetPolicy

    public init(
        id: String,
        title: String,
        path: String,
        detail: String,
        category: ScanCategory,
        policy: TargetPolicy = .contents
    ) {
        self.id = id
        self.title = title
        self.path = path
        self.detail = detail
        self.category = category
        self.policy = policy
    }
}

public struct UserDirectory: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var path: String
    public var isEnabled: Bool

    public init(id: UUID = UUID(), path: String, isEnabled: Bool = true) {
        self.id = id
        self.path = path
        self.isEnabled = isEnabled
    }

    public var url: URL { URL(fileURLWithPath: path, isDirectory: true) }
}

public struct ScanCandidate: Hashable, Sendable {
    public let rootURL: URL
    public let title: String
    public let groupID: String
    public let groupTitle: String
    public let detail: String
    public let category: ScanCategory
    public let policy: TargetPolicy
    public let projectKind: ProjectKind?

    public init(
        rootURL: URL,
        title: String,
        groupID: String,
        groupTitle: String,
        detail: String,
        category: ScanCategory,
        policy: TargetPolicy,
        projectKind: ProjectKind? = nil
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.title = title
        self.groupID = groupID
        self.groupTitle = groupTitle
        self.detail = detail
        self.category = category
        self.policy = policy
        self.projectKind = projectKind
    }
}

public struct ScanItem: Identifiable, Hashable, Codable, Sendable {
    /// The URL is standardized in init, so the hot selection path does not normalize it repeatedly.
    public var id: String { url.path }
    public let url: URL
    public let rootURL: URL
    public let title: String
    public let groupID: String
    public let groupTitle: String
    public let detail: String
    public let category: ScanCategory
    public let policy: TargetPolicy
    public let projectKind: ProjectKind?
    public let byteCount: Int64
    public let fileCount: Int

    public init(
        url: URL,
        rootURL: URL,
        title: String,
        groupID: String,
        groupTitle: String,
        detail: String,
        category: ScanCategory,
        policy: TargetPolicy,
        projectKind: ProjectKind?,
        byteCount: Int64,
        fileCount: Int
    ) {
        self.url = url.standardizedFileURL
        self.rootURL = rootURL.standardizedFileURL
        self.title = title
        self.groupID = groupID
        self.groupTitle = groupTitle
        self.detail = detail
        self.category = category
        self.policy = policy
        self.projectKind = projectKind
        self.byteCount = byteCount
        self.fileCount = fileCount
    }
}

public struct ScanProgress: Sendable {
    public let path: String
    public let candidateCount: Int

    public init(path: String, candidateCount: Int) {
        self.path = path
        self.candidateCount = candidateCount
    }
}

public struct CleanFailure: Identifiable, Sendable {
    public var id: String { path }
    public let path: String
    public let message: String

    public init(path: String, message: String) {
        self.path = path
        self.message = message
    }
}

public struct CleanReport: Sendable {
    public let cleanedItems: [ScanItem]
    public let failures: [CleanFailure]

    public init(cleanedItems: [ScanItem], failures: [CleanFailure]) {
        self.cleanedItems = cleanedItems
        self.failures = failures
    }

    public var reclaimedByteCount: Int64 {
        cleanedItems.reduce(0) { $0 + $1.byteCount }
    }
}

public enum CleanDiskError: LocalizedError, Equatable {
    case cancelled
    case invalidDirectory(String)
    case protectedDirectory(String)
    case duplicateDirectory
    case builtInDirectory
    case directoryNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            "扫描已取消"
        case .invalidDirectory(let path):
            "不是可扫描的目录：\(path)"
        case .protectedDirectory(let path):
            "为保护系统和用户数据，不能添加：\(path)"
        case .duplicateDirectory:
            "这个目录已经在自定义目录中"
        case .builtInDirectory:
            "这个目录已包含在内置扫描规则中"
        case .directoryNotFound(let path):
            "目录不存在或当前不可访问：\(path)"
        }
    }
}
