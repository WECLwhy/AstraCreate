import AppKit

@MainActor
final class UpdateUIController: NSObject {
    private weak var window: NSWindow?
    private let english: () -> Bool
    private let status: (String) -> Void
    private let busy: (Bool) -> Void
    private let updater: GitHubUpdater
    private let install: (VerifiedUpdatePackage) async throws -> Void
    private var task: Task<Void, Never>?
    private var progressPanel: NSPanel?
    private let progressBar = NSProgressIndicator()
    private let progressLabel = NSTextField(labelWithString: "")

    init(window: NSWindow?, english: @escaping () -> Bool, status: @escaping (String) -> Void, busy: @escaping (Bool) -> Void,
         updater: GitHubUpdater? = nil, install: @escaping (VerifiedUpdatePackage) async throws -> Void = UpdateUIController.openInstaller) {
        self.window = window
        self.english = english
        self.status = status
        self.busy = busy
        self.updater = updater ?? GitHubUpdater(currentVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")
        self.install = install
    }

    private func text(_ zh: String, _ en: String) -> String { english() ? en : zh }

    func check() {
        guard task == nil else { return }
        busy(true)
        status(text("正在检查 GitHub 正式发布…", "Checking GitHub releases…"))
        Diagnostics.local().record(.updateCheckStarted)
        task = Task { [weak self] in
            guard let self else { return }
            defer { closeProgress(); task = nil; busy(false) }
            do {
                let result = try await updater.check()
                try Task.checkCancellation()
                Diagnostics.local().record(.updateCheckSucceeded)
                switch result {
                case .current(let latest):
                    let message = text("当前版本无需更新。已安装 \(updater.currentVersion)，GitHub 正式版 \(latest)。", "No update needed. Installed: \(updater.currentVersion); GitHub release: \(latest).")
                    status(message)
                    let alert = NSAlert()
                    alert.messageText = text("无需更新", "No Update Needed")
                    alert.informativeText = message
                    alert.addButton(withTitle: text("好", "OK"))
                    _ = await present(alert)
                case .available(let update):
                    status(text("发现新版本 \(update.version.text)。等待下载与安装确认。", "Version \(update.version.text) is available. Awaiting approval."))
                    let alert = updateAlert(update)
                    let response = await present(alert)
                    if response == .alertThirdButtonReturn {
                        NSWorkspace.shared.open(update.release.html_url)
                        return
                    }
                    guard response == .alertFirstButtonReturn else {
                        Diagnostics.local().record(.updateCancelled)
                        status(text("尚未下载或安装更新。", "No update was downloaded or installed."))
                        return
                    }
                    try Task.checkCancellation()
                    showProgress()
                    Diagnostics.local().record(.updateDownloadStarted)
                    let package = try await updater.prepare(update, approved: true) { [weak self] value in
                        Task { @MainActor in
                            guard let self, self.progressPanel != nil else { return }
                            self.progressBar.doubleValue = value
                            self.progressLabel.stringValue = self.text("下载并校验安装包… \(Int(value * 100))%", "Downloading and verifying… \(Int(value * 100))%")
                        }
                    }
                    try Task.checkCancellation()
                    Diagnostics.local().record(.updateVerified)
                    closeProgress()
                    do { try await install(package) }
                    catch {
                        Diagnostics.local().record(.updateInstallerFailed, error: error)
                        throw UpdateError.installerFailed
                    }
                    Diagnostics.local().record(.updateInstallerOpened)
                    status(text("安装包已校验，已打开 macOS 安装器。请按提示完成覆盖安装，完成后重新打开 AstraCreate。", "Package verified; macOS Installer opened. Complete the installation, then reopen AstraCreate."))
                }
            } catch {
                closeProgress()
                if Task.isCancelled || (error as? URLError)?.code == .cancelled || error is CancellationError {
                    Diagnostics.local().record(.updateCancelled)
                    status(text("更新已取消，未启动安装。", "Update cancelled; installation was not started."))
                } else {
                    Diagnostics.local().record(.updateFailed, error: error)
                    let message = Self.message(error, english: english())
                    status(message)
                    let alert = NSAlert()
                    alert.alertStyle = .warning
                    alert.messageText = text("更新未完成", "Update Not Completed")
                    alert.informativeText = message
                    alert.addButton(withTitle: text("好", "OK"))
                    alert.addButton(withTitle: text("打开发布页", "Open Releases"))
                    if await present(alert) == .alertSecondButtonReturn { NSWorkspace.shared.open(GitHubUpdater.projectURL.appendingPathComponent("releases/latest")) }
                }
            }
        }
    }

    private func updateAlert(_ update: AvailableUpdate) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = text("发现新版本 \(update.version.text)", "Version \(update.version.text) Is Available")
        let size = ByteCountFormatter.string(fromByteCount: update.installer.size, countStyle: .file)
        alert.informativeText = text("\(updater.currentVersion) → \(update.version.text)（\(size)）。来源：WECLwhy/AstraCreate。确认后下载并校验 SHA-256，再打开 macOS 安装器；系统仍会要求安装授权。取消不会下载或安装。", "\(updater.currentVersion) → \(update.version.text) (\(size)), from WECLwhy/AstraCreate. After approval, download and verify SHA-256, then open macOS Installer. macOS still requires installation authorization. Cancelling starts no download or installation.")
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 460, height: 150))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let notes = NSTextView(frame: scroll.contentView.bounds)
        notes.isEditable = false
        notes.isSelectable = true
        notes.font = .systemFont(ofSize: 12)
        notes.textColor = .labelColor
        notes.string = String((update.release.body ?? text("此版本没有提供更新说明。", "No release notes provided.")).prefix(12000))
        notes.textContainer?.widthTracksTextView = true
        notes.autoresizingMask = [.width]
        scroll.documentView = notes
        alert.accessoryView = scroll
        alert.addButton(withTitle: text("下载并安装…", "Download & Install…"))
        alert.addButton(withTitle: text("稍后", "Later"))
        alert.addButton(withTitle: text("打开发布页", "Open Release Page"))
        return alert
    }

    private func present(_ alert: NSAlert) async -> NSApplication.ModalResponse {
        alert.window.appearance = window?.effectiveAppearance
        if let window {
            return await withCheckedContinuation { continuation in
                alert.beginSheetModal(for: window) { continuation.resume(returning: $0) }
            }
        }
        return alert.runModal()
    }

    private func showProgress() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 440, height: 140), styleMask: [.titled], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.title = text("更新 AstraCreate", "Update AstraCreate")
        panel.appearance = window?.effectiveAppearance
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 14
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: panel.contentView!.centerYAnchor)
        ])
        progressLabel.stringValue = text("正在下载并校验安装包…", "Downloading and verifying package…")
        progressLabel.font = .systemFont(ofSize: 13)
        stack.addArrangedSubview(progressLabel)
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 1
        progressBar.doubleValue = 0
        stack.addArrangedSubview(progressBar)
        progressBar.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        let cancel = NSButton(title: text("取消下载", "Cancel Download"), target: self, action: #selector(cancelDownload))
        cancel.bezelStyle = .rounded
        stack.addArrangedSubview(cancel)
        progressPanel = panel
        if let window { window.beginSheet(panel) }
        else { panel.center(); panel.makeKeyAndOrderFront(nil) }
    }

    @objc private func cancelDownload() { task?.cancel() }
    private func closeProgress() {
        guard let panel = progressPanel else { return }
        if let parent = panel.sheetParent { parent.endSheet(panel) }
        panel.orderOut(nil)
        progressPanel = nil
    }

    static func openInstaller(_ package: VerifiedUpdatePackage) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.open([package.url], withApplicationAt: URL(fileURLWithPath: "/System/Library/CoreServices/Installer.app"), configuration: configuration) { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    static func message(_ error: Error, english: Bool) -> String {
        func t(_ zh: String, _ en: String) -> String { english ? en : zh }
        switch error as? UpdateError {
        case .http(let code): return t("GitHub 返回 HTTP \(code)，请稍后重试。", "GitHub returned HTTP \(code). Please try again later.")
        case .invalidMetadata, .invalidVersion: return t("发布信息或版本格式无效，已停止更新。", "Invalid release metadata or version; update stopped.")
        case .untrustedSource: return t("更新来源不符合该项目的 GitHub 发布地址，已停止更新。", "The update source does not match this project's GitHub release; update stopped.")
        case .noInstaller: return t("此版本没有适用的 PKG 安装包。", "This release has no compatible PKG installer.")
        case .missingChecksum, .invalidChecksum: return t("此版本缺少有效的 SHA-256 校验信息，已停止自动更新。", "No valid SHA-256 information is available; automatic update stopped.")
        case .sizeMismatch, .hashMismatch, .notPackage: return t("安装包未通过完整性校验，已停止安装。请重新检查更新。", "Package integrity verification failed; installation stopped. Check again to retry.")
        case .quarantineFailed: return t("无法设置安装包的下载来源标记，已停止自动安装。", "Could not mark the downloaded package's origin; automatic installation stopped.")
        case .approvalRequired: return t("尚未获得下载与安装同意。", "Download and installation have not been approved.")
        case .installerFailed: return t("无法打开 macOS 安装器。可在项目发布页重新下载安装包。", "Could not open macOS Installer. You can download the package from the release page.")
        case nil:
            if (error as? URLError)?.code == .timedOut { return t("连接 GitHub 超时，请稍后重试。", "The GitHub connection timed out. Please try again later.") }
            if let code = (error as? URLError)?.code, [.serverCertificateUntrusted, .serverCertificateHasBadDate, .secureConnectionFailed].contains(code) {
                return t("GitHub 安全连接验证失败，已停止更新。请检查网络或系统时间。", "GitHub secure connection validation failed; update stopped. Check your connection or system time.")
            }
            return t("无法完成更新，请检查网络或可用存储空间后重试；可导出诊断日志。", "Could not complete the update. Check your connection and free space, then retry. Diagnostic logs can be exported.")
        }
    }
}
