# 大结果集无响应排查

## 现象与证据

- 用户界面无响应，进程持续占用约一个 CPU 核。
- `sample` 显示主线程反复进入 `GraphHost.flushTransactions`、`RootGeometry.value.getter` 和 SwiftUI Stack 布局。
- 原始采样还出现 `LazyLayoutViewCache.updateItemPhases` 与 `signalPrefetch → requestUpdate`，表明懒布局预取持续触发后续更新。
- 5000 项调试数据下，首次单项勾选约 22 秒，进程内存峰值接近 2.8 GB。

## 根因

结果区只按“组”懒加载，组内所有行却由 `ForEach` 立即创建。勾选又会修改整个 `ObservableObject`，导致所有分组重新计算、排序和布局。文件大小格式化器、路径缩写和选择汇总也在各行反复创建或计算，进一步放大主线程负担。

## 修复

- 用系统 `List` 替换嵌套 `ScrollView` / `LazyVStack`，按行复用视图。
- 给右侧内容和结果列表明确的弹性边界，减少根布局的 intrinsic-size 协商。
- 在 `AppViewModel` 中缓存分组、分类计数、总大小和选择汇总；仅在数据、筛选或选择变化时更新。
- 结果行不再观察整个 ViewModel，通过输入值和回调接收状态；未变化的行使用 `Equatable` 跳过刷新。
- 复用 `ByteCountFormatter`，`ScanItem.id` 直接使用初始化时已标准化的 URL 路径。
- 在 `FileSizer` 的每个目录遍历边界调用 `autoreleasepool`，避免大缓存扫描期间临时 URL 对象积累到整个扫描结束。

## 验证

- DEBUG 启动参数 `-StressResults5000` 可生成 100 组、5000 项结果，不访问或删除对应文件。
- 5000 项初始内存约 100 MB；单项勾选包含无障碍状态读取约 1.2 秒内完成。
- 单项/整组勾选、搜索、清空筛选和滚动后，CPU 回落到 0。
- 后续采样未再出现持续的 `updateItemPhases` / `signalPrefetch` 循环。
- 12 项核心测试保持通过。

性能数据只用于同机前后对照，不作为所有设备的绝对指标。
