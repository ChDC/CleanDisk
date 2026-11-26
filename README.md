# CleanDisk

一个原生 macOS 磁盘清理工具。基于 Tencent Lemon 5.1.1 本地可见的扫描规则，扩展常用开发缓存、Android / iOS / macOS 原生构建产物，以及 [Native Shell](https://nsh.dev)（Longbridge 的 Rust-first 原生 UI 框架）的构建目录。

## 运行

需要 macOS 14 或更高版本，以及 Xcode 15 或更高版本。

```sh
make test
make run
```

也可以只构建应用：

```sh
./Scripts/build-app.sh
open dist/CleanDisk.app
```

## 扫描范围

- Lemon 本地规则：`~/Library/Caches`、`~/Library/Logs`、各应用容器的 `Data/Library/Caches` 与 `Data/Library/Logs`、Xcode DerivedData。
- 新增缓存：`~/.npm/_cacache`、`~/.cache`、`~/Library/Containers/com.apple.wallpaper.agent/Data/Library/Caches`。
- 开发工具：Xcode、SwiftPM、CocoaPods、Gradle、Android SDK 和 Cargo 共享缓存。
- Android：有 Gradle 标记的项目或模块中的 `build`、`.gradle`、`.cxx`。
- iOS / macOS：有 Xcode 或 SwiftPM 标记的项目中的 `build`、`.build`、`DerivedData`。
- 原生 C/C++：有 CMake 标记的项目中的 `build`、`cmake-build-*`。
- Rust：有 `Cargo.toml` 的项目中的 `target`。
- Native Shell：有 `nsh.json` 的项目中的 `target`、`native/target` 和 `.nsh/out` 的非应用产物。
- Node.js：有 `package.json` 或锁文件的项目中的 `node_modules`、`dist`、`build`、`coverage`、`.yarn/cache`，以及 Next.js、Nuxt、SvelteKit、Astro、Vite、Turbo、Parcel、Rollup、SWC、Expo、Angular 等生成目录。
- Python：`__pycache__`、pytest / mypy / Ruff / tox / nox 缓存、`build`、`dist`、`htmlcov` 和 `*.egg-info`。
- Go / Java / .NET：Go 项目的 `bin`、Maven 项目的 `target`、.NET 项目的 `bin`、`obj`、`TestResults`。
- Flutter / Dart：有 `pubspec.yaml` 的项目中的 `build` 和 `.dart_tool`。
- 其他开发缓存：Yarn、pnpm、Bun、pip 和 Go 构建缓存。

`node_modules` 等依赖目录可通过对应包管理器重新安装。所有结果仍需手动确认后才会移到废纸篓。

项目发现从用户主目录开始，最多向下 10 层；跳过 `Library`、媒体目录、依赖目录、版本控制元数据、符号链接和隐藏目录。无项目标记的同名 `build` / `target` 不会被当作垃圾。

`.nsh/out` 中任意层级的 `.app`、`.ipa`、`.apk`、`.aab`、`.dmg`、`.pkg`、`.exe`、`.msi`、`.msix` 和 `.nshpkg` 始终排除，包含这些文件的父目录也不会作为清理项。Xcode Archives 不属于中间产物，也不扫描。

## 自定义目录

点击“添加目录”或“管理扫描目录”，输入路径或使用系统目录选择器。自定义目录支持启用、停用和移除，设置保存在：

```text
~/Library/Application Support/CleanDiskTrash/custom-directories.json
```

自定义规则保留目录本身，扫描并处理其中的直接子项。停用或移除规则不会删除磁盘文件。主目录、系统目录、应用包和已有的内置目录不可添加。

## 清理安全

- 扫描只读，不修改文件。
- 默认勾选结果，但可以按组或逐项调整，并在 Finder 中检查。
- 清理仅调用 macOS 的“移到废纸篓”，不直接永久删除。
- 清理前再次校验受保护路径、符号链接与 Native Shell 应用输出。
- 嵌套或重复规则只统计、清理一次；缓存根目录和自定义根目录保留。
- 某些系统或应用目录可能需要“完全磁盘访问权限”；无权限目录会跳过。

详细逆向依据见 [Docs/LEMON-RULES.md](Docs/LEMON-RULES.md)。
大结果集的无响应排查与压力验证见 [Docs/PERFORMANCE.md](Docs/PERFORMANCE.md)。

## 检查更新

应用启动后、回到前台时及运行期间每 30 分钟检查 Gitee 更新源，也可以从 CleanDisk 菜单或左侧栏手动选择“检查更新”。

更新地址、清单格式和发布约定见 [Docs/UPDATES.md](Docs/UPDATES.md)。
