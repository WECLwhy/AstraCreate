# 兼容性与验证范围 / Compatibility and evidence

[文档首页 / Guide home](README.md)

记录日期 / Recorded: 2026-10-27。3.00 / build 31，Apple Silicon arm64，最低部署目标 macOS 13。

| 环境 / Environment | 产品范围 / Scope | 原生安装与 Finder / Installed Finder evidence |
|---|---|---|
| macOS 13 · Apple Silicon | 声明支持 / Declared support | 待验证 / Not verified |
| macOS 14 · Apple Silicon | 声明支持 / Declared support | 待验证 / Not verified |
| macOS 15 · Apple Silicon | 声明支持 / Declared support | 待验证；反馈者 M1 / 15.0.1 尚需复测 / Reporter retest pending |
| macOS 26 · Apple Silicon | 声明支持 / Declared support | 待验证 / Not verified |
| macOS 27.0.1 · Apple Silicon | 声明支持 / Declared support | 2026-10-26 本机通过覆盖安装、工具栏和右键菜单、七种开发格式及重名新建、日志导出、版本检查 / Local checks passed |
| Intel Mac | 无发行构建 / No release build | 不支持当前 arm64 包 / Current package not supported |
| macOS 12 及更早 / and older | 低于部署目标 / Below deployment target | 不支持 / Not supported |

## 自动化与人工验收 / Automated vs manual evidence

[CI](https://github.com/WECLwhy/AstraCreate/actions/workflows/ci.yml) 在 macOS 14/15 的 Apple Silicon runner 执行构建、回归、包校验及隐私检查。具体是否通过，以对应提交的绿色运行记录为准。CI 不安装到用户机器，不证明系统扩展启用、菜单实际显示或真实 Office 界面验收。

[CI](https://github.com/WECLwhy/AstraCreate/actions/workflows/ci.yml) builds/tests/audits on macOS 14/15 Apple Silicon runners. Only a successful run for the relevant commit is evidence of a pass. It does not establish user-machine extension activation, live Finder menus or Office UI acceptance.

未完成 / Still unverified: 全部系统安装矩阵、真实远程新版本下载后覆盖安装的整段流程、完整 Office UI、VoiceOver 与辅助功能矩阵。更新同意、取消、校验和安装器交接已有隔离测试；不能替代真实远程安装。

Full OS installation matrix, end-to-end real remote-newer-version installation, complete Office UI/VoiceOver/accessibility matrix remain unverified. Fixture consent/cancellation/integrity/handoff tests do not replace a real remote install.

安装包为 ad-hoc 签名，无 Developer ID 或 Apple 公证。一次历史跨目录移动延迟原因仍未确认；无移动进度条。微信文件只读权限不由本工具修改。

Packages are ad-hoc signed, without Developer ID/notarization. A historical cross-folder delay remains unexplained; there is no move progress bar. Third-party read-only file permissions are unchanged.
