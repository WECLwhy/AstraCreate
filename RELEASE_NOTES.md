# AstraCreate 3.00

## 中文

版本3.00 / 构建31 · 2026-10-26 · macOS13或更高版本 · Apple Silicon（arm64）

### 本次更新

- 新图标与原生磨砂玻璃设置界面，常用设置、外观、诊断支持分组；侧栏图标和文字间距改善。
- 跟随系统、浅色、深色三种模式；浅深方案独立保存透明度、强调色和玻璃底色，支持系统色板及HEX输入，尊重系统“减少透明度”。
- 实现 [issue #1](https://github.com/WECLwhy/AstraCreate/issues/1) 的JSON、JS、TS、Vue、HTML、CSS、YAML新建功能，不包含PDF。新增类型默认关闭，在“常用设置 → 开发文件”按需开启。原有五种格式和所有文件操作继续保留。
- JSON使用有效空对象，HTML/Vue提供最小模板，其余为空白UTF-8文件；重名自动编号并保护已有文件。
- 修复Finder扩展注册和启用请求，显示扩展状态，提供系统设置与修复入口；安装后在当前用户会话中注册，记录失败。
- 结构化本地错误日志及一键JSON导出，不含文件路径、内容或剪切队列，不自动上传。
- 手动检查GitHub正式版；用户确认下载并安装后才下载，可取消；校验来源、大小、PKG标识及SHA-256，再打开系统安装器。增加项目主页入口。
- 发布构建使用相对源码位置，清除二进制中的本机源码路径；资源不含Office作者字段，源码包排除Git元数据、凭据、缓存和本地状态。

### 安装与升级

打开 `AstraCreate-3.00.pkg`，按系统提示授权和完成覆盖安装，再重新打开AstraCreate。保留旧设置；新增格式默认关闭。安装器会尝试重启当前用户的Finder，请先结束正在进行的Finder操作。

本包沿用ad-hoc签名，没有Developer ID签名和Apple公证。macOS可能拦截或要求手动确认，应用不会绕过系统安全检查。未提供Intel构建。

菜单未显示时，在“诊断与支持”查看状态，并打开系统Finder扩展设置。macOS15及更新系统通常位于“通用 → 登录项与扩展 → 扩展 → Finder”；macOS13/14位于“隐私与安全性 → 扩展 → Finder扩展”。启用“新建常用文件”；若列表中没有它，再使用“修复菜单显示…”。

### 验证范围与已知限制

本版完成本机macOS27.0.1的PKG覆盖安装、安装后签名/版本检查、真实Finder工具栏菜单及七种开发格式的新建操作。完整自动化覆盖12,288组原有菜单与1,536组开发格式组合、设置迁移、文件移动、DOCX、诊断、外观和更新流程。更新的同意、下载取消及安装器交接使用隔离测试包/替身验证；没有宣称已完成真实远程新版的整段升级验收。

未在反馈者macOS15.0.1或全部支持系统上验证；没有完整Office界面、VoiceOver及系统辅助功能矩阵验收。此前一次跨目录移动延迟的原因仍未确认，目前无移动进度显示。微信下载文件的只读权限不由本版修改；Word兼容性设置仅适用于新建文档。

检查更新仅获取正式版元数据；打开安装器不等于安装成功。复现问题后请导出诊断JSON并附步骤和脱敏截图，不要直接提交旧原始日志、剪切队列或完整容器。见[隐私说明](PRIVACY.md)。

### 下载与校验

- `AstraCreate-3.00.pkg`：安装包。
- `AstraCreate-Finder-3.00-source.zip`：源码、构建/测试脚本与MIT许可证。
- `AstraCreate-3.00-SHA256SUMS.txt`：校验清单。

```zsh
shasum -a 256 -c AstraCreate-3.00-SHA256SUMS.txt
```

源码构建：`./scripts/build.sh`；测试：`./scripts/test.sh`；打包：`./scripts/package.sh dist`。

---

## English

Version3.00 / build31 · 2026-10-26 · macOS13+ · Apple Silicon (arm64)

### Changes

- New icon and native frosted settings with General, Appearance and Diagnostics & Support pages; improved sidebar icon/title spacing.
- System/light/dark modes, independently saved light/dark transparency, accent and glass tint, native color wells and HEX entry. Respects Reduce Transparency.
- Implement the seven developer formats in [issue #1](https://github.com/WECLwhy/AstraCreate/issues/1): JSON, JS, TS, Vue, HTML, CSS and YAML, excluding PDF. Enable each under General → Developer Files; new formats are off by default. Retain the original five formats and all file actions.
- JSON starts as a valid empty object; HTML/Vue have minimal templates; other developer files are blank UTF-8. Number collisions without overwriting existing items.
- Repair Finder registration/activation requests, display activation status and link to system extension management. Installer registration runs in the current user's session and reports failures.
- Bounded structured local logs and manual JSON export, excluding paths, contents and pending moves. No automatic upload.
- Manual GitHub stable-release checks. Downloads require approval, can be cancelled, and pass source/size/PKG/SHA-256 checks before macOS Installer opens. Project-page navigation included.
- Relative source locations remove local source paths from release binaries. Resources omit Office author fields; source archives exclude Git metadata, credentials, caches and local state.

### Installation and upgrade

Open `AstraCreate-3.00.pkg`, authorize and finish the system Installer steps, then reopen AstraCreate. Existing settings remain; new formats default to off. Installation attempts to restart the current user's Finder, so finish ongoing Finder work first.

The package remains ad-hoc signed, without Developer ID signing or Apple notarization. macOS may block it or require manual confirmation; the app does not bypass security checks. No Intel build is provided.

If menus are absent, inspect Diagnostics & Support and open Finder extension settings. On macOS15 and newer, use General → Login Items & Extensions → Extensions → Finder; macOS13/14 use Privacy & Security → Extensions → Finder Extensions. Enable New Common Files; use Repair Finder Menus if it is missing from the list.

### Validation and limitations

Local testing on macOS27.0.1 covers PKG overwrite installation, installed version/signature checks, live Finder toolbar menus and creation of all seven developer formats. The full automated suite covers the original12,288 menus plus1,536 developer-format combinations, settings migration, moves, DOCX, diagnostics, appearance and updating. Consent, cancellation and Installer handoff use isolated fixture packages/spies; this is not a claim of full real remote-update installation acceptance.

The reporter's macOS15.0.1 and the full supported OS matrix remain unverified. Full Office UI, VoiceOver and accessibility-settings matrix acceptance is pending. A previously observed cross-folder move delay remains unexplained; there is no move progress indicator. This release does not change read-only WeChat download permissions. Word compatibility settings apply only to newly created files.

Opening Installer does not prove installation succeeded. For reports, export diagnostic JSON and include steps and redacted screenshots; do not share legacy raw logs, pending-move queues or whole containers. See [privacy information](PRIVACY.md).

### Downloads and verification

- `AstraCreate-3.00.pkg`: installer.
- `AstraCreate-Finder-3.00-source.zip`: source, build/test scripts and MIT license.
- `AstraCreate-3.00-SHA256SUMS.txt`: checksums.

```zsh
shasum -a 256 -c AstraCreate-3.00-SHA256SUMS.txt
```

Build: `./scripts/build.sh`; test: `./scripts/test.sh`; package: `./scripts/package.sh dist`.
