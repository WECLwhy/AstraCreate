# AstraCreate for macOS / 星域文件新建

[中文](#中文) · [English](#english) · [GitHub](https://github.com/WECLwhy/AstraCreate)

## 下载 / Download

- [AstraCreate 3.00 PKG](https://github.com/WECLwhy/AstraCreate/releases/download/v3.00/AstraCreate-3.00.pkg)
- [Source ZIP / 源码](https://github.com/WECLwhy/AstraCreate/releases/download/v3.00/AstraCreate-Finder-3.00-source.zip)
- [SHA-256](https://github.com/WECLwhy/AstraCreate/releases/download/v3.00/AstraCreate-3.00-SHA256SUMS.txt)
- macOS 13+ · Apple Silicon (arm64) · Version 3.00 / build 31 · 2026-10-26

## 中文

AstraCreate 是轻量的 macOS Finder 菜单工具。在文件夹空白处或选中文件后右键，即可新建文件、打开终端或 VS Code，以及剪切、粘贴和复制路径。

### 3.00 更新

- 全新纸页星光图标、原生磨砂侧栏和设置面板；增大侧栏图标与文字间距。
- 外观支持跟随系统、浅色和深色；两套方案分别保存玻璃透明度、侧栏强调色和底色，支持系统色板及 HEX 输入。系统“减少透明度”设置优先。
- 实现 [issue #1](https://github.com/WECLwhy/AstraCreate/issues/1)：增加 JSON、JavaScript、TypeScript、Vue、HTML、CSS、YAML。新增格式默认关闭，可逐项开启，不含 PDF。
- 修复 Finder 扩展注册和启用流程；设置显示启用状态，提供扩展设置入口及“修复菜单显示…”。安装脚本在当前登录用户的会话中注册并请求启用。
- 新增有大小限制的结构化本地错误日志；手动导出一个 JSON 诊断文件，不含路径、文件内容或剪切队列，不自动上传。
- 手动检查 GitHub 最新正式版；用户同意下载并安装后才获取安装包，通过来源、大小、PKG 标识和 SHA-256 校验后打开 macOS 安装器。可取消下载，保留系统安装授权及安全检查；提供项目页入口。

### 功能与设置

原有五种格式：Word `.docx`、Excel `.xlsx`、PowerPoint `.pptx`、文本 `.txt`、Markdown `.md`。

可选开发格式：JSON `.json`、JavaScript `.js`、TypeScript `.ts`、Vue `.vue`、HTML `.html`、CSS `.css`、YAML `.yaml`。在“常用设置 → 开发文件”中逐项开启。JSON 使用有效空对象，HTML/Vue 提供最小模板，其余为空白 UTF-8 文件。重名自动编号，不覆盖已有文件。

文件操作包括打开终端、在 VS Code 打开当前文件夹、剪切、粘贴及复制绝对路径。保留所有独立开关、中英文切换和新建子菜单/平铺设置；修改自动保存，下次打开菜单生效。

### 安装与升级

下载并打开 `AstraCreate-3.00.pkg`，按 macOS 安装器提示授权并完成安装，随后重新打开 App。安装到 `/Applications/AstraCreate.app`，覆盖旧版并保留设置；安装器会尝试重启当前用户的 Finder，请先完成 Finder 中正在进行的操作。

安装包沿用本地 ad-hoc 签名，**没有 Developer ID 签名或 Apple 公证**。macOS 可能阻止或要求手动确认；应用不会绕过这些检查。仅支持 Apple Silicon，未提供 Intel 构建。

如果菜单未出现，先打开 AstraCreate 的“诊断与支持”查看扩展状态：

- macOS 15 及更新系统：系统设置 → 通用 → 登录项与扩展 → 扩展 → Finder。
- macOS 13/14：系统设置 → 隐私与安全性 → 扩展 → Finder 扩展。

启用“新建常用文件”。若列表中没有该扩展，使用“修复菜单显示…”重新注册并请求启用。系统显示已启用不等于菜单已经加载，请在普通本地文件夹实际检查。详见[发布说明](RELEASE_NOTES.md)。

从 2.16 之前的版本升级时，未粘贴的剪切项目需重新选择。剪切队列独立于系统剪贴板；只有粘贴时才移动文件。失败项保留以便重试。

### 检查更新与反馈

“诊断与支持 → 检查更新…”只获取 GitHub 正式发布元数据。发现更高版本后显示版本、大小与说明；点击“下载并安装…”才开始下载，校验通过后交给系统安装器。打开安装器不代表安装成功，需要按系统提示完成安装。缺少或不匹配的校验信息会停止自动更新，并提供发布页入口。

复现问题后，点击“导出诊断日志…”保存 JSON，再自行发给开发者，并提供 macOS 版本、芯片、步骤与脱敏截图。不要直接提交历史原始日志、完整容器或剪切队列。数据处理见[隐私说明](PRIVACY.md)。

### 构建、测试与打包

需要 Xcode Command Line Tools 和 Python 3：

```zsh
./scripts/build.sh
./scripts/test.sh
./scripts/package.sh dist
```

构建产物为 `build/AstraCreate.app`。打包生成 `AstraCreate-3.00.pkg`、`AstraCreate-Finder-3.00-source.zip` 及 `AstraCreate-3.00-SHA256SUMS.txt`；版本从 plist 读取，主程序与扩展版本必须一致。

```zsh
shasum -a 256 -c AstraCreate-3.00-SHA256SUMS.txt
```

自动化覆盖原有 12,288 组菜单和新增 1,536 组开发格式组合、设置、文件移动、DOCX、诊断、外观、更新与实际文件生成。替身系统操作和自动化结果不能代替目标系统的 Finder、Office 或完整辅助功能验收。具体本机安装验证范围见[发布说明](RELEASE_NOTES.md)。

MIT 许可证。项目结构：`src/` 源码、`Resources/` 与 `assets/` 资源、`scripts/` 构建打包、`packaging/scripts/postinstall` 安装后处理、`tests/` 回归检查。

## English

AstraCreate is a lightweight Finder menu utility. Right-click a folder background or selected items to create files, open Terminal or VS Code, cut/paste items and copy paths.

### New in 3.00

- New document/sparkle icon and native frosted settings; improved icon/title spacing in the sidebar.
- System, light and dark appearance, with separate glass transparency, sidebar accent and tint for light/dark palettes. Native color wells and HEX entry; respects Reduce Transparency.
- [Issue #1](https://github.com/WECLwhy/AstraCreate/issues/1): JSON, JavaScript, TypeScript, Vue, HTML, CSS and YAML. New formats are individually configurable and off by default; PDF is excluded.
- Repair Finder registration and activation requests, display activation state and provide system extension management. Installer registration uses the logged-in user's session.
- Bounded structured local error logs and manual JSON export, excluding paths, file contents and pending moves. No automatic upload.
- Manual GitHub stable-release checks. Installer downloads require user consent, can be cancelled, and must pass source/size/PKG/SHA-256 checks before macOS Installer opens. System authorization and security checks remain in place; project navigation is included.

### Features and settings

Original formats: Word `.docx`, Excel `.xlsx`, PowerPoint `.pptx`, text `.txt` and Markdown `.md`.

Optional developer formats: JSON `.json`, JavaScript `.js`, TypeScript `.ts`, Vue `.vue`, HTML `.html`, CSS `.css`, YAML `.yaml`. Enable each in General → Developer Files. JSON starts as an empty object, HTML/Vue have minimal templates, and other formats are blank UTF-8 files. Collisions use numbered names without overwriting existing items.

Open Terminal or VS Code, cut, paste and copy absolute paths. Every feature has its own switch. Chinese/English and submenu/flat menu settings are retained. Changes save automatically and apply when the menu reopens.

### Install and upgrade

Open `AstraCreate-3.00.pkg`, authorize and complete the macOS Installer steps, then reopen the app. Installation replaces `/Applications/AstraCreate.app` and retains settings. It attempts to restart the current user's Finder; finish ongoing Finder work first.

The package uses local ad-hoc signing and **has no Developer ID signature or Apple notarization**. macOS may block it or require manual confirmation; the app does not bypass those protections. Requires macOS 13+ and Apple Silicon (arm64); no Intel build is provided.

If the menu is missing, use Diagnostics & Support to inspect activation:

- macOS 15 and newer: System Settings → General → Login Items & Extensions → Extensions → Finder.
- macOS 13/14: System Settings → Privacy & Security → Extensions → Finder Extensions.

Enable New Common Files. If absent, use Repair Finder Menus to register it again and request activation. Enabled status alone does not prove live menu loading; check a regular local folder. See [release notes](RELEASE_NOTES.md).

When upgrading from before 2.16, select pending cuts again. The pending-move queue is separate from the system clipboard. Items move only on paste; failures remain for retry.

### Updates and feedback

Check for Updates fetches only GitHub stable-release metadata. A newer version shows its version, size and notes; Download & Install starts the transfer after consent. Verified packages open in macOS Installer. Opening Installer is not installation success: finish its authorization and installation steps. Missing or mismatched verification data stops automatic updates and offers a release-page link.

After reproducing a problem, export diagnostic logs, then send the JSON file with your OS, chip, steps and redacted screenshots. Do not submit legacy raw logs, entire containers or pending-move queues. See [privacy information](PRIVACY.md).

### Build, test and package

Requires Xcode Command Line Tools and Python 3:

```zsh
./scripts/build.sh
./scripts/test.sh
./scripts/package.sh dist
shasum -a 256 -c dist/AstraCreate-3.00-SHA256SUMS.txt
```

App output: `build/AstraCreate.app`. Release outputs: installer, source ZIP and SHA-256 manifest. Package names derive from plist metadata; host/extension versions must match.

Tests cover the original 12,288 menus plus 1,536 developer-format combinations, settings, moves, DOCX, diagnostics, appearance, updating and real file generation. Stubbed system actions and automated tests do not replace installed Finder/Office or full accessibility acceptance. The local installation test scope is recorded in [release notes](RELEASE_NOTES.md).

MIT license. `src/`: code; `Resources/`, `assets/`: media; `scripts/`: build/package; `packaging/scripts/postinstall`: installer registration; `tests/`: regression checks.
