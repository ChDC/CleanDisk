import Foundation

public enum RuleCatalog {
    /// Local paths recovered from Lemon 5.1.1 plus explicit development-tool additions.
    /// Xcode Archives are deliberately absent: they are distribution products, not intermediates.
    public static let rules: [BuiltInRule] = [
        BuiltInRule(
            id: "developer.xcode-derived-data",
            title: "Xcode DerivedData",
            path: "~/Library/Developer/Xcode/DerivedData",
            detail: "Lemon 同类规则；索引、编译缓存和中间产物",
            category: .developer
        ),
        BuiltInRule(
            id: "developer.xcode-cache",
            title: "Xcode 缓存",
            path: "~/Library/Caches/com.apple.dt.Xcode",
            detail: "Xcode 可重新生成的用户缓存",
            category: .developer
        ),
        BuiltInRule(
            id: "developer.swiftpm-cache",
            title: "SwiftPM 缓存",
            path: "~/Library/Caches/org.swift.swiftpm",
            detail: "Swift Package Manager 下载与构建缓存",
            category: .developer
        ),
        BuiltInRule(
            id: "developer.cocoapods-cache",
            title: "CocoaPods 缓存",
            path: "~/Library/Caches/CocoaPods",
            detail: "CocoaPods 可重新下载的缓存",
            category: .developer
        ),
        BuiltInRule(
            id: "developer.gradle-cache",
            title: "Gradle 构建缓存",
            path: "~/.gradle/caches",
            detail: "Android 与 JVM 项目的 Gradle 缓存",
            category: .developer
        ),
        BuiltInRule(
            id: "developer.android-build-cache",
            title: "Android 构建缓存",
            path: "~/.android/build-cache",
            detail: "旧版 Android SDK 构建缓存",
            category: .developer
        ),
        BuiltInRule(
            id: "developer.android-cache",
            title: "Android 工具缓存",
            path: "~/.android/cache",
            detail: "Android SDK 工具生成的缓存",
            category: .developer
        ),
        BuiltInRule(
            id: "developer.cargo-targets",
            title: "Cargo 共享构建目录",
            path: "~/.cargo/targets",
            detail: "Cargo 与 Native Shell 可重新编译的共享产物",
            category: .developer
        ),
        BuiltInRule(
            id: "developer.yarn-cache",
            title: "Yarn 缓存",
            path: "~/Library/Caches/Yarn",
            detail: "Yarn Classic 可重新下载的包缓存",
            category: .developer
        ),
        BuiltInRule(
            id: "developer.yarn-berry-cache",
            title: "Yarn Berry 全局缓存",
            path: "~/.yarn/cache",
            detail: "Yarn Berry 全局包缓存",
            category: .developer
        ),
        BuiltInRule(
            id: "developer.pnpm-store",
            title: "pnpm 内容存储",
            path: "~/Library/pnpm/store",
            detail: "pnpm 可重新生成的内容寻址存储",
            category: .developer
        ),
        BuiltInRule(
            id: "developer.pnpm-legacy-store",
            title: "pnpm 旧版内容存储",
            path: "~/.pnpm-store",
            detail: "旧版 pnpm 默认内容存储",
            category: .developer
        ),
        BuiltInRule(
            id: "developer.bun-cache",
            title: "Bun 包缓存",
            path: "~/.bun/install/cache",
            detail: "Bun 可重新下载的包缓存",
            category: .developer
        ),
        BuiltInRule(
            id: "developer.pip-cache",
            title: "pip 缓存",
            path: "~/Library/Caches/pip",
            detail: "pip 下载与 wheel 构建缓存",
            category: .developer
        ),
        BuiltInRule(
            id: "developer.pip-xdg-cache",
            title: "pip XDG 缓存",
            path: "~/.cache/pip",
            detail: "使用 XDG 路径的 pip 缓存",
            category: .developer
        ),
        BuiltInRule(
            id: "developer.go-build-cache",
            title: "Go 构建缓存",
            path: "~/Library/Caches/go-build",
            detail: "Go 编译器可重新生成的构建缓存",
            category: .developer
        ),
        BuiltInRule(
            id: "system.npm-cache",
            title: "npm 内容缓存",
            path: "~/.npm/_cacache",
            detail: "npm 可重新下载的内容寻址缓存",
            category: .system
        ),
        BuiltInRule(
            id: "system.user-cache",
            title: "用户通用缓存",
            path: "~/.cache",
            detail: "遵循 XDG 缓存约定的应用缓存",
            category: .system
        ),
        BuiltInRule(
            id: "system.wallpaper-cache",
            title: "壁纸服务缓存",
            path: "~/Library/Containers/com.apple.wallpaper.agent/Data/Library/Caches",
            detail: "macOS 壁纸服务容器内的缓存",
            category: .system
        ),
        BuiltInRule(
            id: "system.library-caches",
            title: "应用缓存",
            path: "~/Library/Caches",
            detail: "Lemon 本地规则；不包含 Xcode 等已归类项目",
            category: .system
        ),
        BuiltInRule(
            id: "system.library-logs",
            title: "应用日志",
            path: "~/Library/Logs",
            detail: "Lemon 本地规则中的应用日志目录",
            category: .system
        ),
        BuiltInRule(
            id: "system.container-caches",
            title: "应用容器缓存",
            path: "~/Library/Containers/*/Data/Library/Caches",
            detail: "Lemon 本地规则；逐个扫描沙盒容器缓存",
            category: .system
        ),
        BuiltInRule(
            id: "system.container-logs",
            title: "应用容器日志",
            path: "~/Library/Containers/*/Data/Library/Logs",
            detail: "Lemon 本地规则；逐个扫描沙盒容器日志",
            category: .system
        ),
    ]

    public static func url(for rule: BuiltInRule, home: URL) -> URL {
        let relative = rule.path.hasPrefix("~/") ? String(rule.path.dropFirst(2)) : rule.path
        return home.appendingPathComponent(relative, isDirectory: true).standardizedFileURL
    }

    public static func containsBuiltInRoot(_ url: URL, home: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return rules.contains { rule in
            guard !rule.path.contains("*") else { return false }
            return self.url(for: rule, home: home).path == path
        }
    }
}
