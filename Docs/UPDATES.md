# 检查更新

更新协议沿用 hongguoapp 的 Gitee 清单约定，但 CleanDisk 发布的是 macOS 包，不使用 Android APK 的安装流程。

## 更新地址

- 仓库：`https://gitee.com/lanshanshu/release`
- Bundle ID：`com.cleandisktrash.app`
- 应用代号：Bundle ID 的 MD5，即 `633a445def67474255ed5b9897252510`
- 清单：`https://gitee.com/lanshanshu/release/raw/master/latest/633a445def67474255ed5b9897252510.json`

使用 raw 地址而不是需要令牌的 API，应用不携带任何仓库写入凭据。清单不存在（404）表示尚未发布，不视为错误。

## 清单格式

```json
{
  "version": "1.1.0",
  "build": 2,
  "notes": "更新说明",
  "url": "https://gitee.com/lanshanshu/release/releases/download/633a445def67474255ed5b9897252510.2/633a445def67474255ed5b9897252510.zip"
}
```

`urls` 数组可以替代 `url` 或与其同时存在。应用去重后采用第一个有效地址，仅接受 `https://gitee.com` 和 `https://*.giteeusercontent.com`，避免更新清单把用户引向非 Gitee 来源。

`build` 是必须递增的整数，也是判断新版本的依据。`version` 和 `notes` 用于更新提示。

## 检查策略

- 应用进入前台时检查一次，自动检查之间至少间隔 10 分钟。
- 应用运行期间每 30 分钟检查一次。
- 菜单栏和左侧栏均可手动检查，手动检查不受上述间隔限制。
- 自动检查失败保持静默；手动检查会显示网络、服务器或清单错误。
- 同一后台版本只提示一次，手动检查仍可再次显示。

点击“下载更新”使用默认浏览器打开 Gitee 下载地址。应用不会自动下载、替换或安装未经验证的 macOS 包。
