import SwiftUI

struct PermissionGuideView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "lock.shield")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.teal)
                .padding(.top, 8)

            VStack(spacing: 9) {
                Text("让扫描只授权一次")
                    .font(.title2.weight(.semibold))
                Text("在系统设置中为 CleanDisk 开启一次“完全磁盘访问”，无需在每次扫描时逐个确认文件夹。")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 420)
            }

            VStack(alignment: .leading, spacing: 12) {
                PermissionPoint(icon: "checkmark.circle", text: "一次开启，后续扫描直接使用授权范围")
                PermissionPoint(icon: "signature", text: "稳定签名让版本更新后仍保持同一应用身份")
                PermissionPoint(icon: "eye.slash", text: "目录与文件内容仅在本机处理，不会上传")
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(spacing: 10) {
                Button("打开完全磁盘访问设置") {
                    model.openFullDiskAccessSettings()
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("暂不") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }

            Text("在“隐私与安全性 › 完全磁盘访问”中启用 CleanDisk。也可随时通过“管理扫描目录 › 访问权限”重新打开。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(width: 540, height: 480)
    }
}

struct PermissionSettingsContent: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.teal)
            Text("一次授权，持续扫描")
                .font(.title2.weight(.semibold))
            Text("macOS 将目录访问权限与应用签名关联。CleanDisk 使用稳定签名，并在系统层面使用“完全磁盘访问”覆盖扫描所需目录，避免 Documents、Desktop、Downloads 等位置分别询问。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            PermissionPoint(icon: "checkmark.circle", text: "授权只会在系统设置中发生，应用不会代替你开启权限")
            PermissionPoint(icon: "arrow.triangle.2.circlepath", text: "使用同一证书发布的后续版本会保留应用身份")
            Button("打开完全磁盘访问设置") {
                model.openFullDiskAccessSettings()
            }
            .buttonStyle(PrimaryButtonStyle())
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct PermissionPoint: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.teal)
                .frame(width: 20)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
