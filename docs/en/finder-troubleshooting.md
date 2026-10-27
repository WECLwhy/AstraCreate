# Finder menu troubleshooting

[Guide home](../README.md) · [中文](../zh/finder-troubleshooting.md)

Work through these steps and retest the background of a regular local folder after each one. Search results, Recents, sidebar items, protected directories and third-party cloud storage can behave differently.

1. Confirm the app is in Applications and check its displayed version. Avoid running several old copies.
2. Confirm the relevant feature is enabled in General. JSON/JS/TS/Vue/HTML/CSS/YAML default to off; with grouping enabled they appear under New File.
3. Check Diagnostics & Support, then enable the Finder extension as described in [installation](installation.md).
4. If New Common Files is absent, use Repair Finder Menus. This registers the current app and requests activation, and may restart Finder. Finish file operations first and follow the confirmation prompt.
5. Return to the app to refresh status, then reopen the menu. If the toolbar item is missing, right-click the Finder toolbar → Customize Toolbar and add AstraCreate.
6. If unresolved, export diagnostic JSON and provide app version, full macOS version, chip, steps and redacted screenshots using the [Bug form](https://github.com/WECLwhy/AstraCreate/issues/new?template=bug_report.yml).

## Optional read-only checks

```zsh
sw_vers
/usr/bin/pluginkit -m -A -D -v -i com.astracreate.finder.extension
/usr/bin/codesign --verify --deep --strict /Applications/AstraCreate.app
```

Review before sharing; redact personal paths/usernames. PlugInKit `+`/`-`/`=` indicate elected/ignored/superseded, not proof of live menu display. Successful codesign verification is usually silent; include its exit status.

The reported macOS 15.0.1 scenario still needs target-machine retesting. The [compatibility table](../compatibility.md) separates automated and installed GUI evidence.
