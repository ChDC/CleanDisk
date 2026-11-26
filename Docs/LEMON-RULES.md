# Tencent Lemon 本地扫描规则逆向记录

## 样本与方法

- 样本：`/Applications/Tencent Lemon.app`
- 版本：5.1.1（1008），2020 年构建的 x86_64 / arm64 通用二进制。
- 主要模块：`Contents/Frameworks/LemonClener.framework` 与 `QMCoreFunction.framework`。
- 方法：读取 `Info.plist`，用 `strings` 提取路径与 Objective-C 类/方法名，用 `nm` / `otool` 核对扫描器符号与依赖。
- 核对时间：2026-11-26。

这里只记录样本内可静态确认的目录。Lemon 还有 `QMXMLParseManager`、知识库和云端配置，可能动态补充应用规则；不能把下面的列表当作它所有版本的完整云端规则库。

## 静态可见的垃圾目录

| Lemon 中的字符串或模式 | 用途 | CleanDisk 处理 |
| --- | --- | --- |
| `~/Library/Caches` | 用户应用缓存 | 扫描直接子项 |
| `~/Library/Containers/(.+)/Data/Library/Caches` | 沙盒应用缓存 | 遍历容器后扫描直接子项 |
| `~/Library/Containers/%@/Data/Library/Logs/` | 沙盒应用日志 | 遍历容器后扫描直接子项 |
| `~/Library/Logs/%@/` | 应用日志 | 统一扫描 `~/Library/Logs` 的直接子项 |
| `/Library/Developer/Xcode/DerivedData/` | Xcode 构建中间产物 | 映射到 `~/Library/Developer/Xcode/DerivedData` |
| `/Library/Developer/Xcode/Archives/` | Xcode 归档 | 不实现；Archives 是分发产物，不是中间垃圾 |
| `/.Trash` | 废纸篓 | 不纳入；本应用仅移到废纸篓，重复处理没有价值 |

还确认了 `QMDirectoryScan`、`QMXcodeScan`、`QMMailScan`、`QMSoftScan` 等扫描器，以及 `SystemTempDir`、`NSTemporaryDirectory`、邮件附件、浏览器配置和应用残留等动态逻辑。这些内容依赖运行环境、配置或进一步筛选，不是可直接照搬的固定垃圾目录，因此未做“整目录删除”。

`~/Library/Application Support/FireFox/`、企业微信 Profiles 等路径用于定位应用数据或残留，并不表示整个目录都是垃圾，未纳入本应用。

## 本次新增

固定缓存：

```text
~/.npm/_cacache
~/.cache
~/Library/Containers/com.apple.wallpaper.agent/Data/Library/Caches
~/.gradle/caches
~/.android/build-cache
~/.android/cache
~/Library/Caches/org.swift.swiftpm
~/Library/Caches/CocoaPods
~/.cargo/targets
```

项目构建产物通过项目标记识别，而不是全局按目录名盲目清理。

## Native Shell 规则依据

Native Shell 指 [nsh.dev](https://nsh.dev) 的 Longbridge Rust-first 原生 UI 框架（TSX + Rust），不是 Flutter 的 `nativeshell` embedder。

官方 [Project structure](https://nsh.dev/docs/project-structure.md) 文档确认：

- 项目根目录由 `nsh.json` 确定。
- `.nsh/` 是生成目录，`.nsh/out` 是 `nsh build` 默认输出，能够重新生成。
- `target/` 是 Cargo 构建目录。
- `.nsh/out` 也可能包含 `nsh package` 生成的 `.app`、`.ipa`、`.apk` 等可安装应用。

因此扫描器仅删除 `.nsh/out` 的直接非应用子项，同时在清理执行前再次拒绝应用和安装包。`native/target` 作为 Native Shell / 原生 Rust 模块的 Cargo 中间目录一并支持。
