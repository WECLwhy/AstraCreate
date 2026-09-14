# Changelog / 更新记录

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
