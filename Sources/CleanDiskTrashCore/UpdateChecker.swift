import CryptoKit
import Foundation

public struct ReleaseManifest: Codable, Equatable, Sendable {
    public let version: String
    public let build: Int
    public let notes: String
    public let url: String
    public let urls: [String]

    public init(version: String, build: Int, notes: String = "", url: String = "", urls: [String] = []) {
        self.version = version
        self.build = build
        self.notes = notes
        self.url = url
        self.urls = urls
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        build = try container.decode(Int.self, forKey: .build)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        urls = try container.decodeIfPresent([String].self, forKey: .urls) ?? []
    }

    public var downloadURLs: [URL] {
        var seen: Set<String> = []
        return (urls + [url]).compactMap { value in
            let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, seen.insert(value).inserted,
                  let url = URL(string: value), Self.isTrustedDownloadURL(url) else { return nil }
            return url
        }
    }

    private static func isTrustedDownloadURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return false }
        return host == "gitee.com" || host == "giteeusercontent.com" || host.hasSuffix(".giteeusercontent.com")
    }
}

public enum UpdateCheckError: LocalizedError, Equatable {
    case invalidResponse
    case serverStatus(Int)
    case responseTooLarge
    case missingDownload
    case transportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse: "更新服务器返回了无法识别的响应"
        case .serverStatus(let status): "更新服务器暂时不可用（HTTP \(status)）"
        case .responseTooLarge: "更新服务器返回的版本信息异常"
        case .missingDownload: "新版本信息中没有可用的 Gitee 下载地址"
        case .transportFailed(let message): "网络请求失败：\(message)"
        }
    }
}

public struct UpdateResponse: Sendable {
    public let data: Data
    public let statusCode: Int

    public init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }
}

public struct UpdateChecker: Sendable {
    public typealias Fetch = @Sendable (URL) async throws -> UpdateResponse

    public static let repository = "https://gitee.com/lanshanshu/release"

    public let currentVersion: String
    public let currentBuild: Int
    public let endpoint: URL
    private let fetch: Fetch

    public init(bundle: Bundle = .main, fetch: Fetch? = nil) {
        let appID = bundle.object(forInfoDictionaryKey: "CFBundleIdentifier") as? String
            ?? "com.cleandisktrash.app"
        currentVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        currentBuild = Int(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
        endpoint = URL(string: "\(Self.repository)/raw/master/latest/\(Self.key(for: appID)).json")!
        self.fetch = fetch ?? Self.fetchFromServer
    }

    public init(
        appID: String,
        currentVersion: String,
        currentBuild: Int,
        fetch: @escaping Fetch
    ) {
        self.currentVersion = currentVersion
        self.currentBuild = currentBuild
        endpoint = URL(string: "\(Self.repository)/raw/master/latest/\(Self.key(for: appID)).json")!
        self.fetch = fetch
    }

    public static func key(for appID: String) -> String {
        Insecure.MD5.hash(data: Data(appID.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// A missing manifest is a normal unpublished/up-to-date state. Other failures are reported
    /// to manual checks and remain silent during background checks.
    public func check() async throws -> ReleaseManifest? {
        let response = try await fetch(endpoint)
        if response.statusCode == 404 { return nil }
        guard response.statusCode == 200 else { throw UpdateCheckError.serverStatus(response.statusCode) }
        guard response.data.count <= 65_536 else { throw UpdateCheckError.responseTooLarge }
        let release = try JSONDecoder().decode(ReleaseManifest.self, from: response.data)
        guard release.build > currentBuild else { return nil }
        guard !release.downloadURLs.isEmpty else { throw UpdateCheckError.missingDownload }
        return release
    }

    private static func fetchFromServer(url: URL) async throws -> UpdateResponse {
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 8
        )
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw UpdateCheckError.invalidResponse }
            return UpdateResponse(data: data, statusCode: response.statusCode)
        } catch {
            // Some proxy/TLS combinations fail in CFNetwork while macOS curl, with full
            // certificate verification still enabled, can reach the same public endpoint.
            return try await fetchUsingSystemCurl(url: url)
        }
    }

    private static func fetchUsingSystemCurl(url: URL) async throws -> UpdateResponse {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                let output = Pipe()
                let errors = Pipe()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
                process.arguments = [
                    "--location", "--silent", "--show-error",
                    "--connect-timeout", "5", "--max-time", "8",
                    "--header", "Accept: application/json",
                    "--write-out", "\n%{http_code}",
                    url.absoluteString,
                ]
                process.standardOutput = output
                process.standardError = errors
                do {
                    try process.run()
                    let outputData = output.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errors.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    guard process.terminationStatus == 0 else {
                        let message = String(data: errorData, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        throw UpdateCheckError.transportFailed(
                            message?.isEmpty == false ? message! : "curl 退出码 \(process.terminationStatus)"
                        )
                    }
                    guard let separator = outputData.lastIndex(of: 0x0A),
                          let status = Int(String(
                            decoding: outputData.suffix(from: outputData.index(after: separator)),
                            as: UTF8.self
                          ).trimmingCharacters(in: .whitespacesAndNewlines)) else {
                        throw UpdateCheckError.invalidResponse
                    }
                    continuation.resume(returning: UpdateResponse(
                        data: outputData.prefix(upTo: separator),
                        statusCode: status
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
