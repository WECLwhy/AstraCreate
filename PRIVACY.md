# Privacy / 隐私说明

## 中文

AstraCreate 的所审查源码没有遥测、账号登录或向服务器上传文件的实现。文件操作在本机执行；打开终端或 VS Code 后由对应应用处理。复制路径会写入系统剪贴板。

设置保存在本地。剪切队列 `clipboard.json` 为移动功能保存所选项目的绝对路径，位于 Finder 扩展容器的 `Library/Application Support/AstraCreate` 下；移动完成后成功项目会从队列移除，失败项保留重试。队列不是加密保险箱，不应公开分享。旧版 helper 的兼容队列位于临时目录。

从 2.16 build 29 起，主程序、Finder 扩展和旧 helper 不再写入诊断日志。升级不会自动删除旧日志：旧主程序使用 `/tmp/AstraCreateHost.log`，扩展使用其容器下的 `Library/Application Support/AstraCreate/extension.log`。这些历史日志可能含文件路径，请勿直接上传。

发布源码包按明确的目录清单打包，并排除 Git 元数据、构建缓存、日志、常见凭据与本地状态。模板作者信息和 PNG 非视觉元数据已清理。GitHub 仓库的 Git 历史仍会公开提交者姓名、邮箱及历史文件内容；当前文件清理不等于历史删除。

报告问题请尽量只提供复现步骤和已脱敏截图，不要附带剪切队列、完整容器目录或未经检查的系统诊断文件。

## English

The reviewed AstraCreate source implements no telemetry, account login or server uploads. File operations run locally; Terminal and VS Code handle their own behavior when opened. Copy Path writes to the system clipboard.

Preferences are stored locally. The pending-move `clipboard.json` stores absolute selected paths under the Finder extension container’s `Library/Application Support/AstraCreate`. Successful moves are removed, while failures remain for retry. This queue is not encrypted storage and should not be shared. The legacy helper uses a separate temporary queue.

Starting with 2.16 build 29, the host, extension and legacy helper do not write diagnostic logs. Upgrading does not remove old logs: the host previously used `/tmp/AstraCreateHost.log`, and the extension used `Library/Application Support/AstraCreate/extension.log` within its container. Historical logs may contain private paths.

Source archives use an explicit input list and exclude Git metadata, build caches, logs, common credentials and local state. Template author fields and nonvisual PNG metadata have been removed. Git history still exposes commit identities and historical file content; cleaning current files does not erase history.

Share reproduction steps and redacted screenshots, rather than clipboard queues, entire containers or unreviewed system diagnostics.
