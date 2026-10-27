# 安装、升级与卸载

[文档首页](../README.md) · [English](../en/installation.md)

## 安装与来源

只从[项目正式发布](https://github.com/WECLwhy/AstraCreate/releases/latest)获取安装包、源码 ZIP 和 SHA256SUMS。三个文件放在同一目录，在终端中进入该目录后运行：

```zsh
shasum -a 256 -c AstraCreate-3.00-SHA256SUMS.txt
```

更高版本请使用对应文件名。校验失败时停止安装。包使用 ad-hoc 签名，没有 Developer ID 签名或 Apple 公证；系统可能拦截，校验和也不能代替发布者身份认证。请阅读 [Apple 的说明](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac)，由自己决定是否授权；不要关闭 Gatekeeper 或运行来源不明的修复命令。

打开 PKG 并完成系统授权。安装目标为 `/Applications/AstraCreate.app`；安装器会尝试重启当前用户的 Finder，请先结束正在进行的 Finder 操作。密码只在 macOS 系统窗口中输入。

## 启用扩展

- macOS 15 及更新系统：系统设置 → 通用 → 登录项与扩展 → 扩展 → Finder。
- macOS 13/14：系统设置 → 隐私与安全性 → 扩展 → Finder 扩展。

启用“新建常用文件”。不同系统的小标题可能不同，可从 App 的“诊断与支持 → 打开扩展设置…”进入。系统显示已启用不代表菜单已经加载，请在普通文件夹验证。

## 升级

新包覆盖旧 App，保留原有设置；七种开发格式新增时默认关闭。检查更新必须用户同意才下载，最终安装仍由系统安装器完成。从 2.16 之前版本升级时，未粘贴的剪切项目需要重新选择。

## 卸载

先在系统设置关闭扩展并退出 App，再用 Finder 将 `/Applications/AstraCreate.app` 移到废纸篓。卸载 App 不删除你已创建的文档，也不自动清空偏好、日志或待移动队列。可暂时保留这些数据用于重装或排障；如需进一步清理，先查看[隐私说明](../../PRIVACY.md)，核对文件用途并自行备份，不要直接删除整个容器。
