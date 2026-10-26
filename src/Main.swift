import AppKit
import Foundation
import FinderSync
import UniformTypeIdentifiers

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
    MenuFeature(key: "json", zhTitle: "新建 JSON 文件", enTitle: "New JSON File", zhDetail: ".json", enDetail: ".json"),
    MenuFeature(key: "js", zhTitle: "新建 JavaScript 文件", enTitle: "New JavaScript File", zhDetail: ".js", enDetail: ".js"),
    MenuFeature(key: "ts", zhTitle: "新建 TypeScript 文件", enTitle: "New TypeScript File", zhDetail: ".ts", enDetail: ".ts"),
    MenuFeature(key: "vue", zhTitle: "新建 Vue 文件", enTitle: "New Vue File", zhDetail: ".vue", enDetail: ".vue"),
    MenuFeature(key: "html", zhTitle: "新建 HTML 文件", enTitle: "New HTML File", zhDetail: ".html", enDetail: ".html"),
    MenuFeature(key: "css", zhTitle: "新建 CSS 文件", enTitle: "New CSS File", zhDetail: ".css", enDetail: ".css"),
    MenuFeature(key: "yaml", zhTitle: "新建 YAML 文件", enTitle: "New YAML File", zhDetail: ".yaml", enDetail: ".yaml"),
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
    var appearance = AppearancePreferences()
}

private func extensionSupportDirectory() -> URL {
    URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Containers/\(extensionContainerIdentifier)/Data/Library/Application Support/\(appSupportFolderName)", isDirectory: true)
}

private func settingsURL() -> URL {
    extensionSupportDirectory().appendingPathComponent("settings.json")
}

private func defaultEnabledFeatures() -> [String: Bool] {
    Dictionary(uniqueKeysWithValues: menuFeatures.map { ($0.key, SourceFileKind(rawValue: $0.key) == nil) })
}

private func loadSettings(from url: URL = settingsURL()) -> AppSettings {
    var enabled = defaultEnabledFeatures()
    var language = AppLanguage.zh
    guard let data = try? Data(contentsOf: url),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        if url == settingsURL(), FileManager.default.fileExists(atPath: url.path) { Diagnostics.local().record(.settingsReadFailed) }
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
    return AppSettings(enabled: enabled, language: language, groupNewFiles: object["groupNewFiles"] as? Bool ?? true, appearance: AppearancePreferences(object: object["appearance"]))
}

private func loadEnabledFeatures() -> [String: Bool] {
    loadSettings().enabled
}

private func loadAppLanguage() -> AppLanguage {
    loadSettings().language
}

private func saveSettings(_ settings: AppSettings, to url: URL = settingsURL()) throws {
    let payload: [String: Any] = ["enabled": settings.enabled, "language": settings.language.rawValue, "groupNewFiles": settings.groupNewFiles, "appearance": settings.appearance.object]
    let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
}

final class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
    private var checkboxes: [String: NSSwitch] = [:]
    private var featureLabels: [String: NSTextField] = [:]
    private var translatedLabels: [(NSTextField, String, String)] = []
    private let generalNavigation = SettingsNavigationButton(symbol: "gearshape.fill", tag: 0)
    private let appearanceNavigation = SettingsNavigationButton(symbol: "paintpalette", tag: 1)
    private let supportNavigation = SettingsNavigationButton(symbol: "doc.text.magnifyingglass", tag: 2)
    private var appearancePreferences = AppearancePreferences()
    private let appearanceModeControl = NSSegmentedControl(labels: ["跟随系统", "浅色", "深色"], trackingMode: .selectOne, target: nil, action: nil)
    private let paletteControl = NSSegmentedControl(labels: ["浅色方案", "深色方案"], trackingMode: .selectOne, target: nil, action: nil)
    private let transparencySlider = NSSlider(value: 40, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let transparencyValue = NSTextField(labelWithString: "40%")
    private let accentColorWell = NSColorWell()
    private let glassColorWell = NSColorWell()
    private let accentHexField = NSTextField(string: "")
    private let glassHexField = NSTextField(string: "")
    private let resetAppearanceButton = NSButton(title: "", target: nil, action: nil)
    private let checkUpdatesButton = NSButton(title: "", target: nil, action: nil)
    private let projectButton = NSButton(title: "", target: nil, action: nil)
    private var updateUI: UpdateUIController?
    private var pages: [NSScrollView] = []
    private var selectedPage = 0
    private var detailLabels: [String: NSTextField] = [:]
    private var currentLanguage: AppLanguage = .zh
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let languageLabel = NSTextField(labelWithString: "")
    private let languageControl = NSSegmentedControl(labels: ["中文", "English"], trackingMode: .selectOne, target: nil, action: nil)
    private let groupNewFilesCheckbox = NSSwitch()
    private let enableAllButton = NSButton(title: "", target: nil, action: nil)
    private let disableAllButton = NSButton(title: "", target: nil, action: nil)
    private let restartFinderButton = NSButton(title: "", target: nil, action: nil)
    private let extensionSettingsButton = NSButton(title: "", target: nil, action: nil)
    private let exportDiagnosticsButton = NSButton(title: "", target: nil, action: nil)
    private let extensionStatusLabel = NSTextField(wrappingLabelWithString: "")
    private var repairInProgress = false
    private let toolbarHintLabel = NSTextField(wrappingLabelWithString: "")
    private let statusLabel = NSTextField(wrappingLabelWithString: "")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 840),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "AstraCreate"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.minSize = NSSize(width: 900, height: 680)
        window.center()
        super.init(window: window)
        buildUI()
        loadState()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshExtensionStatus), name: NSApplication.didBecomeActiveNotification, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    required init?(coder: NSCoder) {
        nil
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }
        let background = NSVisualEffectView()
        background.material = .underWindowBackground
        background.blendingMode = .behindWindow
        background.state = .active
        pin(background, to: contentView)
        pin(FrostedBackdropView(), to: background)

        let sidebar = FrostedPanelView(material: .sidebar, cornerRadius: 0)
        sidebar.blendingMode = .withinWindow
        sidebar.state = .active
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(sidebar)
        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: background.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 248)
        ])
        let side = stack()
        pin(side, to: sidebar, insets: NSEdgeInsets(top: 64, left: 20, bottom: 24, right: 20))
        side.alignment = .centerX
        side.spacing = 14
        let icon = NSImageView()
        icon.image = Bundle.main.url(forResource: "AppIcon", withExtension: "icns").flatMap(NSImage.init(contentsOf:)) ?? NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityLabel("AstraCreate")
        side.addArrangedSubview(icon)
        icon.widthAnchor.constraint(equalToConstant: 160).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 160).isActive = true
        titleLabel.font = .systemFont(ofSize: 27, weight: .bold)
        side.addArrangedSubview(titleLabel)
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        side.addArrangedSubview(subtitleLabel)
        side.addArrangedSubview(spacer(height: 16))
        for button in [generalNavigation, appearanceNavigation, supportNavigation] {
            button.target = self
            button.action = #selector(selectPage(_:))
            side.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: side.widthAnchor).isActive = true
            button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        }
        let spring = NSView()
        spring.setContentHuggingPriority(.defaultLow, for: .vertical)
        side.addArrangedSubview(spring)
        languageLabel.font = .systemFont(ofSize: 11)
        languageLabel.textColor = .secondaryLabelColor
        side.addArrangedSubview(languageLabel)
        languageControl.target = self
        languageControl.action = #selector(languageChanged(_:))
        languageControl.setWidth(74, forSegment: 0)
        languageControl.setWidth(86, forSegment: 1)
        side.addArrangedSubview(languageControl)
        let version = NSTextField(labelWithString: "AstraCreate \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
        version.font = .systemFont(ofSize: 11)
        version.textColor = .tertiaryLabelColor
        side.addArrangedSubview(version)

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(divider)
        NSLayoutConstraint.activate([
            divider.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.topAnchor.constraint(equalTo: background.topAnchor),
            divider.bottomAnchor.constraint(equalTo: background.bottomAnchor)
        ])
        let main = NSView()
        main.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(main)
        NSLayoutConstraint.activate([
            main.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            main.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            main.topAnchor.constraint(equalTo: background.topAnchor, constant: 40),
            main.bottomAnchor.constraint(equalTo: background.bottomAnchor)
        ])
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 3
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        main.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: main.leadingAnchor, constant: 28),
            statusLabel.trailingAnchor.constraint(equalTo: main.trailingAnchor, constant: -28),
            statusLabel.bottomAnchor.constraint(equalTo: main.bottomAnchor, constant: -16),
            statusLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 16)
        ])
        let general = page(in: main)
        let appearance = page(in: main)
        let support = page(in: main)
        buildAppearancePage(appearance)

        let menu = card(in: general, title: "菜单显示", english: "Menu Appearance", detail: "在 Finder 菜单和工具栏中显示常用操作。", englishDetail: "Your everyday actions in Finder menus and the toolbar.")
        let groupingTitle = label("新建文件使用子菜单", "Group new files in a submenu", size: 13)
        groupNewFilesCheckbox.target = self
        groupNewFilesCheckbox.action = #selector(toggleChanged(_:))
        groupNewFilesCheckbox.setAccessibilityIdentifier("groupNewFiles")
        menu.addArrangedSubview(horizontal([groupingTitle, NSView(), groupNewFilesCheckbox]))

        let files = card(in: general, title: "新建文件", english: "Create Files", detail: "在菜单中显示以下新建选项。", englishDetail: "Choose which file types appear in your menu.")
        for feature in menuFeatures.prefix(5) { addFeature(feature, to: files) }
        let developerFiles = card(in: general, title: "开发文件", english: "Developer Files", detail: "默认关闭，按需开启以保持菜单简洁。", englishDetail: "Off by default. Enable only the formats you need.")
        for feature in menuFeatures where SourceFileKind(rawValue: feature.key) != nil { addFeature(feature, to: developerFiles) }
        let actions = card(in: general, title: "文件操作", english: "File Actions", detail: "只保留你需要的常用操作。", englishDetail: "Keep the actions you use, right where you need them.")
        for feature in menuFeatures.suffix(5) { addFeature(feature, to: actions) }
        enableAllButton.target = self
        enableAllButton.action = #selector(enableAllFeatures)
        disableAllButton.target = self
        disableAllButton.action = #selector(disableAllFeatures)
        for button in [enableAllButton, disableAllButton] { button.bezelStyle = .rounded; button.controlSize = .small }
        general.addArrangedSubview(horizontal([enableAllButton, disableAllButton]))

        let supportTitle = label("诊断与支持", "Diagnostics & Support", size: 25, weight: .bold)
        support.addArrangedSubview(supportTitle)
        let finder = card(in: support, title: "Finder 扩展", english: "Finder Extension", detail: "检查系统启用状态，必要时重新注册扩展。", englishDetail: "Check activation and repair registration when needed.")
        extensionStatusLabel.font = .systemFont(ofSize: 13)
        finder.addArrangedSubview(extensionStatusLabel)
        extensionStatusLabel.widthAnchor.constraint(equalTo: finder.widthAnchor).isActive = true
        extensionSettingsButton.target = self
        extensionSettingsButton.action = #selector(openExtensionSettings)
        restartFinderButton.target = self
        restartFinderButton.action = #selector(applyAndRestartFinder)
        for button in [extensionSettingsButton, restartFinderButton] { button.bezelStyle = .rounded }
        finder.addArrangedSubview(horizontal([extensionSettingsButton, restartFinderButton, NSView()]))
        let logs = card(in: support, title: "诊断日志", english: "Diagnostic Logs", detail: "复现问题后导出一个文件，方便提交给开发者。", englishDetail: "Reproduce the issue, then export one file to send to the developer.")
        let privacy = label("仅包含版本、扩展状态和近期错误；不含文件路径、内容或剪切队列，不会自动上传。", "Includes versions, extension status and recent errors. Excludes file paths, contents and pending moves. No automatic upload.", size: 12, secondary: true)
        logs.addArrangedSubview(privacy)
        privacy.widthAnchor.constraint(equalTo: logs.widthAnchor).isActive = true
        exportDiagnosticsButton.target = self
        exportDiagnosticsButton.action = #selector(exportDiagnostics)
        exportDiagnosticsButton.bezelStyle = .rounded
        exportDiagnosticsButton.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: nil)
        exportDiagnosticsButton.imagePosition = .imageLeading
        logs.addArrangedSubview(horizontal([exportDiagnosticsButton, NSView()]))
        let updates = card(in: support, title: "关于与更新", english: "About & Updates", detail: "从 GitHub 正式发布检查更新，经你确认后下载并打开系统安装器。", englishDetail: "Check GitHub releases. Download and open Installer only after your approval.")
        checkUpdatesButton.target = self
        checkUpdatesButton.action = #selector(checkForUpdates)
        checkUpdatesButton.bezelStyle = .rounded
        projectButton.target = self
        projectButton.action = #selector(openProject)
        projectButton.bezelStyle = .rounded
        updates.addArrangedSubview(horizontal([checkUpdatesButton, projectButton, NSView()]))
        let toolbar = card(in: support, title: "工具栏", english: "Finder Toolbar")
        toolbarHintLabel.font = .systemFont(ofSize: 12)
        toolbarHintLabel.textColor = .secondaryLabelColor
        toolbar.addArrangedSubview(toolbarHintLabel)
        toolbarHintLabel.widthAnchor.constraint(equalTo: toolbar.widthAnchor).isActive = true
        showPage(0)
    }

    private func stack() -> NSStackView {
        let view = NSStackView()
        view.orientation = .vertical
        view.alignment = .leading
        view.spacing = 12
        return view
    }

    private func pin(_ child: NSView, to parent: NSView, insets: NSEdgeInsets = .init()) {
        child.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(child)
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: insets.left),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -insets.right),
            child.topAnchor.constraint(equalTo: parent.topAnchor, constant: insets.top),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -insets.bottom)
        ])
    }

    private func spacer(height: CGFloat) -> NSView {
        let view = NSView()
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return view
    }

    private func label(_ zh: String, _ en: String, size: CGFloat, weight: NSFont.Weight = .regular, secondary: Bool = false) -> NSTextField {
        let view = NSTextField(wrappingLabelWithString: zh)
        view.font = .systemFont(ofSize: size, weight: weight)
        view.textColor = secondary ? .secondaryLabelColor : .labelColor
        translatedLabels.append((view, zh, en))
        return view
    }

    private func horizontal(_ views: [NSView]) -> NSStackView {
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        return row
    }

    private func page(in parent: NSView) -> NSStackView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: parent.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -12)
        ])
        let document = SettingsDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        let root = stack()
        root.spacing = 18
        pin(root, to: document, insets: NSEdgeInsets(top: 18, left: 28, bottom: 18, right: 28))
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        pages.append(scroll)
        return root
    }

    private func card(in root: NSStackView, title: String, english: String, detail: String? = nil, englishDetail: String? = nil) -> NSStackView {
        let panel = FrostedPanelView()
        root.addArrangedSubview(panel)
        panel.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        let body = stack()
        body.spacing = 4
        pin(body, to: panel, insets: NSEdgeInsets(top: 14, left: 20, bottom: 14, right: 20))
        body.addArrangedSubview(label(title, english, size: 16, weight: .semibold))
        if let detail, let englishDetail {
            let hint = label(detail, englishDetail, size: 12, secondary: true)
            body.addArrangedSubview(hint)
            hint.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        }
        return body
    }

    private func addFeature(_ feature: MenuFeature, to list: NSStackView) {
        let divider = NSBox()
        divider.boxType = .separator
        list.addArrangedSubview(divider)
        divider.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
        let symbols = ["docx": "doc.richtext", "xlsx": "tablecells", "pptx": "rectangle.on.rectangle", "txt": "doc.text", "md": "text.alignleft", "json": "curlybraces", "js": "chevron.left.forwardslash.chevron.right", "ts": "chevron.left.forwardslash.chevron.right", "vue": "chevron.left.forwardslash.chevron.right", "html": "chevron.left.forwardslash.chevron.right", "css": "paintbrush", "yaml": "list.bullet.indent", "terminal": "terminal", "vscode": "chevron.left.forwardslash.chevron.right", "cut": "scissors", "paste": "doc.on.clipboard", "copyPath": "link"]
        let image = NSImageView(image: NSImage(systemSymbolName: symbols[feature.key] ?? "doc", accessibilityDescription: nil)!)
        image.contentTintColor = ["docx": NSColor.systemBlue, "xlsx": .systemGreen, "pptx": .systemOrange][feature.key] ?? .secondaryLabelColor
        image.widthAnchor.constraint(equalToConstant: 24).isActive = true
        image.heightAnchor.constraint(equalToConstant: 24).isActive = true
        let title = NSTextField(labelWithString: "")
        title.font = .systemFont(ofSize: 13)
        featureLabels[feature.key] = title
        let detail = NSTextField(labelWithString: "")
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingTail
        detailLabels[feature.key] = detail
        let control = NSSwitch()
        control.target = self
        control.action = #selector(toggleChanged(_:))
        control.setAccessibilityIdentifier(feature.key)
        checkboxes[feature.key] = control
        let row = horizontal([image, title, NSView(), detail, control])
        list.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
        row.heightAnchor.constraint(equalToConstant: 30).isActive = true
        detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    @objc private func selectPage(_ sender: NSButton) { showPage(sender.tag) }

    private func showPage(_ index: Int) {
        guard pages.indices.contains(index) else { return }
        selectedPage = index
        for (pageIndex, page) in pages.enumerated() { page.isHidden = pageIndex != index }
        generalNavigation.selected = index == 0
        appearanceNavigation.selected = index == 1
        supportNavigation.selected = index == 2
        window?.contentView?.layoutSubtreeIfNeeded()
        pages[index].contentView.scroll(to: .zero)
        pages[index].reflectScrolledClipView(pages[index].contentView)
    }


    private func loadState() {
        let settings = loadSettings()
        currentLanguage = settings.language
        appearancePreferences = settings.appearance
        groupNewFilesCheckbox.state = settings.groupNewFiles ? .on : .off
        languageControl.selectedSegment = currentLanguage == .en ? 1 : 0
        let enabled = settings.enabled
        for (key, checkbox) in checkboxes {
            checkbox.state = (enabled[key] ?? true) ? .on : .off
        }
        applyAppearance()
        paletteControl.selectedSegment = window?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? 1 : 0
        synchronizeAppearanceControls()
        applyLanguage(status: localized("自动保存，下次打开菜单时生效。", "Saved automatically; changes apply when the menu reopens."))
    }

    private func buildAppearancePage(_ root: NSStackView) {
        root.addArrangedSubview(label("外观", "Appearance", size: 25, weight: .bold))
        let mode = card(in: root, title: "显示模式", english: "Appearance Mode", detail: "设置即时生效；跟随系统会自动响应浅色和深色切换。", englishDetail: "Changes apply immediately. Follow System switches between light and dark automatically.")
        appearanceModeControl.target = self
        appearanceModeControl.action = #selector(appearanceModeChanged)
        appearanceModeControl.setWidth(110, forSegment: 0)
        for index in 1...2 { appearanceModeControl.setWidth(74, forSegment: index) }
        appearanceModeControl.setAccessibilityIdentifier("appearanceMode")
        mode.addArrangedSubview(appearanceModeControl)
        let palette = card(in: root, title: "透明度与配色", english: "Transparency & Colors", detail: "浅色和深色分别保存。选择要编辑的方案，切换显示模式可预览。", englishDetail: "Light and dark palettes are saved separately. Switch the appearance mode to preview either palette.")
        paletteControl.selectedSegment = 0
        paletteControl.target = self
        paletteControl.action = #selector(paletteSelectionChanged)
        paletteControl.setAccessibilityIdentifier("paletteSelection")
        palette.addArrangedSubview(paletteControl)
        transparencySlider.isContinuous = true
        transparencySlider.target = self
        transparencySlider.action = #selector(paletteValueChanged)
        transparencySlider.setAccessibilityIdentifier("glassTransparency")
        transparencySlider.widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
        transparencyValue.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        transparencyValue.widthAnchor.constraint(equalToConstant: 42).isActive = true
        let opacityRow = horizontal([label("玻璃透明度", "Glass transparency", size: 13), NSView(), transparencySlider, transparencyValue])
        palette.addArrangedSubview(opacityRow)
        opacityRow.widthAnchor.constraint(equalTo: palette.widthAnchor).isActive = true
        for (well, field, zh, en, identifier) in [(accentColorWell, accentHexField, "侧栏强调色", "Navigation accent", "accentColor"), (glassColorWell, glassHexField, "玻璃底色", "Glass tint", "glassTint")] {
            well.target = self
            well.action = #selector(paletteValueChanged)
            well.colorWellStyle = .minimal
            if #available(macOS 14.0, *) { well.supportsAlpha = false }
            well.setAccessibilityIdentifier(identifier)
            well.widthAnchor.constraint(equalToConstant: 54).isActive = true
            well.heightAnchor.constraint(equalToConstant: 28).isActive = true
            field.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            field.placeholderString = "#RRGGBB"
            field.delegate = self
            field.setAccessibilityIdentifier(identifier + "Hex")
            field.widthAnchor.constraint(equalToConstant: 96).isActive = true
            let row = horizontal([label(zh, en, size: 13), NSView(), field, well])
            palette.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: palette.widthAnchor).isActive = true
        }
        resetAppearanceButton.target = self
        resetAppearanceButton.action = #selector(resetPalette)
        resetAppearanceButton.bezelStyle = .rounded
        palette.addArrangedSubview(resetAppearanceButton)
        let note = label("透明度只调整玻璃底色，文字保持清晰。系统的“减少透明度”设置优先；原生开关颜色由系统控制。", "Transparency affects glass surfaces, keeping text clear. Reduce Transparency takes precedence. Native switches retain the system accent.", size: 12, secondary: true)
        root.addArrangedSubview(note)
        note.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
    }

    private func synchronizeAppearanceControls() {
        appearanceModeControl.selectedSegment = AppearanceMode.allCases.firstIndex(of: appearancePreferences.mode) ?? 0
        let palette = paletteControl.selectedSegment == 1 ? appearancePreferences.dark : appearancePreferences.light
        transparencySlider.doubleValue = palette.transparency
        transparencyValue.stringValue = "\(Int(palette.transparency.rounded()))%"
        accentColorWell.color = .fromHex(palette.accentHex)
        glassColorWell.color = .fromHex(palette.tintHex)
        accentHexField.stringValue = palette.accentHex
        glassHexField.stringValue = palette.tintHex
    }

    private func applyAppearance() {
        NSApp.appearance = appearancePreferences.applicationAppearance
        window?.appearance = NSApp.appearance
        func apply(_ view: NSView) {
            (view as? FrostedPanelView)?.preferences = appearancePreferences
            (view as? FrostedBackdropView)?.preferences = appearancePreferences
            (view as? SettingsNavigationButton)?.preferences = appearancePreferences
            view.subviews.forEach(apply)
        }
        if let content = window?.contentView { apply(content) }
    }

    @objc private func appearanceModeChanged() {
        guard AppearanceMode.allCases.indices.contains(appearanceModeControl.selectedSegment) else { return }
        appearancePreferences.mode = AppearanceMode.allCases[appearanceModeControl.selectedSegment]
        applyAppearance()
        paletteControl.selectedSegment = window?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? 1 : 0
        synchronizeAppearanceControls()
        saveState(status: localized("外观已保存并生效。", "Appearance saved and applied."))
    }

    @objc private func paletteSelectionChanged() { synchronizeAppearanceControls() }

    @objc private func paletteValueChanged() {
        let palette = GlassPalette(transparency: transparencySlider.doubleValue,
            accentHex: accentColorWell.color.rgbHex ?? "#007AFF", tintHex: glassColorWell.color.rgbHex ?? "#C9DFFF")
        if paletteControl.selectedSegment == 1 { appearancePreferences.dark = palette }
        else { appearancePreferences.light = palette }
        transparencyValue.stringValue = "\(Int(palette.transparency.rounded()))%"
        accentHexField.stringValue = palette.accentHex
        glassHexField.stringValue = palette.tintHex
        applyAppearance()
        saveState(status: localized("配色与透明度已保存。", "Colors and transparency saved."))
    }

    @objc private func resetPalette() {
        if paletteControl.selectedSegment == 1 { appearancePreferences.dark = .dark }
        else { appearancePreferences.light = .light }
        synchronizeAppearanceControls()
        applyAppearance()
        saveState(status: localized("已重置当前外观方案。", "This palette has been reset."))
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField,
              field === accentHexField || field === glassHexField else { return }
        let normalized = GlassPalette.color(field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), fallback: "invalid")
        guard normalized != "invalid" else {
            statusLabel.stringValue = localized("颜色格式应为 #RRGGBB，例如 #007AFF。", "Use #RRGGBB, for example #007AFF.")
            return
        }
        if field === accentHexField { accentColorWell.color = .fromHex(normalized) }
        else { glassColorWell.color = .fromHex(normalized) }
        paletteValueChanged()
    }

    @objc private func checkForUpdates() {
        if updateUI == nil {
            updateUI = UpdateUIController(window: window, english: { [weak self] in self?.currentLanguage == .en },
                status: { [weak self] in self?.statusLabel.stringValue = $0 },
                busy: { [weak self] in self?.checkUpdatesButton.isEnabled = !$0 })
        }
        updateUI?.check()
    }

    @objc private func openProject() {
        if NSWorkspace.shared.open(GitHubUpdater.projectURL) {
            statusLabel.stringValue = localized("已打开 GitHub 项目主页。", "GitHub project page opened.")
        } else {
            Diagnostics.local().record(.projectPageFailed)
            statusLabel.stringValue = localized("无法打开浏览器，请稍后重试。", "Could not open the browser. Please try again.")
        }
    }

    private func currentState() -> [String: Bool] {
        Dictionary(uniqueKeysWithValues: menuFeatures.map { feature in
            (feature.key, checkboxes[feature.key]?.state == .on)
        })
    }

    private func currentSettings() -> AppSettings {
        AppSettings(enabled: currentState(), language: currentLanguage, groupNewFiles: groupNewFilesCheckbox.state == .on, appearance: appearancePreferences)
    }

    private func localized(_ zh: String, _ en: String) -> String {
        currentLanguage == .en ? en : zh
    }

    private func applyLanguage(status: String? = nil) {
        titleLabel.stringValue = "AstraCreate"
        subtitleLabel.stringValue = localized("文件新建，触手可及", "Create right where you are.")
        generalNavigation.title = localized("常用设置", "General")
        appearanceNavigation.title = localized("外观", "Appearance")
        supportNavigation.title = localized("诊断与支持", "Diagnostics & Support")
        for (index, text) in [localized("跟随系统", "Follow System"), localized("浅色", "Light"), localized("深色", "Dark")].enumerated() { appearanceModeControl.setLabel(text, forSegment: index) }
        paletteControl.setLabel(localized("浅色方案", "Light Palette"), forSegment: 0)
        paletteControl.setLabel(localized("深色方案", "Dark Palette"), forSegment: 1)
        resetAppearanceButton.title = localized("重置当前方案", "Reset This Palette")
        accentColorWell.setAccessibilityLabel(localized("侧栏强调色", "Navigation accent color"))
        glassColorWell.setAccessibilityLabel(localized("玻璃底色", "Glass tint color"))
        accentHexField.setAccessibilityLabel(localized("侧栏强调色 HEX", "Navigation accent HEX"))
        glassHexField.setAccessibilityLabel(localized("玻璃底色 HEX", "Glass tint HEX"))
        transparencySlider.setAccessibilityLabel(localized("玻璃透明度", "Glass transparency"))
        checkUpdatesButton.title = localized("检查更新…", "Check for Updates…")
        projectButton.title = localized("GitHub 项目主页", "GitHub Project")
        for (label, zh, en) in translatedLabels { label.stringValue = localized(zh, en) }
        toolbarHintLabel.stringValue = localized("Finder 右上角点击 AstraCreate 图标展开操作；若未显示，在工具栏右键 → 自定工具栏中添加。", "Click AstraCreate in the Finder toolbar. If missing, right-click the toolbar → Customize Toolbar to add it.")
        groupNewFilesCheckbox.setAccessibilityLabel(localized("新建文件使用子菜单", "Group new files in a submenu"))
        languageLabel.stringValue = localized("语言", "Language")
        enableAllButton.title = localized("全部开启", "Enable All")
        disableAllButton.title = localized("全部关闭", "Disable All")
        restartFinderButton.title = localized("修复菜单显示…", "Repair Finder Menus…")
        extensionSettingsButton.title = localized("打开扩展设置…", "Open Extension Settings…")
        exportDiagnosticsButton.title = localized("导出诊断日志…", "Export Diagnostic Logs…")
        refreshExtensionStatus()
        for feature in menuFeatures {
            let title = feature.title(for: currentLanguage)
            let prefix = currentLanguage == .zh ? "新建" : "New "
            let uiTitle = title.hasPrefix(prefix) ? String(title.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces) : title
            featureLabels[feature.key]?.stringValue = uiTitle
            checkboxes[feature.key]?.setAccessibilityLabel(title)
            detailLabels[feature.key]?.stringValue = feature.detail(for: currentLanguage)
        }
        statusLabel.stringValue = status ?? localized("自动保存，下次打开菜单时生效。", "Saved automatically; changes apply when the menu reopens.")
        showPage(selectedPage)
    }

    private func saveState(status: String = "已保存。") {
        do {
            try saveSettings(currentSettings())
            statusLabel.stringValue = status
        } catch {
            Diagnostics.local().record(.settingsSaveFailed, error: error)
            statusLabel.stringValue = localized("保存失败：\(error.localizedDescription)", "Save failed: \(error.localizedDescription)")
        }
    }

    @objc private func toggleChanged(_ sender: NSControl) {
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

    @objc private func refreshExtensionStatus() {
        extensionStatusLabel.stringValue = FIFinderSyncController.isExtensionEnabled
            ? localized("Finder 扩展已启用。若菜单仍未显示，请使用修复，并在普通本地文件夹中重试。", "Finder extension is enabled. If the menu is missing, repair and retry in a regular local folder.")
            : localized("Finder 扩展尚未启用或不可用。请打开扩展设置，启用“新建常用文件”；若列表中没有它，请先修复。", "Finder extension is disabled or unavailable. Open extension settings and enable New Common Files; if it is missing, repair first.")
    }

    @objc private func openExtensionSettings() {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    @objc private func exportDiagnostics() {
        guard let window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        panel.nameFieldStringValue = "AstraCreate-Diagnostics-\(formatter.string(from: Date())).json"
        panel.message = localized("保存后可将此文件发给开发者。包含软件/系统版本、扩展状态和近期错误记录；不含文件路径、文件内容或剪切队列，不会自动上传。", "Save this file and send it to the developer. Includes versions, extension status and recent errors. Excludes file paths, file contents and pending moves. No automatic upload.")
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let destination = panel.url else { return }
            self.exportDiagnosticsButton.isEnabled = false
            Diagnostics.local().record(.exportStarted)
            let enabled = FIFinderSyncController.isExtensionEnabled
            let hostDirectory = Diagnostics.local().directory
            let extensionDirectory = extensionSupportDirectory().appendingPathComponent("Diagnostics-v1")
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result {
                    let data = try Diagnostics.exportData(hostDirectory: hostDirectory,
                        extensionDirectory: extensionDirectory, extensionEnabled: enabled)
                    try data.write(to: destination, options: .atomic)
                }
                DispatchQueue.main.async {
                    self.exportDiagnosticsButton.isEnabled = true
                    switch result {
                    case .success:
                        Diagnostics.local().record(.exportCompleted)
                        self.statusLabel.stringValue = self.localized("诊断日志已导出，可将文件发给开发者。", "Diagnostic logs exported. You can send the file to the developer.")
                        NSWorkspace.shared.activateFileViewerSelecting([destination])
                    case .failure(let error):
                        Diagnostics.local().record(.exportFailed, error: error)
                        self.statusLabel.stringValue = self.localized("导出失败：\(error.localizedDescription)", "Export failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    @objc private func applyAndRestartFinder() {
        guard !repairInProgress else { return }
        let alert = NSAlert()
        alert.messageText = localized("修复 Finder 菜单？", "Repair Finder menus?")
        alert.informativeText = localized("将重新注册当前 App 的 Finder 扩展并请求启用。若仍未启用，会打开系统扩展设置供你确认；已启用时会重启当前用户的 Finder，窗口会短暂关闭。普通设置无需修复。", "This registers this app's Finder extension and requests activation. If it remains disabled, system extension settings will open for confirmation. If enabled, your Finder will restart and windows will briefly close. Ordinary settings do not need repair.")
        alert.addButton(withTitle: localized("修复", "Repair"))
        alert.addButton(withTitle: localized("取消", "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Diagnostics.local().record(.repairStarted)
        repairInProgress = true
        restartFinderButton.isEnabled = false
        statusLabel.stringValue = localized("正在注册 Finder 扩展…", "Registering Finder extension…")
        let appURL = Bundle.main.bundleURL
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try FinderIntegration().register(appURL: appURL) }
            DispatchQueue.main.async {
                self.refreshExtensionStatus()
                switch result {
                case .failure(let error):
                    Diagnostics.local().record(.registrationFailed, error: error)
                    self.finishRepair(self.localized("注册失败：\(error.localizedDescription)", "Registration failed: \(error.localizedDescription)"))
                case .success:
                    guard FIFinderSyncController.isExtensionEnabled else {
                        Diagnostics.local().record(.extensionState, value: 0)
                        self.finishRepair(self.localized("已请求启用；请在系统扩展设置中确认，然后返回此窗口检查状态。", "Activation requested. Confirm in system extension settings, then return to check the status."))
                        self.openExtensionSettings()
                        return
                    }
                    Diagnostics.local().record(.extensionState, value: 1)
                    DispatchQueue.global(qos: .userInitiated).async {
                        let restart = Result { try FinderIntegration().restartFinder() }
                        DispatchQueue.main.async {
                            switch restart {
                            case .success:
                                self.finishRepair(self.localized("扩展已启用，已发送 Finder 重启请求。请在普通本地文件夹中验证菜单。", "Extension enabled; Finder restart requested. Check the menu in a regular local folder."))
                            case .failure(let error):
                                Diagnostics.local().record(.restartFailed, error: error)
                                self.finishRepair(self.localized("扩展已注册，但重启失败：\(error.localizedDescription)", "Extension registered, but restart failed: \(error.localizedDescription)"))
                            }
                        }
                    }
                }
            }
        }
    }

    private func finishRepair(_ message: String) {
        repairInProgress = false
        restartFinderButton.isEnabled = true
        statusLabel.stringValue = message
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindowController: SettingsWindowController?
    private var pendingSettingsWindow: DispatchWorkItem?
    private var handledLaunchAction = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = loadSettings().appearance.applicationAppearance
        Diagnostics.local().record(.appStarted)
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
        Diagnostics.local().record(.commandReceived, operation: command)
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
        default:
            if let kind = SourceFileKind(rawValue: command) { createSourceFile(kind, in: directory) }
            else { Diagnostics.local().record(.unknownCommand) }
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
        guard FileManager.default.createFile(atPath: output.path, contents: Data(), attributes: nil) else {
            Diagnostics.local().record(.fileCreateFailed, operation: "txt")
            return
        }
        log("created txt \(output.path)")
        reveal(output)
    }

    private func createMarkdownFile(in directory: URL) {
        let output = uniqueFile(in: directory, base: loadAppLanguage() == .en ? "New Markdown File" : "新建 Markdown 文件", ext: "md")
        guard FileManager.default.createFile(atPath: output.path, contents: Data(), attributes: nil) else {
            Diagnostics.local().record(.fileCreateFailed, operation: "md")
            return
        }
        log("created md \(output.path)")
        reveal(output)
    }

    private func createSourceFile(_ kind: SourceFileKind, in directory: URL) {
        do {
            let output = try kind.create(in: directory, english: loadAppLanguage() == .en)
            reveal(output)
        } catch {
            Diagnostics.local().record(.fileCreateFailed, error: error, operation: kind.rawValue)
            showCreateFileError()
        }
    }

    private func showCreateFileError() {
        let english = loadAppLanguage() == .en
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = english ? "Could Not Create File" : "无法新建文件"
        alert.informativeText = english ? "Check that the folder exists and is writable, then try again. You can export diagnostic logs from Settings." : "请确认文件夹存在且有写入权限后重试；可在设置中导出诊断日志。"
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
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
            Diagnostics.local().record(.fileCreateFailed, error: error, operation: kind.ext)
        }
        try? FileManager.default.removeItem(at: temp)
    }

    private func createPowerPointFile(at output: URL) {
        guard let template = Bundle.main.url(forResource: "blank", withExtension: "pptx") else {
            Diagnostics.local().record(.templateMissing)
            log("missing bundled PowerPoint template")
            return
        }

        do {
            try FileManager.default.copyItem(at: template, to: output)
            log("created pptx \(output.path)")
            reveal(output)
        } catch {
            log("failed pptx copy: \(error)")
            Diagnostics.local().record(.fileCreateFailed, error: error, operation: "pptx")
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
        catch {
            Diagnostics.local().record(.moveFailed, error: error)
            showMoveError(error.localizedDescription)
        }
    }

    private func paste(into directory: URL) {
        do {
            let result = try moveClipboard.paste(into: directory)
            log("paste: \(result.moved.count) moved, \(result.unchanged.count) unchanged, \(result.failures.count) failed")
            if !result.failures.isEmpty {
                Diagnostics.local().record(.partialMoveFailed, value: result.failures.count)
                showMoveError(loadAppLanguage() == .en
                    ? "Some items could not be moved and remain pending: \(result.failures.joined(separator: ", "))"
                    : "以下项目未能移动，已保留以便重试：\(result.failures.joined(separator: "、"))")
            }
            if let first = result.moved.first { reveal(first) }
        } catch {
            Diagnostics.local().record(.moveFailed, error: error)
            showMoveError(error.localizedDescription)
        }
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
            if process.terminationStatus != 0 { Diagnostics.local().record(.processFailed, value: Int(process.terminationStatus), operation: URL(fileURLWithPath: launchPath).lastPathComponent) }
            return process.terminationStatus
        } catch {
            Diagnostics.local().record(.processFailed, error: error, operation: URL(fileURLWithPath: launchPath).lastPathComponent)
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
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/></Types>
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
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rIdSettings" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/></Relationships>
        """, to: root.appendingPathComponent("word/_rels/document.xml.rels"))
        // Explicitly select modern Word features; omission defaults to legacy compatibility.
        try write("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:compat><w:compatSetting w:name="compatibilityMode" w:uri="http://schemas.microsoft.com/office/word" w:val="15"/></w:compat></w:settings>
        """, to: root.appendingPathComponent("word/settings.xml"))
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
