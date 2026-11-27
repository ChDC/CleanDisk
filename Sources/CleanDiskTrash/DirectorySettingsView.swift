import AppKit
import CleanDiskTrashCore
import SwiftUI

struct DirectorySettingsView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var path = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("扫描目录")
                        .font(.title2.weight(.semibold))
                    Text("管理内置规则与用户自定义范围")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)

            Picker("", selection: $selectedTab) {
                Text("自定义目录").tag(0)
                Text("内置规则").tag(1)
                Text("访问权限").tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Divider()
            if selectedTab == 0 {
                customDirectories
            } else if selectedTab == 1 {
                builtInRules
            } else {
                PermissionSettingsContent()
                    .environmentObject(model)
            }
        }
        .frame(width: 720, height: 590)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var customDirectories: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("添加需要扫描的缓存或生成目录。清理时保留目录本身，仅处理其中的内容。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    TextField("例如 ~/Library/Caches/com.example.app", text: $path)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addPath)
                    Button("选择目录…", action: chooseDirectory)
                    Button("添加", action: addPath)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)

            Divider()
            if model.directories.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("还没有自定义目录")
                        .font(.headline)
                    Text("可以输入路径，或通过系统目录选择器添加。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(model.directories.enumerated()), id: \.element.id) { index, directory in
                            HStack(spacing: 12) {
                                Toggle("", isOn: Binding(
                                    get: { directory.isEnabled },
                                    set: { model.setDirectory(directory, enabled: $0) }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .controlSize(.small)
                                Image(systemName: "folder")
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(directory.url.lastPathComponent)
                                        .font(.callout.weight(.medium))
                                    Text((directory.path as NSString).abbreviatingWithTildeInPath)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Button {
                                    model.removeDirectory(directory)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)
                                .help("移出扫描规则，不删除磁盘目录")
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 62)
                            if index < model.directories.count - 1 {
                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                }
            }
            Divider()
            HStack {
                Image(systemName: "info.circle")
                Text("停用或移除只改变扫描规则，不会删除目录。主目录、系统目录与应用包不可添加。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(16)
        }
    }

    private var builtInRules: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield")
                    .foregroundStyle(.teal)
                Text("项目目录自动识别 Gradle、Xcode、SwiftPM、Cargo、CMake 与 nsh.json；Xcode Archives 不纳入清理。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(RuleCatalog.rules.enumerated()), id: \.element.id) { index, rule in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: rule.category == .developer ? "hammer" : "shippingbox")
                                .foregroundStyle(rule.category == .developer ? .orange : .teal)
                                .frame(width: 20)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rule.title)
                                    .font(.callout.weight(.medium))
                                Text(rule.path)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                Text(rule.detail)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        if index < RuleCatalog.rules.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }
        }
    }

    private func addPath() {
        let value = path
        model.addDirectory(path: value)
        if model.directories.contains(where: {
            $0.path == (value as NSString).expandingTildeInPath
        }) {
            path = ""
        }
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择扫描目录"
        panel.prompt = "添加目录"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            model.addDirectory(url: url)
        }
    }
}
