import AppKit
import Foundation

private let finderSyncLaunchArgument = "--finder-sync-command"
private let appSupportFolderName = "AstraCreate"
private let extensionContainerIdentifier = "com.astracreate.finder.extension"

private enum AppLanguage: String {
    case zh
    case en
}

private struct MenuFeature {
    let key: String
    let zhTitle: String
    let enTitle: String
    let zhDetail: String
    let enDetail: String

    func title(for language: AppLanguage) -> String {
        language == .en ? enTitle : zhTitle
    }

    func detail(for language: AppLanguage) -> String {
        language == .en ? enDetail : zhDetail
    }
}

private let menuFeatures: [MenuFeature] = [
    MenuFeature(key: "docx", zhTitle: "新建 Word 文档", enTitle: "New Word Document", zhDetail: ".docx", enDetail: ".docx"),
    MenuFeature(key: "xlsx", zhTitle: "新建 Excel 表格", enTitle: "New Excel Workbook", zhDetail: ".xlsx", enDetail: ".xlsx"),
    MenuFeature(key: "pptx", zhTitle: "新建 PowerPoint 演示文稿", enTitle: "New PowerPoint Presentation", zhDetail: ".pptx", enDetail: ".pptx"),
    MenuFeature(key: "txt", zhTitle: "新建文本文件", enTitle: "New Text File", zhDetail: ".txt", enDetail: ".txt"),
    MenuFeature(key: "md", zhTitle: "新建 Markdown 文件", enTitle: "New Markdown File", zhDetail: ".md", enDetail: ".md"),
    MenuFeature(key: "terminal", zhTitle: "在此处打开终端", enTitle: "Open Terminal Here", zhDetail: "Terminal", enDetail: "Terminal"),
    MenuFeature(key: "vscode", zhTitle: "在 VS Code 打开当前文件夹", enTitle: "Open Current Folder in VS Code", zhDetail: "Visual Studio Code", enDetail: "Visual Studio Code"),
    MenuFeature(key: "cut", zhTitle: "剪切", enTitle: "Cut", zhDetail: "粘贴时才移动", enDetail: "Move only when pasted"),
    MenuFeature(key: "paste", zhTitle: "粘贴", enTitle: "Paste", zhDetail: "粘贴到当前文件夹", enDetail: "Paste into current folder"),
    MenuFeature(key: "copyPath", zhTitle: "复制绝对路径", enTitle: "Copy Absolute Path", zhDetail: "复制文件或文件夹路径", enDetail: "Copy file or folder paths")
]

private struct AppSettings {
    var enabled: [String: Bool]
    var language: AppLanguage
    var groupNewFiles = true
}

private func extensionSupportDirectory() -> URL {
    URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Containers/\(extensionContainerIdentifier)/Data/Library/Application Support/\(appSupportFolderName)", isDirectory: true)
}

private func settingsURL() -> URL {
    extensionSupportDirectory().appendingPathComponent("settings.json")
}

private func defaultEnabledFeatures() -> [String: Bool] {
    Dictionary(uniqueKeysWithValues: menuFeatures.map { ($0.key, true) })
}

private func loadSettings(from url: URL = settingsURL()) -> AppSettings {
    var enabled = defaultEnabledFeatures()
    var language = AppLanguage.zh
    guard let data = try? Data(contentsOf: url),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return AppSettings(enabled: enabled, language: language)
    }

    let saved = object["enabled"] as? [String: Any] ?? [:]
    for feature in menuFeatures {
        if let value = saved[feature.key] as? Bool {
            enabled[feature.key] = value
        }
    }

    if let raw = object["language"] as? String,
       let savedLanguage = AppLanguage(rawValue: raw) {
        language = savedLanguage
    }
    return AppSettings(enabled: enabled, language: language, groupNewFiles: object["groupNewFiles"] as? Bool ?? true)
}

private func loadEnabledFeatures() -> [String: Bool] {
    loadSettings().enabled
}

private func loadAppLanguage() -> AppLanguage {
    loadSettings().language
}

private func saveSettings(_ settings: AppSettings, to url: URL = settingsURL()) throws {
    let payload: [String: Any] = ["enabled": settings.enabled, "language": settings.language.rawValue, "groupNewFiles": settings.groupNewFiles]
    let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
}

final class SettingsWindowController: NSWindowController {
    private var checkboxes: [String: NSButton] = [:]
    private var detailLabels: [String: NSTextField] = [:]
    private var currentLanguage: AppLanguage = .zh
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let languageLabel = NSTextField(labelWithString: "")
    private let languageControl = NSSegmentedControl(labels: ["中文", "English"], trackingMode: .selectOne, target: nil, action: nil)
    private let groupNewFilesCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let enableAllButton = NSButton(title: "", target: nil, action: nil)
    private let disableAllButton = NSButton(title: "", target: nil, action: nil)
    private let restartFinderButton = NSButton(title: "", target: nil, action: nil)
    private var sectionLabels: [NSTextField] = []
    private let toolbarHintLabel = NSTextField(wrappingLabelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 690),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AstraCreate"
        window.center()
        super.init(window: window)
        buildUI()
        loadState()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            root.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20)
        ])

        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        root.addArrangedSubview(titleLabel)

        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.font = NSFont.systemFont(ofSize: 13)
        root.addArrangedSubview(subtitleLabel)

        let languageRow = NSStackView()
        languageRow.orientation = .horizontal
        languageRow.alignment = .centerY
        languageRow.spacing = 10
        languageLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        languageControl.target = self
        languageControl.action = #selector(languageChanged(_:))
        languageControl.setWidth(74, forSegment: 0)
        languageControl.setWidth(92, forSegment: 1)
        languageRow.addArrangedSubview(languageLabel)
        languageRow.addArrangedSubview(languageControl)
        root.addArrangedSubview(languageRow)

        groupNewFilesCheckbox.target = self
        groupNewFilesCheckbox.action = #selector(toggleChanged(_:))
        root.addArrangedSubview(groupNewFilesCheckbox)

        for features in [Array(menuFeatures[0..<5]), Array(menuFeatures[5..<7]), Array(menuFeatures[7..<10])] {
            let box = NSBox()
            box.boxType = .custom
            box.borderColor = .separatorColor
            box.fillColor = .controlBackgroundColor
            box.cornerRadius = 10
            box.contentViewMargins = NSSize(width: 14, height: 10)
            root.addArrangedSubview(box)
            box.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
            let list = NSStackView()
            list.orientation = .vertical
            list.alignment = .leading
            list.spacing = 4
            list.translatesAutoresizingMaskIntoConstraints = false
            box.contentView!.addSubview(list)
            NSLayoutConstraint.activate([
                list.leadingAnchor.constraint(equalTo: box.contentView!.leadingAnchor),
                list.trailingAnchor.constraint(equalTo: box.contentView!.trailingAnchor),
                list.topAnchor.constraint(equalTo: box.contentView!.topAnchor),
                list.bottomAnchor.constraint(equalTo: box.contentView!.bottomAnchor)
            ])
            let heading = NSTextField(labelWithString: "")
            heading.font = .systemFont(ofSize: 12, weight: .semibold)
            heading.textColor = .secondaryLabelColor
            sectionLabels.append(heading)
            list.addArrangedSubview(heading)
            for feature in features {
                let row = NSView()
                let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleChanged(_:)))
                checkbox.identifier = NSUserInterfaceItemIdentifier(feature.key)
                checkbox.font = .systemFont(ofSize: 13)
                checkboxes[feature.key] = checkbox
                let detail = NSTextField(labelWithString: "")
                detail.font = .systemFont(ofSize: 12)
                detail.textColor = .secondaryLabelColor
                detail.alignment = .right
                detailLabels[feature.key] = detail
                for view in [checkbox, detail] { view.translatesAutoresizingMaskIntoConstraints = false; row.addSubview(view) }
                list.addArrangedSubview(row)
                NSLayoutConstraint.activate([
                    row.widthAnchor.constraint(equalTo: list.widthAnchor),
                    row.heightAnchor.constraint(equalToConstant: 25),
                    checkbox.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                    checkbox.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                    detail.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                    detail.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                    checkbox.trailingAnchor.constraint(lessThanOrEqualTo: detail.leadingAnchor, constant: -12)
                ])
            }
        }
        toolbarHintLabel.font = .systemFont(ofSize: 12)
        toolbarHintLabel.textColor = .secondaryLabelColor
        root.addArrangedSubview(toolbarHintLabel)
        toolbarHintLabel.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 8

        enableAllButton.target = self
        enableAllButton.action = #selector(enableAllFeatures)
        disableAllButton.target = self
        disableAllButton.action = #selector(disableAllFeatures)
        restartFinderButton.target = self
        restartFinderButton.action = #selector(applyAndRestartFinder)
        restartFinderButton.bezelStyle = .rounded

        buttons.addArrangedSubview(enableAllButton)
        buttons.addArrangedSubview(disableAllButton)
        buttons.addArrangedSubview(restartFinderButton)
        root.addArrangedSubview(buttons)

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        root.addArrangedSubview(statusLabel)
    }

    private func loadState() {
        let settings = loadSettings()
        currentLanguage = settings.language
        groupNewFilesCheckbox.state = settings.groupNewFiles ? .on : .off
        languageControl.selectedSegment = currentLanguage == .en ? 1 : 0
        let enabled = settings.enabled
        for (key, checkbox) in checkboxes {
            checkbox.state = (enabled[key] ?? true) ? .on : .off
        }
        applyLanguage(status: localized("自动保存，下次打开菜单时生效。", "Saved automatically; changes apply when the menu reopens."))
    }

    private func currentState() -> [String: Bool] {
        Dictionary(uniqueKeysWithValues: menuFeatures.map { feature in
            (feature.key, checkboxes[feature.key]?.state == .on)
        })
    }

    private func currentSettings() -> AppSettings {
        AppSettings(enabled: currentState(), language: currentLanguage, groupNewFiles: groupNewFilesCheckbox.state == .on)
    }

    private func localized(_ zh: String, _ en: String) -> String {
        currentLanguage == .en ? en : zh
    }

    private func applyLanguage(status: String? = nil) {
        titleLabel.stringValue = localized("AstraCreate · 文件操作", "AstraCreate · File Actions")
        subtitleLabel.stringValue = localized("右键菜单与工具栏，共用一套常用操作。", "Your everyday actions, in the context menu and toolbar.")
        let headings = [localized("新建文件", "CREATE FILES"), localized("打开工具", "OPEN TOOLS"), localized("文件操作", "FILE ACTIONS")]
        for (label, title) in zip(sectionLabels, headings) { label.stringValue = title }
        toolbarHintLabel.stringValue = localized("Finder 右上角点击 AstraCreate 图标展开操作；若未显示，在工具栏右键 → 自定工具栏中添加。", "Click AstraCreate in the Finder toolbar. If missing, right-click the toolbar → Customize Toolbar to add it.")
        groupNewFilesCheckbox.title = localized("将新建文件折叠到二级菜单", "Group new files in a submenu")
        languageLabel.stringValue = localized("语言", "Language")
        enableAllButton.title = localized("全部开启", "Enable All")
        disableAllButton.title = localized("全部关闭", "Disable All")
        restartFinderButton.title = localized("修复菜单显示…", "Refresh Finder…")

        for feature in menuFeatures {
            checkboxes[feature.key]?.title = feature.title(for: currentLanguage)
            detailLabels[feature.key]?.stringValue = feature.detail(for: currentLanguage)
        }
        statusLabel.stringValue = status ?? localized("自动保存，下次打开菜单时生效。", "Saved automatically; changes apply when the menu reopens.")
    }

    private func saveState(status: String = "已保存。") {
        do {
            try saveSettings(currentSettings())
            statusLabel.stringValue = status
        } catch {
            statusLabel.stringValue = localized("保存失败：\(error.localizedDescription)", "Save failed: \(error.localizedDescription)")
        }
    }

    @objc private func toggleChanged(_ sender: NSButton) {
        saveState(status: localized("已保存。", "Saved."))
    }

    @objc private func languageChanged(_ sender: NSSegmentedControl) {
        currentLanguage = sender.selectedSegment == 1 ? .en : .zh
        applyLanguage(status: localized("已切换为中文。", "Switched to English."))
        saveState(status: localized("语言已保存，下次打开菜单时生效。", "Language saved. Reopen the menu to apply."))
    }

    @objc private func enableAllFeatures() {
        for checkbox in checkboxes.values {
            checkbox.state = .on
        }
        saveState(status: localized("已全部开启。", "All features enabled."))
    }

    @objc private func disableAllFeatures() {
        for checkbox in checkboxes.values {
            checkbox.state = .off
        }
        saveState(status: localized("已全部关闭。", "All features disabled."))
    }

    @objc private func applyAndRestartFinder() {
        let alert = NSAlert()
        alert.messageText = localized("重新启动 Finder？", "Restart Finder?")
        alert.informativeText = localized("普通设置无需重启。仅在菜单或工具栏图标未更新时使用，Finder 窗口会短暂关闭。", "Settings do not need a restart. Use this only if menus or the toolbar have not updated; Finder windows will briefly close.")
        alert.addButton(withTitle: localized("重启 Finder", "Restart Finder"))
        alert.addButton(withTitle: localized("取消", "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        saveState(status: localized("已保存，正在重启 Finder...", "Saved. Restarting Finder..."))
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Finder"]
        do {
            try process.run()
            statusLabel.stringValue = localized("已保存并重启 Finder。", "Saved and restarted Finder.")
        } catch {
            statusLabel.stringValue = localized("已保存，但重启 Finder 失败。", "Saved, but Finder restart failed.")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindowController: SettingsWindowController?
    private var pendingSettingsWindow: DispatchWorkItem?
    private var handledLaunchAction = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        let args = CommandLine.arguments
        log("launch args \(args.dropFirst().joined(separator: " "))")
        if args.count >= 3 && args[1] != finderSyncLaunchArgument {
            NSApp.setActivationPolicy(.accessory)
            log("launch mode direct command")
            run(command: args[1], path: args[2], selectedPaths: [])
            NSApp.terminate(nil)
        } else if handleFinderSyncLaunchArguments(args) {
            NSApp.setActivationPolicy(.accessory)
            log("launch mode finder sync command")
            NSApp.terminate(nil)
        } else {
            log("launch mode waiting for url or settings")
            scheduleSettingsWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettingsWindow()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleCommandURL(url)
        }
    }

    private func showSettingsWindow() {
        handledLaunchAction = true
        pendingSettingsWindow?.cancel()
        pendingSettingsWindow = nil
        NSApp.setActivationPolicy(.regular)
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        guard let controller = settingsWindowController else { return }
        controller.showWindow(nil)
        controller.window?.isReleasedWhenClosed = false
        controller.window?.center()
        controller.window?.makeKeyAndOrderFront(nil)
        controller.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        log("settings window requested")
    }

    private func scheduleSettingsWindow() {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.handledLaunchAction else { return }
            self.log("launch mode settings window")
            self.showSettingsWindow()
        }
        pendingSettingsWindow = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    private func handleFinderSyncLaunchArguments(_ args: [String]) -> Bool {
        guard args.count >= 4, args[1] == finderSyncLaunchArgument else {
            return false
        }

        let command = args[2]
        let path = args[3]
        let selectedPaths = parseSelectedPaths(args.dropFirst(4).first)
        run(command: command, path: path, selectedPaths: selectedPaths)
        return true
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let raw = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: raw) else {
            return
        }

        handleCommandURL(url)
    }

    private func handleCommandURL(_ url: URL) {
        handledLaunchAction = true
        pendingSettingsWindow?.cancel()
        pendingSettingsWindow = nil
        log("url received \(url.absoluteString)")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }
        if components.host == "settings" {
            showSettingsWindow()
            return
        }
        let items = components.queryItems ?? []
        guard components.host == "run",
              let command = items.first(where: { $0.name == "command" })?.value,
              let path = items.first(where: { $0.name == "path" })?.value else {
            return
        }

        let selectedRaw = items.first(where: { $0.name == "selected" })?.value
        let selectedPaths = parseSelectedPaths(selectedRaw)
        log("launch mode url command")
        run(command: command, path: path, selectedPaths: selectedPaths)
        if settingsWindowController?.window?.isVisible != true { NSApp.terminate(nil) }
    }

    private func parseSelectedPaths(_ raw: String?) -> [String] {
        guard let raw,
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            return []
        }
        return object.compactMap { $0 as? String }
    }

    private func run(command: String, path: String, selectedPaths: [String]) {
        let directory = URL(fileURLWithPath: path)
        log("host command \(command) path \(directory.path)")
        switch command {
        case "docx": createOfficeFile(kind: .docx, in: directory)
        case "xlsx": createOfficeFile(kind: .xlsx, in: directory)
        case "pptx": createOfficeFile(kind: .pptx, in: directory)
        case "txt": createTextFile(in: directory)
        case "md": createMarkdownFile(in: directory)
        case "terminal": openTerminal(at: directory)
        case "vscode": openVSCode(at: directory)
        case "cut": cut(paths: selectedPaths)
        case "paste": paste(into: directory)
        default: break
        }
    }

    private func runPendingCommandFile() -> Bool {
        let url = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(extensionContainerIdentifier)/Data/Library/Application Support/\(appSupportFolderName)/command.json")
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let command = object["command"] as? String,
              let path = object["path"] as? String else {
            log("no pending command file")
            return false
        }

        let selectedPaths = object["selectedPaths"] as? [String] ?? []
        try? FileManager.default.removeItem(at: url)
        run(command: command, path: path, selectedPaths: selectedPaths)
        return true
    }

    private enum OfficeKind {
        case docx
        case xlsx
        case pptx

        var ext: String {
            switch self {
            case .docx: return "docx"
            case .xlsx: return "xlsx"
            case .pptx: return "pptx"
            }
        }

        func baseName(for language: AppLanguage) -> String {
            switch (self, language) {
            case (.docx, .en): return "New Word Document"
            case (.xlsx, .en): return "New Excel Workbook"
            case (.pptx, .en): return "New PowerPoint Presentation"
            case (.docx, .zh): return "新建 Word 文档"
            case (.xlsx, .zh): return "新建 Excel 表格"
            case (.pptx, .zh): return "新建 PowerPoint 演示文稿"
            }
        }
    }

    private func createTextFile(in directory: URL) {
        let output = uniqueFile(in: directory, base: loadAppLanguage() == .en ? "New Text File" : "新建文本文件", ext: "txt")
        FileManager.default.createFile(atPath: output.path, contents: Data(), attributes: nil)
        log("created txt \(output.path)")
        reveal(output)
    }

    private func createMarkdownFile(in directory: URL) {
        let output = uniqueFile(in: directory, base: loadAppLanguage() == .en ? "New Markdown File" : "新建 Markdown 文件", ext: "md")
        FileManager.default.createFile(atPath: output.path, contents: Data(), attributes: nil)
        log("created md \(output.path)")
        reveal(output)
    }

    private func createOfficeFile(kind: OfficeKind, in directory: URL) {
        let output = uniqueFile(in: directory, base: kind.baseName(for: loadAppLanguage()), ext: kind.ext)
        if kind == .pptx {
            createPowerPointFile(at: output)
            return
        }

        let temp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("newfile-\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
            switch kind {
            case .docx: try writeDocxTemplate(to: temp)
            case .xlsx: try writeXlsxTemplate(to: temp)
            case .pptx: try writePptxTemplate(to: temp)
            }
            let status = runProcess("/usr/bin/zip", arguments: ["-Xqr", output.path, "."], currentDirectory: temp)
            log("zip status \(status), output \(output.path)")
            reveal(output)
        } catch {
            log("failed \(kind.ext): \(error)")
        }
        try? FileManager.default.removeItem(at: temp)
    }

    private func createPowerPointFile(at output: URL) {
        guard let template = Bundle.main.url(forResource: "blank", withExtension: "pptx") else {
            log("missing bundled PowerPoint template")
            return
        }

        do {
            try FileManager.default.copyItem(at: template, to: output)
            log("created pptx \(output.path)")
            reveal(output)
        } catch {
            log("failed pptx copy: \(error)")
        }
    }

    private func openTerminal(at directory: URL) {
        let status = runProcess("/usr/bin/open", arguments: ["-a", "Terminal", directory.path])
        log("terminal status \(status)")
    }

    private func openVSCode(at directory: URL) {
        let bundleStatus = runProcess("/usr/bin/open", arguments: ["-b", "com.microsoft.VSCode", directory.path])
        if bundleStatus != 0 {
            let appStatus = runProcess("/usr/bin/open", arguments: ["-a", "Visual Studio Code", directory.path])
            log("vscode app status \(appStatus)")
        } else {
            log("vscode bundle status \(bundleStatus)")
        }
    }

    private var moveClipboard: FileMoveClipboard {
        FileMoveClipboard(url: extensionSupportDirectory().appendingPathComponent("clipboard.json"))
    }

    private func cut(paths: [String]) {
        let existing = paths.filter { FileManager.default.fileExists(atPath: $0) }
        guard !existing.isEmpty else { return }
        do { try moveClipboard.store(existing) }
        catch { showMoveError(error.localizedDescription) }
    }

    private func paste(into directory: URL) {
        do {
            let result = try moveClipboard.paste(into: directory)
            log("paste: \(result.moved.count) moved, \(result.unchanged.count) unchanged, \(result.failures.count) failed")
            if !result.failures.isEmpty {
                showMoveError(loadAppLanguage() == .en
                    ? "Some items could not be moved and remain pending: \(result.failures.joined(separator: ", "))"
                    : "以下项目未能移动，已保留以便重试：\(result.failures.joined(separator: "、"))")
            }
            if let first = result.moved.first { reveal(first) }
        } catch { showMoveError(error.localizedDescription) }
    }

    private func showMoveError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = loadAppLanguage() == .en ? "Unable to move items" : "未能完成移动"
        alert.informativeText = message
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func uniqueFile(in directory: URL, base: String, ext: String) -> URL {
        var index = 1
        while true {
            let suffix = index == 1 ? "" : " \(index)"
            let candidate = directory.appendingPathComponent("\(base)\(suffix).\(ext)")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    private func reveal(_ url: URL) {
        _ = runProcess("/usr/bin/open", arguments: ["-R", url.path])
    }

    @discardableResult
    private func runProcess(_ launchPath: String, arguments: [String], currentDirectory: URL? = nil) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            log("process failed \(launchPath): \(error)")
            return -1
        }
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.data(using: .utf8)!.write(to: url)
    }

    private func writeDocxTemplate(to root: URL) throws {
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/></Types>
        """, to: root.appendingPathComponent("[Content_Types].xml"))
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>
        """, to: root.appendingPathComponent("_rels/.rels"))
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/><w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/></w:sectPr></w:body></w:document>
        """, to: root.appendingPathComponent("word/document.xml"))
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
        """, to: root.appendingPathComponent("word/_rels/document.xml.rels"))
        try writeCommonProps(to: root)
    }

    private func writeXlsxTemplate(to root: URL) throws {
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/></Types>
        """, to: root.appendingPathComponent("[Content_Types].xml"))
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>
        """, to: root.appendingPathComponent("_rels/.rels"))
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>
        """, to: root.appendingPathComponent("xl/workbook.xml"))
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>
        """, to: root.appendingPathComponent("xl/_rels/workbook.xml.rels"))
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData/></worksheet>
        """, to: root.appendingPathComponent("xl/worksheets/sheet1.xml"))
        try writeCommonProps(to: root)
    }

    private func writePptxTemplate(to root: URL) throws {
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/><Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/></Types>
        """, to: root.appendingPathComponent("[Content_Types].xml"))
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>
        """, to: root.appendingPathComponent("_rels/.rels"))
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><p:sldSz cx="9144000" cy="5143500" type="screen16x9"/><p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst></p:presentation>
        """, to: root.appendingPathComponent("ppt/presentation.xml"))
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/></Relationships>
        """, to: root.appendingPathComponent("ppt/_rels/presentation.xml.rels"))
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>
        """, to: root.appendingPathComponent("ppt/slides/slide1.xml"))
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
        """, to: root.appendingPathComponent("ppt/slides/_rels/slide1.xml.rels"))
        try writeCommonProps(to: root)
    }

    private func writeCommonProps(to root: URL) throws {
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:title></dc:title><dc:creator></dc:creator><cp:lastModifiedBy></cp:lastModifiedBy><dcterms:created xsi:type="dcterms:W3CDTF">2026-06-04T00:00:00Z</dcterms:created><dcterms:modified xsi:type="dcterms:W3CDTF">2026-06-04T00:00:00Z</dcterms:modified></cp:coreProperties>
        """, to: root.appendingPathComponent("docProps/core.xml"))
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"><Application>Finder New File</Application></Properties>
        """, to: root.appendingPathComponent("docProps/app.xml"))
    }

    private func log(_ message: String) {
        // Release builds intentionally do not persist file paths or command URLs.
    }
}

@main
struct AstraCreateApplication {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
