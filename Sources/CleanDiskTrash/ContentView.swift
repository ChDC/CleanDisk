import SwiftUI
import AppKit
import CleanDiskTrashCore

struct ContentView: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 220)
            Divider()
            VStack(spacing: 0) {
                SummaryHeader()
                Divider()
                content
                if !model.items.isEmpty && !model.isScanning {
                    Divider()
                    SelectionBar()
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $model.isSettingsPresented) {
            DirectorySettingsView()
                .environmentObject(model)
        }
        .alert(item: $model.alert) { alert in
            if let release = alert.release {
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("下载更新")) { model.openUpdate(release) },
                    secondaryButton: .cancel(Text("稍后"))
                )
            } else {
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("好"))
                )
            }
        }
        .confirmationDialog(
            "将所选项目移到废纸篓？",
            isPresented: $model.isCleanConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("移到废纸篓", role: .destructive) { model.cleanSelected() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("共 \(model.selectedItems.count) 项，\(ByteFormatting.string(model.selectedByteCount))。清理前已排除 Native Shell 应用与安装包。")
        }
        .onAppear { model.startUpdateWatcher() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.checkForUpdates(manual: false)
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isScanning {
            ScanningView()
        } else if model.isCleaning {
            CleaningView()
        } else if model.items.isEmpty {
            EmptyStateView()
        } else {
            ResultsView()
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                AppIconView(size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CleanDisk")
                        .font(.headline)
                    Text("MAC 磁盘清理")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 26)

            Text("扫描范围")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            SidebarButton(category: nil, title: "全部结果", icon: "square.grid.2x2")
            SidebarButton(category: .system, title: "系统与缓存", icon: "shippingbox")
            SidebarButton(category: .developer, title: "开发产物", icon: "hammer")
            SidebarButton(category: .custom, title: "自定义目录", icon: "folder")

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                Divider()
                Button {
                    model.checkForUpdates(manual: true)
                } label: {
                    Label(
                        model.isCheckingForUpdates ? "正在检查更新…" : "检查更新",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(model.isCheckingForUpdates)
                .padding(.horizontal, 18)
                .padding(.vertical, 6)
                Button {
                    model.isSettingsPresented = true
                } label: {
                    Label("管理扫描目录", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.vertical, 6)
                Text("文件仅移入废纸篓，可恢复")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .background(Color.primary.opacity(0.025))
    }
}

private struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22)
                    .fill(Color.teal)
                Image(systemName: "internaldrive")
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
        }
    }
}

private struct SidebarButton: View {
    @EnvironmentObject private var model: AppViewModel
    let category: ScanCategory?
    let title: String
    let icon: String

    var body: some View {
        let isSelected = model.selectedCategory == category
        Button {
            model.selectedCategory = category
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? Color.teal : Color.secondary)
                Text(title)
                    .font(.callout.weight(isSelected ? .medium : .regular))
                    .lineLimit(1)
                Spacer()
                if model.itemCount(for: category) > 0 {
                    Text("\(model.itemCount(for: category))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(isSelected ? Color.teal.opacity(0.13) : .clear)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.teal.opacity(0.09), lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .foregroundStyle(Color.primary)
    }
}

private struct SummaryHeader: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 7) {
                Text(model.items.isEmpty ? "释放磁盘空间" : ByteFormatting.string(model.totalByteCount))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(model.items.isEmpty ? "缓存、日志与原生项目构建产物，一次看清" : "发现 \(model.items.count) 项可清理内容，默认全部勾选")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.isSettingsPresented = true
            } label: {
                Label("添加目录", systemImage: "folder.badge.plus")
            }
            .disabled(model.isScanning || model.isCleaning)
            Button {
                model.startScan()
            } label: {
                Label(model.items.isEmpty ? "开始扫描" : "重新扫描", systemImage: "arrow.clockwise")
                    .frame(minWidth: 72)
            }
            .buttonStyle(PrimaryButtonStyle())
            .controlSize(.large)
            .disabled(model.isScanning || model.isCleaning)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct EmptyStateView: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.teal)
            VStack(spacing: 8) {
                Text("从一次只读扫描开始")
                    .font(.title2.weight(.semibold))
                Text("结果按来源分组，任何项目都可以单独取消勾选。")
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 12) {
                ScopeCard(icon: "shippingbox", title: "系统与缓存", text: "npm、用户缓存、壁纸缓存\n应用容器缓存与日志")
                ScopeCard(icon: "hammer", title: "开发构建", text: "Node.js、Android、iOS、macOS\nPython、Go、Java、.NET、Flutter")
                ScopeCard(icon: "cube.box", title: "Native Shell", text: "target、native/target\n.nsh/out 排除应用与安装包")
            }
            .frame(maxWidth: 700)
            Button("开始扫描") { model.startScan() }
                .buttonStyle(PrimaryButtonStyle())
                .controlSize(.large)
            Text(model.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ScopeCard: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ScanningView: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("正在扫描可清理内容")
                .font(.title2.weight(.semibold))
            Text("已发现 \(model.scanProgress.candidateCount) 项 · 仅读取目录与文件大小")
                .foregroundStyle(.secondary)
            Text((model.scanProgress.path as NSString).abbreviatingWithTildeInPath)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: 600)
            Button("取消扫描", role: .cancel) { model.cancelScan() }
            Spacer()
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CleaningView: View {
    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
            Text("正在移到废纸篓")
                .font(.title2.weight(.semibold))
            Text("请稍候，原始目录结构会按规则保留。")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SelectionBar: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("已选择 \(model.selectedItemCount) 项 · \(ByteFormatting.string(model.selectedByteCount))")
                    .font(.callout.weight(.medium))
                Text(model.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                model.isCleanConfirmationPresented = true
            } label: {
                Label("移到废纸篓", systemImage: "trash")
            }
            .buttonStyle(PrimaryButtonStyle(tint: .red))
            .disabled(model.selectedItemCount == 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct ResultsView: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索名称或完整路径", text: $model.searchText)
                    .textFieldStyle(.plain)
                if !model.searchText.isEmpty {
                    Button { model.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                Divider().frame(height: 18)
                Button("全选") { model.setSelection(true, for: model.visibleItems.map(\.id)) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.teal)
                Button("清空") { model.setSelection(false, for: model.visibleItems.map(\.id)) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.teal)
            }
            .padding(.horizontal, 22)
            .frame(height: 46)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()
            if model.visibleGroups.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("当前筛选条件下没有结果")
                    Button("清除筛选") {
                        model.searchText = ""
                        model.selectedCategory = nil
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.visibleGroups) { group in
                    Section {
                        ForEach(group.items) { item in
                            ResultRow(
                                item: item,
                                isSelected: model.selectedIDs.contains(item.id),
                                onToggle: { model.toggle(item) },
                                onReveal: { model.reveal(item) }
                            )
                            .equatable()
                            .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14))
                        }
                    } header: {
                        ResultGroupHeader(
                            group: group,
                            isSelected: model.isGroupSelected(group.items),
                            onSelectionChange: {
                                model.setSelection($0, for: group.items.map(\.id))
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14))
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var tint: Color = .teal

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(tint.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct ResultGroupHeader: View {
    let group: ResultGroup
    let isSelected: Bool
    let onSelectionChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { value in onSelectionChange(value) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
            Text(group.title)
                .font(.headline)
                .lineLimit(1)
            if let kind = group.kind {
                Text(kind.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            Spacer()
            Text(ByteFormatting.string(group.byteCount))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(height: 38)
    }

    private var iconName: String {
        switch group.category {
        case .system: "shippingbox"
        case .developer: group.kind == .nativeShell ? "cube.box" : "hammer"
        case .custom: "folder"
        }
    }

    private var iconColor: Color {
        switch group.category {
        case .system: .teal
        case .developer: .orange
        case .custom: .blue
        }
    }
}

private struct ResultRow: View, Equatable {
    let item: ScanItem
    let isSelected: Bool
    let onToggle: () -> Void
    let onReveal: () -> Void

    nonisolated static func == (lhs: ResultRow, rhs: ResultRow) -> Bool {
        lhs.item == rhs.item && lhs.isSelected == rhs.isSelected
    }

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text((item.url.path as NSString).abbreviatingWithTildeInPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 12)
            Text("\(item.fileCount) 个文件")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text(ByteFormatting.string(item.byteCount))
                .font(.callout.monospacedDigit())
                .frame(width: 82, alignment: .trailing)
            Button {
                onReveal()
            } label: {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("在 Finder 中显示")
        }
        .frame(height: 48)
    }
}
