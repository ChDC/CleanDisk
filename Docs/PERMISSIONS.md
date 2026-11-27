# 文件夹访问权限

## 为什么之前会反复询问

早期构建使用 `codesign --sign -` 生成临时（ad hoc）签名，没有 Team ID。重新构建后，macOS 可能把应用视为新的身份，再次询问 Documents、Desktop、Downloads 等受保护目录。

## 现在的处理

`Scripts/build-app.sh` 会优先使用 `CODE_SIGN_IDENTITY`，未设置时自动选择本机的 Apple Development 或 Developer ID Application 证书。只要后续版本继续使用同一证书和 Bundle ID，应用身份就保持稳定。

```sh
CODE_SIGN_IDENTITY="Developer ID Application: ..." ./Scripts/build-app.sh
```

没有证书时仍能构建 ad hoc 包，但脚本会提示 macOS 可能重新请求目录权限。

## 只授权一次

首次启动的权限引导会打开“系统设置 › 隐私与安全性 › 完全磁盘访问”。用户在这里手动启用 CleanDisk 后，扫描不再需要逐目录确认。入口也保留在“管理扫描目录 › 访问权限”。

macOS 不允许应用自行打开此权限。CleanDisk 只负责打开对应设置页，不会绕过授权，也不会读取或上传账户信息。

不开启完全磁盘访问仍可使用应用，但 macOS 可能按目录询问，未授权目录会在扫描时跳过。撤销权限、修改 Bundle ID、改变签名证书或系统重置隐私数据库后，需要重新授权。

应用没有启用 App Sandbox，因此不使用只适用于沙盒应用的 security-scoped bookmark 作为权限方案。
