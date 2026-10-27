# Installation, upgrade and removal

[Guide home](../README.md) · [中文](../zh/installation.md)

## Install and verify the source

Download the PKG, source ZIP and SHA256SUMS only from [official project releases](https://github.com/WECLwhy/AstraCreate/releases/latest). Put the three files together, open Terminal in that directory and run:

```zsh
shasum -a 256 -c AstraCreate-3.00-SHA256SUMS.txt
```

Use the matching manifest name for later versions. Stop if verification fails. Packages are ad-hoc signed, without Developer ID signing or Apple notarization. A checksum is not publisher identity authentication. Read [Apple's guidance](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac) and decide whether to authorize installation yourself; do not disable Gatekeeper or run unknown repair commands.

Open the PKG and finish system authorization. It installs `/Applications/AstraCreate.app` and attempts to restart the current user's Finder. Finish ongoing Finder work first. Enter passwords only in the macOS system dialog.

## Enable the extension

- macOS 15 and newer: System Settings → General → Login Items & Extensions → Extensions → Finder.
- macOS 13/14: System Settings → Privacy & Security → Extensions → Finder Extensions.

Enable New Common Files. Headings can vary by OS; Diagnostics & Support → Open Extension Settings provides a shortcut. Enabled status alone does not prove live menu loading: verify a regular folder.

## Upgrade

The new package replaces the app and retains preferences. Newly introduced developer formats default to off. Updates download only after consent and still require completion in macOS Installer. When upgrading from before 2.16, select pending cuts again.

## Remove

Disable the extension in System Settings and quit the app, then use Finder to move `/Applications/AstraCreate.app` to Trash. Removing the app does not remove created documents or automatically clear preferences, logs or the pending-move queue. Retain those for reinstalling/troubleshooting if useful. Before any additional cleanup, review [privacy information](../../PRIVACY.md), identify the files and make your own backup; do not delete the entire container blindly.
