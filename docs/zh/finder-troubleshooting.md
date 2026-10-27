# Finder 菜单排障

[文档首页](../README.md) · [English](../en/finder-troubleshooting.md)

按顺序检查，每完成一步就在普通本地文件夹空白处重试；搜索结果、侧栏、最近使用、受保护目录和第三方云盘可能表现不同。

1. 确认 App 在“应用程序”中，检查 App 显示的版本，避免同时运行多个旧拷贝。
2. 打开常用设置，确认目标格式已开启。JSON/JS/TS/Vue/HTML/CSS/YAML 默认关闭；“新建文件使用子菜单”开启时，它们位于二级菜单。
3. 在“诊断与支持”查看扩展状态，并按[安装指南](installation.md)启用 Finder 扩展。
4. 如果扩展列表没有“新建常用文件”，使用“修复菜单显示…”。修复会重新注册当前 App 并请求启用，可能重启 Finder；先完成现有文件操作，再按界面提示确认。
5. 返回 App 让状态刷新，再重新打开菜单。工具栏图标没出现时，在 Finder 工具栏右键 → 自定工具栏中添加 AstraCreate。
6. 仍有问题时导出诊断 JSON，提供软件版本、macOS 完整版本、芯片、步骤及脱敏截图，使用 [Bug 模板](https://github.com/WECLwhy/AstraCreate/issues/new?template=bug_report.yml)。

## 可选只读检查

```zsh
sw_vers
/usr/bin/pluginkit -m -A -D -v -i com.astracreate.finder.extension
/usr/bin/codesign --verify --deep --strict /Applications/AstraCreate.app
```

分享前检查输出，遮盖用户名和个人路径。PlugInKit 的 `+`/`-`/`=` 分别表示启用选择、忽略和被替代，不能单独证明菜单已显示。codesign 成功通常没有文字输出，需同时记录退出状态。

macOS 15.0.1 的反馈场景仍待目标机复测；[兼容性表](../compatibility.md)区分自动化与实际安装证据。
