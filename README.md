# AstraCreate for macOS / 星域文件新建

<p align="center">
  <a href="#中文"><strong>中文</strong></a>
  |
  <a href="#english"><strong>English</strong></a>
</p>

## 下载 / Download

- 安装包 / Package: [AstraCreate-2.17.pkg](https://github.com/WECLwhy/AstraCreate/releases/download/v2.17/AstraCreate-2.17.pkg)
- 系统版本 / System version: macOS 13 or later, Apple Silicon Mac
- 文档更新时间 / Document updated: 2026-09-18

## 中文

**AstraCreate for macOS（星域文件新建）** 是一个 macOS Finder 右键菜单工具。安装后，可以在 Finder 文件夹空白处或选中文件后右键，直接新建常见文件、打开终端或 VS Code，并进行剪贴、粘贴和复制绝对路径等操作。

本项目由持有者为了在多系统之间保持同一种文件操作习惯而编写。欢迎在使用过程中指出 Bug，并请尽量附上 macOS 系统版本、设备类型、复现步骤和相关截图，方便定位问题。

### 下载

- 安装包：[AstraCreate-2.17.pkg](https://github.com/WECLwhy/AstraCreate/releases/download/v2.17/AstraCreate-2.17.pkg)
- 适用系统：macOS 13 或更高版本，Apple Silicon Mac
- 文档更新时间：2026-09-18

发布详情与已知问题见 [发布说明](RELEASE_NOTES.md)，本地数据处理见 [隐私说明](PRIVACY.md)。

### 2.17 更新

- 新建 Word 文档显式声明现代兼容性模式（compatibilityMode=15），补齐设置文件及关联；已有文档不变。
- 增加主程序和旧 helper 的 DOCX 生成回归检查，验证包结构、兼容性和匿名作者字段。
- 保留 Finder 工具栏、可配置新建子菜单、分组设置及剪切队列等功能。
- 微信下载文件的只读权限不由本次更新修改；请参阅发布说明中的排查范围。

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
- 设置界面支持开启或关闭每个右键菜单功能
- 设置界面支持中文 / English 切换，右键菜单和新文件默认名称会跟随语言

### 系统要求

- macOS 13 或更高版本
- Apple Silicon Mac
- Xcode Command Line Tools，用于从源码构建
- 可选：Visual Studio Code，用于“在 VS Code 打开当前文件夹”

### 安装

下载并打开 [AstraCreate-2.17.pkg](https://github.com/WECLwhy/AstraCreate/releases/download/v2.17/AstraCreate-2.17.pkg)。安装脚本会：

- 把 `AstraCreate.app` 安装到 `/Applications`
- 注册 Finder Sync 扩展
- 启用扩展
- 重启 Finder

当前安装包为本地 ad-hoc 构建，未使用 Apple Developer ID 签名。首次安装时 macOS 可能会显示安全确认。

如果右键菜单没有出现，请打开：

`系统设置 -> 隐私与安全性 -> 扩展 -> Finder 扩展`

确认“新建常用文件”或 AstraCreate 对应扩展已启用。

### 使用

在 Finder 中打开任意文件夹，在空白处右键即可看到菜单项。移动文件时，先选中项目并点击“剪切（粘贴时移动）”，再到目标文件夹点击“将 N 项移到此处”。此队列独立于系统剪贴板。

双击 `/Applications/AstraCreate.app` 可以打开设置界面。勾选或取消对应功能、切换中文 / English 后，下次打开菜单即可生效。仅在菜单或工具栏未更新时使用“修复菜单显示…”。

首次在“桌面”“文稿”等受 macOS 隐私保护的位置操作时，系统可能会询问文件访问权限，请选择允许。

### 从源码构建

```zsh
chmod +x scripts/build.sh scripts/package.sh packaging/scripts/postinstall
./scripts/build.sh
```

构建后的 app 位于：

```text
build/AstraCreate.app
```

### 测试

```zsh
./scripts/test.sh
```

需要 Python 3 和 Xcode Command Line Tools。覆盖 12,288 组菜单组合、设置兼容性、真实文件移动，以及主程序和旧 helper 生成的 DOCX 包。

### 打包

```zsh
./scripts/package.sh dist
```

输出：

```text
dist/AstraCreate-2.17.pkg
dist/AstraCreate-Finder-2.17-source.zip
dist/AstraCreate-2.17-SHA256SUMS.txt
```

### 项目结构

```text
src/Main.swift                 设置界面主程序
src/FileMoveClipboard.swift    待移动队列与安全粘贴逻辑
src/Helper.swift               旧版命令行 helper（保留兼容）
src/FinderSyncObjC.m           Finder Sync 扩展，负责右键菜单和命令转发
Resources/SoftwareLogo.png     原始图标基准图
Resources/AppIcon.icns         标准 macOS 多尺寸 app 图标
Resources/blank.pptx           PowerPoint 空白模板
scripts/build.sh               构建 app 和扩展
scripts/package.sh             生成安装包和源码压缩包
packaging/scripts/postinstall  安装后注册并启用 Finder 扩展
```

### 卸载

```zsh
pluginkit -e ignore -i com.astracreate.finder.extension
rm -rf /Applications/AstraCreate.app
killall Finder
```

## English

**AstraCreate for macOS** is a Finder context menu utility for macOS. After installation, you can right-click a blank area in Finder or selected items to create common files, open Terminal or VS Code, cut and paste files, and copy absolute paths.

This project was created by the owner to keep the same file-operation habits across multiple operating systems. Bug reports are welcome. When reporting an issue, please include your macOS version, device type, reproduction steps, and screenshots when possible.

### Download

- Package: [AstraCreate-2.17.pkg](https://github.com/WECLwhy/AstraCreate/releases/download/v2.17/AstraCreate-2.17.pkg)
- System version: macOS 13 or later, Apple Silicon Mac
- Document updated: 2026-09-18

See [release notes and known issues](RELEASE_NOTES.md) and [privacy information](PRIVACY.md).

### What’s New in 2.17

- Declare modern Word compatibility mode (compatibilityMode=15), with settings and relationships, in newly created documents. Existing documents are unchanged.
- Add DOCX generation regression checks for both generators, including package structure and anonymous author metadata.
- Retain the Finder toolbar, configurable new-file submenu, grouped settings and pending-move queue.
- This update does not change read-only permissions on WeChat downloads; see release notes for the investigation scope.

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
- Settings window for enabling or disabling each context menu feature
- Chinese / English language switch for the settings window, context menu, and default new-file names

### Requirements

- macOS 13 or later
- Apple Silicon Mac
- Xcode Command Line Tools for building from source
- Optional: Visual Studio Code for the VS Code menu item

### Install

Download and open [AstraCreate-2.17.pkg](https://github.com/WECLwhy/AstraCreate/releases/download/v2.17/AstraCreate-2.17.pkg). The installer will:

- Install `AstraCreate.app` into `/Applications`
- Register the Finder Sync extension
- Enable the extension
- Restart Finder

This package is locally built with ad-hoc signing and is not signed with an Apple Developer ID. macOS may show a security confirmation on first install.

If the menu does not appear, open:

`System Settings -> Privacy & Security -> Extensions -> Finder Extensions`

Then make sure the AstraCreate Finder extension is enabled.

### Usage

Open any folder in Finder and right-click on a blank area to see the menu items. For cut/paste, select files and choose “Cut (Move on Paste)”, then choose “Move N Item(s) Here” in the destination folder. This pending-move queue is independent of the system clipboard.

Open `/Applications/AstraCreate.app` to show the settings window. Toggle the desired features or switch between Chinese and English, then reopen the menu to apply. Use “Refresh Finder…” only if menus or the toolbar do not update.

When operating in privacy-protected locations such as Desktop or Documents for the first time, macOS may ask for file access permission. Allow it if prompted.

### Build From Source

```zsh
chmod +x scripts/build.sh scripts/package.sh packaging/scripts/postinstall
./scripts/build.sh
```

The built app will be available at:

```text
build/AstraCreate.app
```

### Tests

Requires Python 3 and Xcode Command Line Tools. Includes generated DOCX validation for both writers.

```zsh
./scripts/test.sh
```

Checks 12,288 menu combinations, legacy/invalid settings and unsupported menu contexts.

### Package

```zsh
./scripts/package.sh dist
```

Outputs:

```text
dist/AstraCreate-2.17.pkg
dist/AstraCreate-Finder-2.17-source.zip
dist/AstraCreate-2.17-SHA256SUMS.txt
```

### Project Structure

```text
src/Main.swift                 Settings UI host app
src/FileMoveClipboard.swift    Pending move queue and paste handling
src/Helper.swift               Legacy command-line helper
src/FinderSyncObjC.m           Finder Sync extension: context menu and command forwarding
Resources/SoftwareLogo.png     Original icon reference image
Resources/AppIcon.icns         Standard multi-size macOS app icon
Resources/blank.pptx           Blank PowerPoint template
scripts/build.sh               Builds the app and extension
scripts/package.sh             Creates installer and source archive
packaging/scripts/postinstall  Registers and enables the Finder extension after install
```

### Uninstall

```zsh
pluginkit -e ignore -i com.astracreate.finder.extension
rm -rf /Applications/AstraCreate.app
killall Finder
```
