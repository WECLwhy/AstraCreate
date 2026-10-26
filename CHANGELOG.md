# Changelog / 更新记录

## 3.00 — 2026-10-26

Build 31 / 构建31。

- 实现 issue #1 的 JSON、JS、TS、Vue、HTML、CSS、YAML（排除 PDF）。开发文件逐项配置，新增格式默认关闭，保留原有功能开关；主程序与旧 helper 共用 UTF-8 模板及独占写入的自动重名逻辑。
- Add the seven configurable developer formats from issue #1, excluding PDF. Keep new formats off by default and preserve existing feature preferences; share UTF-8 templates and collision-safe exclusive creation between host and helper.
- 增加 1,536 组开发格式菜单组合、复制菜单项路由、实际命令生成、并发/重名/符号链接保护及失败处理检查。完整构建和回归通过；本机macOS27.0.1已验证PKG安装和真实Finder工具栏操作，macOS15.0.1仍待验收。

- 新增“外观”：跟随系统/浅色/深色，独立保存两套玻璃透明度、强调色及底色；系统色板和 HEX 输入即时生效。
- 新增 GitHub 正式版检查、项目页入口；用户确认下载并安装后才获取安装包，经来源、大小、PKG 格式及 SHA-256 校验，交由 macOS 安装器完成授权与覆盖安装。支持取消和失败提示，不降级、不自动后台更新。
- Add persistent light/dark palettes, glass transparency and system/light/dark modes, with native color wells and HEX entry.
- Add explicit GitHub release checks and project navigation. Require download/install consent, validate source/size/PKG/SHA-256, support cancellation, then hand off to macOS Installer. No downgrade or background updating.
- 打包版本从 AppInfo.plist 读取，并检查主程序与扩展版本一致，避免后续发布出现包名与版本不符。
- Derive package names from app metadata and require app/extension version consistency for future releases.

- 采用纸页与新建星光图标、原生磨砂玻璃侧栏及半透明设置面板。常用设置和诊断支持分开，语言控件固定在侧栏；保留独立剪切、粘贴开关及现有修复/导出行为。
- Refresh the icon and native AppKit settings with frosted materials, separate support navigation and persistent language controls. Preserve all independent toggles and existing repair/export behavior.
- 增加主程序、Finder 扩展及旧 helper 的结构化错误日志，每组件上限 256 KiB；设置窗口支持导出单个 JSON 诊断文件，重新筛选字段，不含路径、文件内容、剪切队列或历史原始日志，不自动上传。
- Add bounded structured error logs and a user-controlled JSON export with versions, extension state and recent events. Filter fields again at export; exclude paths, file contents, pending moves and legacy raw logs. No automatic upload.
- 修复“修复菜单显示”仅重启 Finder 的问题：按当前 App 路径重新注册扩展、请求启用，并检查命令退出状态。显示系统启用状态并提供原生扩展管理入口；返回 App 时刷新状态。
- 安装脚本通过登录用户的 GUI 会话和身份注册扩展，避免写入 root 的用户级配置；无用户或安装到其他卷时推迟注册，失败记录日志。仅重启该用户的 Finder。
- 更新 macOS 15 的设置路径。增加隔离的注册/安装回归检查；系统操作使用替身，不能代替 macOS 15.0.1 的原生 Finder 验收。
- Re-register the current app's extension during repair, check subprocess results, show activation status and provide native extension management.
- Run installer registration in the console user's session and identity; log failures and defer for headless or other-volume installs. Scope Finder restarts to that user.
- Add isolated regression checks and macOS 15 settings guidance. Local macOS27.0.1 installation and Finder toolbar checks passed; macOS15.0.1 acceptance remains pending. Earlier 2.17 artifacts are unchanged.

## 2.17 — 2026-09-18

Build 30 / 构建 30。

- 修复新建 Word 文档因未声明兼容性设置而进入兼容模式的问题；主程序和旧 helper 均显式设置 compatibilityMode=15。
- 增加生成后 DOCX 检查，覆盖设置内容类型、文档关联及匿名作者字段。已有文件不会自动修改。

- Fix newly created Word documents opening in compatibility mode by declaring compatibilityMode=15 in both generators. Existing documents are unchanged.
- Add generated-package regression checks for settings, relationships, content types and empty author metadata.

## 2.16 — 2026-09-14

Build 29: disable diagnostic log writes, remove personal Office/image metadata, and add bilingual release and privacy documentation.

- 构建 29：关闭诊断日志写入、移除模板个人作者及图片元数据、补齐双语发布与隐私说明。
- 已知问题：本机曾出现一次跨目录移动长延迟，复测正常但原因未确认；详见 RELEASE_NOTES.md。

- 新增原生 Finder 工具栏菜单及设置入口，保留可配置的新建子菜单。
- 设置按功能分组、统一说明对齐，更新即时生效文案。
- 剪切在扩展内记录，避免唤起主程序；其余文件命令后台打开主程序。
- 菜单保存当次目录和选中项，避免焦点变化导致误操作；无目标或选中项时禁用相应操作。
- 待移动队列改存扩展容器，粘贴显示数量；旧版本未完成的剪贴需重新选择。
- 同目录粘贴不改名；重名自动编号；失败项目保留重试并提示。
- Finder 重启改为需要确认的修复入口。
- 新增工具栏、剪切不唤起主程序、选中项快照、无目录以及移动异常测试。

## 2.15 — 2026-09-14

- 新建文件默认收进“新建文件”二级菜单，可在设置中切回平铺。
- 移除菜单分隔项，避免空白条；全部关闭时隐藏扩展菜单。
- 保留旧版功能开关和语言偏好，升级默认启用二级菜单。
- 新增 8,192 组菜单回归检查，验证菜单层级、开关、命令顺序及中英文标题。
- 打包不再清空输出目录；源码包不包含 Git 元数据和构建缓存。

English:
- Group new-file actions in a configurable submenu, enabled by default.
- Remove extension separators and hide the menu when all actions are disabled.
- Preserve existing feature and language settings on upgrade.
- Add menu regression coverage across 8,192 configurations.
- Preserve previous packages and exclude Git metadata/build caches from source archives.

Validation scope: local Apple Silicon build, menu construction regression tests and signature verification. Live Finder integration after installation still requires manual verification on the target macOS version.
