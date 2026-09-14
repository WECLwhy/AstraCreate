# AstraCreate 2.16

## 中文

AstraCreate for macOS（星域新建）是一个 macOS Finder 右键菜单工具。安装后，可以在 Finder 文件夹空白处或选中文件后右键，快速新建常用文件、打开终端或 VS Code，并进行剪贴、粘贴和复制绝对路径等操作。

### 本次更新（自 2.14 起）

- 新建文件默认折叠为可配置的二级菜单，移除扩展多余分隔项，减少空白条。
- 新增 Finder 工具栏按钮，可展开文件操作及设置；可通过 Finder“自定工具栏”添加或调整位置。
- 设置界面分组、统一对齐，保留原有语言与功能开关。
- 剪切在扩展内记录，不唤起主程序；粘贴时才移动，菜单显示待移动数量。
- 同目录粘贴不改名，重名自动编号，部分失败保留失败项供重试并提示。
- 关闭发布版诊断日志写入，清理 Office 模板作者和图片非视觉元数据。

### 版本与系统要求

- 版本：2.16；构建号：29；日期：2026-09-14。
- macOS 13 或更高版本，Apple Silicon（arm64）；未提供 Intel 构建。
- MIT 许可证。安装包未使用 Developer ID 签名，未公证。

### 功能

- 新建 Word 文档 `.docx`
- 新建 Excel 表格 `.xlsx`
- 新建 PowerPoint 演示文稿 `.pptx`
- 新建文本文件 `.txt`
- 新建 Markdown 文件 `.md`
- 在当前文件夹打开终端
- 在 VS Code 打开当前文件夹
- 剪贴选中的文件或文件夹
- 粘贴到当前文件夹
- 复制选中文件或当前文件夹的绝对路径
- 支持中文 / English 切换

### 安装

下载并打开 `AstraCreate-2.16.pkg`。

当前安装包为本地 ad-hoc 构建，未使用 Apple Developer ID 签名。首次安装时 macOS 可能会显示安全确认。

如果右键菜单没有出现，请打开：

`系统设置 -> 隐私与安全性 -> 扩展 -> Finder 扩展`

确认 AstraCreate 对应扩展已启用。

### 升级与使用注意

直接安装覆盖旧版，安装器会重启 Finder；请先完成 Finder 中正在进行的操作。原有设置保留，旧版尚未粘贴的剪切项目需重新选择。待移动队列独立于系统剪贴板。设置修改后重新打开菜单生效；“修复菜单显示…”仅用于故障排查。

### 验证与已知问题

已通过 12,288 组菜单组合、设置兼容性与真实文件移动测试。构建 28 已完成本机 Finder 工具栏、新建、剪切、同目录与跨目录移动验证；构建 29 在此基础上清理隐私元数据与日志，已重新构建并运行自动化检查，尚未重新安装进行完整 UI 回归。

一次本机跨目录移动曾延迟约 5 分钟，重新启动已安装版本后再次测试即时完成，原因尚未确认。移动目前没有进度显示，发生等待时请先核对源、目标目录，不要连续重复操作。尚未完成各支持系统版本、Intel、浅色及 VoiceOver 全覆盖验证。

### 下载文件与校验

- `AstraCreate-2.16.pkg`：安装包。
- `AstraCreate-Finder-2.16-source.zip`：源码，含构建、测试脚本与 MIT 许可证。
- `AstraCreate-2.16-SHA256SUMS.txt`：SHA-256 校验清单。

将三个文件放在同一目录，运行 `shasum -a 256 -c AstraCreate-2.16-SHA256SUMS.txt` 验证。源码构建：`./scripts/build.sh`；测试：`./scripts/test.sh`；打包：`./scripts/package.sh dist`。

反馈问题请提供系统版本、芯片、复现步骤；截图请遮盖用户名、私人文件名与路径。隐私说明见源码中的 `PRIVACY.md`。

---

## English

AstraCreate for macOS is a Finder context menu utility for macOS. After installation, you can right-click a blank area in Finder or selected items to quickly create common files, open Terminal or VS Code, cut and paste files, and copy absolute paths.

### Changes since 2.14

- Group new-file actions in a configurable submenu and remove extra extension separators.
- Add a native Finder toolbar menu with file actions and Settings; add or reposition it using Customize Toolbar.
- Group and align settings while preserving existing language and feature preferences.
- Record Cut in the extension without launching the host. Move files only on paste and show the pending count.
- Keep same-folder filenames unchanged, number collisions, and retain failed moves for retry with an error message.
- Disable diagnostic log writes in release builds and remove author/image metadata from bundled resources.

### Version and requirements

- Version 2.16; build 29; date: 2026-09-14.
- macOS 13 or later, Apple Silicon (arm64); no Intel build is provided.
- MIT license. The package has no Developer ID signature or notarization.

### Features

- Create Word documents `.docx`
- Create Excel workbooks `.xlsx`
- Create PowerPoint presentations `.pptx`
- Create text files `.txt`
- Create Markdown files `.md`
- Open Terminal in the current folder
- Open the current folder in VS Code
- Cut selected files or folders
- Paste into the current folder
- Copy absolute paths for selected items or the current folder
- Chinese / English language switching

### Installation

Download and open `AstraCreate-2.16.pkg`.

This package is locally built with ad-hoc signing and is not signed with an Apple Developer ID. macOS may show a security confirmation on first install.

If the Finder context menu does not appear, open:

`System Settings -> Privacy & Security -> Extensions -> Finder Extensions`

Then make sure the AstraCreate Finder extension is enabled.

### Upgrade and usage notes

Install over the previous version. The installer restarts Finder; finish active Finder operations first. Existing preferences are retained, but pending cuts from older versions must be selected again. The pending-move queue is separate from the system clipboard. Reopen menus after changing settings; use Refresh Finder only for troubleshooting.

### Validation and known issues

12,288 menu combinations, settings compatibility, and real filesystem move tests passed. Build 28 was tested in live Finder for toolbar actions, file creation, Cut, same-folder and cross-folder moves. Build 29 adds privacy metadata/log cleanup and has been rebuilt and automatically checked; a full installed UI regression has not been repeated.

One local cross-folder move took about five minutes. A subsequent test after restarting the installed app completed immediately; the cause remains unconfirmed. There is no move progress indicator yet. Check both folders before retrying delayed operations. Testing does not cover every supported macOS version, Intel, light appearance or VoiceOver.

### Downloads and verification

- `AstraCreate-2.16.pkg`: installer.
- `AstraCreate-Finder-2.16-source.zip`: source, build/test scripts and MIT license.
- `AstraCreate-2.16-SHA256SUMS.txt`: checksum manifest.

Place all three files in one directory and run `shasum -a 256 -c AstraCreate-2.16-SHA256SUMS.txt`. Build: `./scripts/build.sh`; tests: `./scripts/test.sh`; package: `./scripts/package.sh dist`.

For bug reports, include OS version, chip and reproduction steps. Redact usernames, private filenames and paths from screenshots. See `PRIVACY.md` in the source for local data handling.
