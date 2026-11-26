import SwiftUI
import CleanDiskTrashCore

@main
struct CleanDiskTrashApp: App {
    @StateObject private var model = AppViewModel()

    var body: some Scene {
        WindowGroup("CleanDisk") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 660)
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("开始扫描") { model.startScan() }
                    .keyboardShortcut("r", modifiers: [.command])
                    .disabled(model.isScanning || model.isCleaning)
                Button("添加扫描目录…") { model.isSettingsPresented = true }
                    .keyboardShortcut("o", modifiers: [.command])
            }
            CommandGroup(after: .appInfo) {
                Button("检查更新…") { model.checkForUpdates(manual: true) }
                    .disabled(model.isCheckingForUpdates)
            }
        }
    }
}
