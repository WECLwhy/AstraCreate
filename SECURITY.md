# 安全政策 / Security policy

## 报告漏洞 / Report a vulnerability

请使用 GitHub 的[私密漏洞举报](https://github.com/WECLwhy/AstraCreate/security/advisories/new)。不要把凭据、个人文件、可直接利用的细节或未经脱敏的日志放在公开 Issue、PR 或 Wiki。

Use [GitHub private vulnerability reporting](https://github.com/WECLwhy/AstraCreate/security/advisories/new). Do not publish credentials, personal files, actionable exploit details or unredacted logs in issues, PRs or Wiki pages.

提供受影响版本、系统/架构、影响范围、最小复现步骤和必要的脱敏证据。请不要上传真实用户数据或执行破坏性验证。普通 Bug 使用 [问题模板](https://github.com/WECLwhy/AstraCreate/issues/new/choose)。维护者按实际精力处理，不承诺响应或修复时限。

Include affected version, OS/architecture, impact, minimal steps and necessary redacted evidence. Do not submit real user data or perform destructive validation. Use [issue forms](https://github.com/WECLwhy/AstraCreate/issues/new/choose) for ordinary bugs. Responses/fixes are best-effort, without a guaranteed deadline.

## 版本范围 / Version scope

| 版本 / Version | 策略 / Policy |
|---|---|
| 3.00 / 最新正式版 / latest stable | 优先排查 / Primary investigation target |
| 2.x 与更早 / and older | 请先在最新正式版复现；不承诺回补 / Retest latest stable; no promised backports |

## 已知边界 / Security boundaries

当前发行包仅 ad-hoc 签名，无 Developer ID 或 Apple 公证。SHA-256 检查不能替代身份认证。应用更新保留系统隔离/来源标记和安装授权；不要关闭 Gatekeeper。诊断只导出固定字段，不自动上传，但分享前仍应自行检查。

Current packages are ad-hoc signed, without Developer ID/notarization. SHA-256 is not publisher identity authentication. Updating retains quarantine/origin metadata and system authorization; do not disable Gatekeeper. Diagnostic export uses fixed fields and no automatic upload; review before sharing. See [privacy](PRIVACY.md).
