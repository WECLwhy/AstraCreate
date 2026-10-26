# Privacy / 隐私说明

## 中文

AstraCreate 的所审查源码没有遥测、账号登录或向服务器上传文件的实现。文件操作在本机执行；打开终端或 VS Code 后由对应应用处理。复制路径会写入系统剪贴板。

设置保存在本地，包括外观模式和两套配色/透明度。剪切队列 `clipboard.json` 为移动功能保存所选项目的绝对路径，位于 Finder 扩展容器的 `Library/Application Support/AstraCreate` 下；移动完成后成功项目会从队列移除，失败项保留重试。队列不是加密保险箱，不应公开分享。旧版 helper 的兼容队列位于临时目录。

3.00 中的“检查更新…”由用户点击触发，通过 HTTPS 访问 GitHub API；不会定时后台检查。GitHub 会收到常规连接信息（例如 IP、User-Agent）；不发送诊断日志、用户文件、剪切队列或本地路径。仅在用户同意“下载并安装…”后获取该项目的安装包及必要校验文件。下载可跳转至 GitHub 官方发布资源域名，使用系统证书验证，不附带账号凭据。

安装包在 `~/Library/Caches/AstraCreate/Updates` 的独立目录中暂存，校验失败或取消会清理本次目录；通过校验的包保留供系统安装器读取。下载包保留隔离/来源标记，不能绕过 macOS 安装授权或安全检查。“GitHub 项目主页”及发布页按钮会交给默认浏览器打开。

已发布的 2.16 build 29 和 2.17 不写诊断日志。3.00（2026-10-26）增加本地结构化错误日志：只记录时间、组件、软件版本/构建号、固定事件名称、数字结果和标准错误域/错误代码，不记录文件路径、选中文件名、文件内容、命令参数、URL、剪贴板/剪切队列或错误描述原文。

主程序和旧 helper 的新日志保存在 `~/Library/Application Support/AstraCreate/Diagnostics-v1`；Finder 扩展的新日志保存在其沙盒容器内同名目录。每个组件最多保留 256 KiB，达到上限时保留近期完整记录。新目录权限为 0700，新日志文件权限为 0600。日志写入失败不阻止原本的文件操作。

设置中的“导出诊断日志…”由用户手动选择位置，生成单个 JSON 文件，含软件/系统版本、CPU 架构、扩展启用状态、扩展是否随 App 打包及三个组件的新日志。缺失或不可读日志会标记状态，不代表相应组件运行正常。导出时再次筛选允许的字段，不包含原始系统日志或签名/注册命令输出，不会自动上传；用户自行将文件发给开发者。

升级不会自动删除历史日志：旧主程序使用 `/tmp/AstraCreateHost.log`，扩展使用其容器下的 `Library/Application Support/AstraCreate/extension.log`。这些历史日志可能含文件路径，请勿直接上传；新的导出功能不会读取它们。

发布源码包按明确的目录清单打包，并排除 Git 元数据、构建缓存、日志、常见凭据与本地状态。模板作者信息和 PNG 非视觉元数据已清理。GitHub 仓库的 Git 历史仍会公开提交者姓名、邮箱及历史文件内容；当前文件清理不等于历史删除。

报告问题可使用“导出诊断日志…”，并附上复现步骤和已脱敏截图。不要附带剪切队列、完整容器目录或未经检查的系统诊断文件。

## English

The reviewed AstraCreate source implements no telemetry, account login or server uploads. File operations run locally; Terminal and VS Code handle their own behavior when opened. Copy Path writes to the system clipboard.

Preferences, including appearance mode and separate light/dark palettes and transparency, are stored locally. The pending-move `clipboard.json` stores absolute selected paths under the Finder extension container’s `Library/Application Support/AstraCreate`. Successful moves are removed, while failures remain for retry. This queue is not encrypted storage and should not be shared. The legacy helper uses a separate temporary queue.

In 3.00, Check for Updates runs only when clicked and contacts the GitHub API over HTTPS; there is no periodic background check. GitHub receives normal connection data such as IP address and User-Agent, never diagnostic logs, user files, pending moves or local paths. Installer and necessary checksum transfers start only after Download & Install consent. Downloads may redirect to official GitHub release asset hosts, using normal system certificate validation with no account credentials.

Each download uses a private staging directory under `~/Library/Caches/AstraCreate/Updates`. Failed or cancelled attempts remove their own staging directory; verified packages remain for macOS Installer to read. Downloads retain quarantine/origin metadata and do not bypass macOS authorization or security checks. Project/release page buttons open the default browser.

Published 2.16 build 29 and 2.17 do not write diagnostic logs. Version 3.00 (2026-10-26) adds local structured logs containing timestamps, component, version/build, fixed event names, numeric results and standard error domains/codes. It excludes file paths/names, file contents, command arguments, URLs, clipboard/pending-move contents and original error descriptions.

New host/helper logs live under `~/Library/Application Support/AstraCreate/Diagnostics-v1`; the extension uses the same relative directory in its sandbox. Each component retains at most 256 KiB, keeping recent complete records when the limit is reached. New directories use mode 0700 and new files use mode 0600. Log failures do not block file operations.

Export Diagnostic Logs lets the user save one JSON file containing app/system versions, CPU architecture, enabled/embedded extension status and the three new component logs. Missing or unreadable logs are explicitly marked, not treated as evidence of successful execution. Fields are filtered again during export. Raw system logs and signing/registration command output are excluded. The app never uploads the report; users choose whether to send it to the developer.

Upgrading does not remove historical logs: the host previously used `/tmp/AstraCreateHost.log`, and the extension used `Library/Application Support/AstraCreate/extension.log` within its container. These may contain private paths and are never read by the new exporter.

Source archives use an explicit input list and exclude Git metadata, build caches, logs, common credentials and local state. Template author fields and nonvisual PNG metadata have been removed. Git history still exposes commit identities and historical file content; cleaning current files does not erase history.

Use Export Diagnostic Logs with reproduction steps and redacted screenshots. Do not share clipboard queues, entire containers or unreviewed system diagnostics.
