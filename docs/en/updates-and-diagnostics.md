# Updates, diagnostics and FAQ

[Guide home](../README.md) · [中文](../zh/updates-and-diagnostics.md)

## Updating

Diagnostics & Support → Check for Updates manually fetches GitHub stable-release metadata. There is no periodic background check. A newer version shows its version, size and notes. Only Download & Install starts package/necessary checksum transfers; Later and Cancel Download are available.

Source, size, PKG header and SHA-256 must pass. Missing verification data stops automatic updating and offers the release page. Verified packages open in macOS Installer, where the user must authorize and finish installation, then reopen the app. **Opening Installer is not installation success.** No automatic downgrade or security bypass.

## Diagnostics

Reproduce the problem and export one JSON file to a location you choose. It contains app/system versions, extension status and bounded structured events, excluding user paths, contents and pending moves. Nothing is uploaded automatically. Missing/unreadable components are marked, not treated as successful execution.

Review reports/screenshots before sharing. Do not attach legacy raw logs, entire containers or `clipboard.json`. See [privacy](../../PRIVACY.md).

## FAQ

- **Missing JSON or another new format?** Enable it under Developer Files, then check the New File submenu.
- **Little transparency change?** Reduce Transparency, display mode, the edited palette and backdrop affect rendering.
- **.ts appears as media?** Finder descriptions/default apps depend on local associations. The file remains .ts and UTF-8; this utility does not take over associations.
- **Read-only WeChat downloads?** The app does not change third-party file permissions. Check source, editing rights and permissions; do not broadly loosen permissions.
- **Other OS versions or Intel?** See [compatibility](../compatibility.md).
- **Security concern?** Use [private vulnerability reporting](https://github.com/WECLwhy/AstraCreate/security/advisories/new), not a public issue containing credentials or exploit details.
