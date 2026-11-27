# CleanDisk 项目规则

- `secrets/release.env` 可保存 Gitee 发布令牌，但 GitHub 源码仓库必须保持私有。发版脚本优先读环境变量，再读此文件；禁止在日志、提交说明、Issue 或聊天中输出令牌值。

- 扫描器必须保持只读；删除统一使用 `TrashCleaner` 移到废纸篓，禁止直接 `removeItem` 处理用户扫描结果。
- 新增项目类型时必须有项目标记，不允许只凭 `build`、`target` 等通用目录名判定垃圾。
- Native Shell 是 https://nsh.dev 的 Longbridge Rust-first 原生 UI 框架。`.nsh/out` 下的应用与安装包必须在扫描和清理两层都排除。
- 缓存与自定义目录采用“处理子项、保留根目录”策略。重复路径只处理一次，符号链接不跟随。
- 修改扫描、清理或安全策略后运行 `swift test`；修改界面后构建并启动 `dist/CleanDisk.app` 做实际检查。
- macOS 26 实测中，`windowToolbarStyle(.unified)` 会遮挡此应用的顶部自定义内容，原生 `borderedProminent` 与自动分栏宽度也出现渲染异常；顶部布局变更必须截图复核，主要按钮使用项目内 `PrimaryButtonStyle`，侧栏保持固定宽度。
- 大结果集不得使用“组级懒加载、组内全量行”的嵌套 `LazyVStack`；结果列表使用系统 `List` 复用行。派生分组与格式化结果不得在每行反复计算，修改后使用 `-StressResults5000` 验证勾选、筛选、滚动及空闲 CPU。
- Swift 6.3 下不要把存储的 `@MainActor` 回调直接传给 `Binding` setter（本次触发编译器 IRGen crash）；回调保持普通函数类型，并在 setter 闭包内显式调用。
- 同一视图层不要叠加多个 `.alert(item:)`（更新实测会吞掉先注册的结果提示）；普通消息与新版本提示统一使用一个带可选操作的 `AppAlert`。
- 更新学城文档前先重新拉取最新内容，编辑后再次拉取复核，禁止用本地缓存覆盖新修改。
