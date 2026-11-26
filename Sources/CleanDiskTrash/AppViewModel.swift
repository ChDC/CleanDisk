import AppKit
import CleanDiskTrashCore
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var items: [ScanItem] = [] {
        didSet { rebuildItemDerivedData() }
    }
    @Published var selectedIDs: Set<String> = [] {
        didSet { rebuildSelectionSummary() }
    }
    @Published var directories: [UserDirectory] = []
    @Published var selectedCategory: ScanCategory? {
        didSet { rebuildVisibleGroups() }
    }
    @Published var searchText = "" {
        didSet { rebuildVisibleGroups() }
    }
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var isSettingsPresented = false
    @Published var isCleanConfirmationPresented = false
    @Published var scanProgress = ScanProgress(path: "准备扫描…", candidateCount: 0)
    @Published var statusMessage = "扫描不会修改文件，清理前需要再次确认。"
    @Published var lastScanDate: Date?
    @Published var alert: AppAlert?
    @Published var isCheckingForUpdates = false

    private(set) var visibleGroups: [ResultGroup] = []
    private(set) var selectedItemCount = 0
    private(set) var selectedByteCount: Int64 = 0
    private(set) var totalByteCount: Int64 = 0
    private var allGroups: [ResultGroup] = []
    private var categoryCounts: [ScanCategory: Int] = [:]
    private var categoryByteCounts: [ScanCategory: Int64] = [:]
    private var totalItemCount = 0

    private let store = DirectoryStore.default()
    private var cancellation: ScanCancellation?
    private var scanTask: Task<Void, Never>?
    private var updateWatcher: Task<Void, Never>?
    private var updateCheckInProgress = false
    private var lastUpdateAttempt = Date.distantPast
    private var lastPresentedBuild: Int?

    init() {
        do {
            directories = try store.load()
        } catch {
            alert = AppAlert(title: "无法读取自定义目录", message: error.localizedDescription)
        }
        #if DEBUG
        installStressResultsIfRequested()
        #endif
    }

    #if DEBUG
    private func installStressResultsIfRequested() {
        guard let flag = CommandLine.arguments.first(where: { $0.hasPrefix("-StressResults") }),
              let count = Int(flag.dropFirst("-StressResults".count)), count > 0 else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser
        items = (0..<count).map { index in
            let group = index % 100
            let url = home.appendingPathComponent("Stress/Group\(group)/Cache\(index)")
            return ScanItem(
                url: url,
                rootURL: url,
                title: "Cache\(index)",
                groupID: "stress.\(group)",
                groupTitle: "Stress group \(group)",
                detail: url.path,
                category: index % 3 == 0 ? .developer : .system,
                policy: .wholeDirectory,
                projectKind: index % 5 == 0 ? .nativeShell : nil,
                byteCount: Int64((index % 100 + 1) * 1_048_576),
                fileCount: index * 10
            )
        }
        selectedIDs = Set(items.map(\.id))
    }
    #endif

    var visibleItems: [ScanItem] {
        visibleGroups.flatMap(\.items)
    }

    var selectedItems: [ScanItem] {
        items.filter { selectedIDs.contains($0.id) }
    }

    func byteCount(for category: ScanCategory?) -> Int64 {
        category.map { categoryByteCounts[$0] ?? 0 } ?? totalByteCount
    }

    func itemCount(for category: ScanCategory?) -> Int {
        category.map { categoryCounts[$0] ?? 0 } ?? totalItemCount
    }

    func startUpdateWatcher() {
        guard updateWatcher == nil else { return }
        updateWatcher = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            while !Task.isCancelled {
                self?.checkForUpdates(manual: false)
                try? await Task.sleep(for: .seconds(30 * 60))
            }
        }
    }

    func checkForUpdates(manual: Bool = true) {
        guard !updateCheckInProgress else { return }
        let now = Date()
        guard manual || now.timeIntervalSince(lastUpdateAttempt) >= 10 * 60 else { return }
        updateCheckInProgress = true
        isCheckingForUpdates = true
        lastUpdateAttempt = now

        Task { [weak self] in
            guard let self else { return }
            defer {
                updateCheckInProgress = false
                isCheckingForUpdates = false
            }
            do {
                let checker = UpdateChecker()
                if let release = try await checker.check() {
                    if manual || lastPresentedBuild != release.build {
                        lastPresentedBuild = release.build
                        alert = AppAlert(
                            title: "发现新版本 \(release.version)",
                            message: "构建 \(release.build)\(release.notes.isEmpty ? "" : "\n\n\(release.notes)")",
                            release: release
                        )
                    }
                } else if manual {
                    alert = AppAlert(
                        title: "暂未发现新版本",
                        message: "当前版本 \(checker.currentVersion)（\(checker.currentBuild)）。"
                    )
                }
            } catch {
                if manual {
                    alert = AppAlert(title: "检查更新失败", message: error.localizedDescription)
                }
            }
        }
    }

    func openUpdate(_ release: ReleaseManifest) {
        guard let url = release.downloadURLs.first else {
            alert = AppAlert(title: "无法打开更新", message: UpdateCheckError.missingDownload.localizedDescription)
            return
        }
        NSWorkspace.shared.open(url)
    }

    func startScan() {
        guard !isScanning, !isCleaning else { return }
        scanTask?.cancel()
        let cancellation = ScanCancellation()
        self.cancellation = cancellation
        isScanning = true
        items = []
        selectedIDs = []
        scanProgress = ScanProgress(path: "正在发现缓存与项目…", candidateCount: 0)
        statusMessage = "只读扫描中，不会修改任何文件。"
        let directories = directories.filter(\.isEnabled)
        let relay = ProgressRelay { [weak self] progress in
            Task { @MainActor in
                self?.scanProgress = progress
            }
        }

        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let result = try DiskScanner().scan(
                    customDirectories: directories,
                    cancellation: cancellation,
                    progress: { relay.send($0) }
                )
                try cancellation.check()
                await self?.finishScan(result)
            } catch {
                await self?.failScan(error)
            }
        }
    }

    func cancelScan() {
        cancellation?.cancel()
        scanTask?.cancel()
        isScanning = false
        scanProgress = ScanProgress(path: "扫描已取消", candidateCount: 0)
        statusMessage = "已取消扫描，磁盘内容未发生变化。"
    }

    func toggle(_ item: ScanItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    func setSelection(_ selected: Bool, for itemIDs: [String]) {
        if selected {
            selectedIDs.formUnion(itemIDs)
        } else {
            selectedIDs.subtract(itemIDs)
        }
    }

    func isGroupSelected(_ items: [ScanItem]) -> Bool {
        !items.isEmpty && items.allSatisfy { selectedIDs.contains($0.id) }
    }

    func cleanSelected() {
        let selected = selectedItems
        guard !selected.isEmpty, !isCleaning else { return }
        isCleaning = true
        statusMessage = "正在将所选项目移到废纸篓…"
        Task.detached(priority: .userInitiated) { [weak self] in
            let report = TrashCleaner().clean(items: selected)
            await self?.finishCleaning(report)
        }
    }

    func addDirectory(path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let expanded = (trimmed as NSString).expandingTildeInPath
        addDirectory(url: URL(fileURLWithPath: expanded, isDirectory: true))
    }

    func addDirectory(url: URL) {
        do {
            directories = try store.add(url, to: directories)
            statusMessage = "目录已添加，重新扫描后生效。"
        } catch {
            alert = AppAlert(title: "无法添加目录", message: error.localizedDescription)
        }
    }

    func setDirectory(_ directory: UserDirectory, enabled: Bool) {
        guard let index = directories.firstIndex(where: { $0.id == directory.id }) else { return }
        directories[index].isEnabled = enabled
        persistDirectories()
    }

    func removeDirectory(_ directory: UserDirectory) {
        directories.removeAll { $0.id == directory.id }
        persistDirectories()
    }

    func reveal(_ item: ScanItem) {
        guard FileManager.default.fileExists(atPath: item.url.path) else {
            alert = AppAlert(title: "文件已不存在", message: "请重新扫描以更新结果。")
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    private func finishScan(_ result: [ScanItem]) {
        isScanning = false
        items = result
        selectedIDs = Set(result.map(\.id))
        lastScanDate = Date()
        scanProgress = ScanProgress(path: "扫描完成", candidateCount: result.count)
        statusMessage = result.isEmpty
            ? "未发现可清理内容。你可以添加自定义目录后重新扫描。"
            : "扫描完成。默认勾选全部结果，可在清理前逐项调整。"
    }

    private func failScan(_ error: Error) {
        isScanning = false
        guard !Task.isCancelled, (error as? CleanDiskError) != .cancelled else {
            statusMessage = "已取消扫描，磁盘内容未发生变化。"
            return
        }
        statusMessage = "扫描未完成。"
        alert = AppAlert(title: "扫描失败", message: error.localizedDescription)
    }

    private func finishCleaning(_ report: CleanReport) {
        isCleaning = false
        let cleanedIDs = Set(report.cleanedItems.map(\.id))
        items.removeAll { cleanedIDs.contains($0.id) }
        selectedIDs.subtract(cleanedIDs)
        let size = ByteFormatting.string(report.reclaimedByteCount)
        if report.failures.isEmpty {
            statusMessage = "已将 \(report.cleanedItems.count) 项（\(size)）移到废纸篓。"
            alert = AppAlert(
                title: "清理完成",
                message: "\(size) 已移到废纸篓。需要时可从废纸篓恢复。"
            )
        } else {
            statusMessage = "已处理 \(report.cleanedItems.count) 项，\(report.failures.count) 项失败。"
            let details = report.failures.prefix(3)
                .map { "\(($0.path as NSString).abbreviatingWithTildeInPath)\n\($0.message)" }
                .joined(separator: "\n\n")
            alert = AppAlert(title: "部分项目未清理", message: details)
        }
    }

    private func rebuildItemDerivedData() {
        totalItemCount = items.count
        totalByteCount = items.reduce(0) { $0 + $1.byteCount }
        categoryCounts = Dictionary(grouping: items, by: \.category).mapValues(\.count)
        categoryByteCounts = Dictionary(grouping: items, by: \.category).mapValues {
            $0.reduce(0) { $0 + $1.byteCount }
        }
        allGroups = Dictionary(grouping: items, by: \.groupID).map { id, items in
            ResultGroup(id: id, items: items.sorted { $0.byteCount > $1.byteCount })
        }.sorted { $0.byteCount > $1.byteCount }
        rebuildVisibleGroups()
        rebuildSelectionSummary()
    }

    private func rebuildVisibleGroups() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        visibleGroups = allGroups.compactMap { group in
            if let selectedCategory, group.category != selectedCategory { return nil }
            guard !query.isEmpty else { return group }
            let matchingItems = group.items.filter { item in
                item.title.localizedCaseInsensitiveContains(query)
                    || item.groupTitle.localizedCaseInsensitiveContains(query)
                    || item.url.path.localizedCaseInsensitiveContains(query)
            }
            return matchingItems.isEmpty ? nil : ResultGroup(id: group.id, items: matchingItems)
        }
    }

    private func rebuildSelectionSummary() {
        var count = 0
        var bytes: Int64 = 0
        for item in items where selectedIDs.contains(item.id) {
            count += 1
            bytes += item.byteCount
        }
        selectedItemCount = count
        selectedByteCount = bytes
    }

    private func persistDirectories() {
        do {
            try store.save(directories)
            statusMessage = "自定义目录设置已保存，重新扫描后生效。"
        } catch {
            alert = AppAlert(title: "无法保存目录设置", message: error.localizedDescription)
        }
    }
}

struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let release: ReleaseManifest?

    init(title: String, message: String, release: ReleaseManifest? = nil) {
        self.title = title
        self.message = message
        self.release = release
    }
}

@MainActor
enum ByteFormatting {
    private static let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.includesActualByteCount = false
        return formatter
    }()

    static func string(_ bytes: Int64) -> String {
        return formatter.string(fromByteCount: bytes)
    }
}

struct ResultGroup: Identifiable, Equatable {
    let id: String
    let title: String
    let category: ScanCategory
    let kind: ProjectKind?
    let items: [ScanItem]
    let byteCount: Int64

    init(id: String, items: [ScanItem]) {
        self.id = id
        self.items = items
        self.title = items[0].groupTitle
        self.category = items[0].category
        self.kind = items[0].projectKind
        self.byteCount = items.reduce(0) { $0 + $1.byteCount }
    }
}

private final class ProgressRelay: @unchecked Sendable {
    private let lock = NSLock()
    private var lastUpdate = Date.distantPast
    private let handler: @Sendable (ScanProgress) -> Void

    init(handler: @escaping @Sendable (ScanProgress) -> Void) {
        self.handler = handler
    }

    func send(_ progress: ScanProgress) {
        lock.lock()
        let now = Date()
        guard now.timeIntervalSince(lastUpdate) >= 0.12 else {
            lock.unlock()
            return
        }
        lastUpdate = now
        lock.unlock()
        handler(progress)
    }
}
