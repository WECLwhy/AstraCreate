import Foundation
import Darwin

/// Structured events only. Never pass paths, URLs, command arguments or error descriptions.
enum DiagnosticEvent: String, CaseIterable {
    case appStarted, settingsReadFailed, settingsSaveFailed, commandReceived, unknownCommand
    case fileCreateFailed, templateMissing, moveFailed, partialMoveFailed
    case processFailed, repairStarted, launchServicesResult, extensionRegistrationResult, extensionActivationResult, finderRestartResult, registrationFailed, restartFailed
    case extensionState, exportStarted, exportCompleted, exportFailed
    case extensionStarted, menuRequested, hostLaunchFailed, commandEncodingFailed, clipboardWriteFailed
    case updateCheckStarted, updateCheckSucceeded, updateDownloadStarted, updateVerified, updateInstallerOpened, updateInstallerFailed, updateCancelled, updateFailed
    case projectPageFailed
}

struct Diagnostics {
    static let maxBytes = 256 * 1024
    static let knownDomains = [NSCocoaErrorDomain, NSPOSIXErrorDomain, NSOSStatusErrorDomain, NSURLErrorDomain]
    static let components = ["host", "helper", "extension"]
    static let operations = ["docx", "xlsx", "pptx", "txt", "md", "json", "js", "ts", "vue", "html", "css", "yaml", "terminal", "vscode", "cut", "paste", "copyPath", "zip", "open"]
    let directory: URL
    let component: String

    static func local(_ component: String = "host") -> Diagnostics {
        Diagnostics(directory: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AstraCreate/Diagnostics-v1"), component: component)
    }

    @discardableResult
    func record(_ event: DiagnosticEvent, error: Error? = nil, value: Int? = nil, operation: String? = nil) -> Bool {
        guard Self.components.contains(component) else { return false }
        var row: [String: Any] = ["schema": 1, "time": ISO8601DateFormatter().string(from: Date()),
                                  "component": component, "event": event.rawValue,
                                  "version": Self.version(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")),
                                  "build": Self.version(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion"))]
        if let value { row["value"] = value }
        if let operation { row["operation"] = Self.operations.contains(operation) ? operation : "unknown" }
        if let error {
            let ns = error as NSError
            row["errorCode"] = ns.code
            row["errorDomain"] = Self.knownDomains.contains(ns.domain) ? ns.domain : "other"
        }
        guard var data = try? JSONSerialization.data(withJSONObject: row, options: .sortedKeys) else { return false }
        data.append(10)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            let fd = Darwin.open(directory.appendingPathComponent(component + ".jsonl").path,
                                 O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
            guard fd >= 0 else { return false }
            defer { Darwin.close(fd) }
            guard flock(fd, LOCK_EX) == 0 else { return false }
            defer { flock(fd, LOCK_UN) }
            var metadata = stat()
            guard fstat(fd, &metadata) == 0, metadata.st_mode & S_IFMT == S_IFREG else { return false }
            if metadata.st_size + Int64(data.count) > Int64(Self.maxBytes) {
                // Retain complete recent records in the same inode, under the process lock.
                let start = max(0, metadata.st_size - Int64(Self.maxBytes / 2))
                _ = lseek(fd, start, SEEK_SET)
                var buffer = [UInt8](repeating: 0, count: Self.maxBytes / 2)
                let count = Darwin.read(fd, &buffer, buffer.count)
                var tail = count > 0 ? Data(buffer.prefix(count)) : Data()
                if start > 0, let newline = tail.firstIndex(of: 10) { tail = tail.suffix(from: newline + 1) }
                guard ftruncate(fd, 0) == 0, lseek(fd, 0, SEEK_SET) == 0 else { return false }
                guard Self.write(tail, fd: fd) else { return false }
            } else {
                _ = lseek(fd, 0, SEEK_END)
            }
            return Self.write(data, fd: fd)
        } catch { return false } // Logging must never prevent the file action itself.
    }

    private static func write(_ data: Data, fd: Int32) -> Bool {
        data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return true }
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(fd, base.advanced(by: offset), bytes.count - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { return false }
                offset += count
            }
            return true
        }
    }

    private static func version(_ value: Any?) -> String {
        guard let value = value as? String, value.count <= 32,
              value.range(of: #"^[0-9]+(?:\.[0-9]+)*$"#, options: .regularExpression) != nil else { return "unknown" }
        return value
    }

    /// Rebuild every row from allowed fields; never copy arbitrary local log text.
    static func readLog(at url: URL) -> [String: Any] {
        let fd = Darwin.open(url.path, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { return ["state": errno == ENOENT ? "missing" : "unreadable", "events": []] }
        defer { Darwin.close(fd) }
        guard flock(fd, LOCK_SH) == 0 else { return ["state": "unreadable", "events": []] }
        defer { flock(fd, LOCK_UN) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_size <= maxBytes else {
            return ["state": "invalid_or_oversized", "events": []]
        }
        var buffer = [UInt8](repeating: 0, count: maxBytes)
        let count = Darwin.read(fd, &buffer, buffer.count)
        guard count >= 0 else { return ["state": "unreadable", "events": []] }
        let text = String(decoding: buffer.prefix(count), as: UTF8.self)
        var events: [[String: Any]] = []
        var dropped = 0
        for line in text.split(separator: "\n") {
            guard let data = String(line).data(using: .utf8),
                  let row = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let event = row["event"] as? String, DiagnosticEvent(rawValue: event) != nil,
                  let component = row["component"] as? String, components.contains(component),
                  let time = row["time"] as? String, ISO8601DateFormatter().date(from: time) != nil else {
                dropped += 1
                continue
            }
            var clean: [String: Any] = ["event": event, "component": component,
                                      "time": ISO8601DateFormatter().string(from: ISO8601DateFormatter().date(from: time)!),
                                      "version": version(row["version"]), "build": version(row["build"])]
            for key in ["value", "errorCode"] {
                if let number = row[key] as? Int { clean[key] = number }
            }
            if let domain = row["errorDomain"] as? String { clean["errorDomain"] = knownDomains.contains(domain) ? domain : "other" }
            if let operation = row["operation"] as? String { clean["operation"] = operations.contains(operation) ? operation : "unknown" }
            events.append(clean)
        }
        return ["state": "read", "events": events, "droppedRecords": dropped]
    }

    static func exportData(hostDirectory: URL, extensionDirectory: URL, extensionEnabled: Bool,
                           appBundle: Bundle = .main) throws -> Data {
        let extensionURL = appBundle.bundleURL.appendingPathComponent("Contents/PlugIns/AstraCreateFinderExtension.appex")
        var logs: [String: Any] = [:]
        for component in components {
            let directory = component == "extension" ? extensionDirectory : hostDirectory
            logs[component] = readLog(at: directory.appendingPathComponent(component + ".jsonl"))
        }
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "other"
        #endif
        let report: [String: Any] = [
            "format": "AstraCreate diagnostics", "schema": 1,
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "appVersion": version(appBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString")),
            "appBuild": version(appBundle.object(forInfoDictionaryKey: "CFBundleVersion")),
            "systemVersion": ProcessInfo.processInfo.operatingSystemVersionString,
            "architecture": architecture, "extensionEnabled": extensionEnabled,
            "embeddedExtensionPresent": FileManager.default.fileExists(atPath: extensionURL.appendingPathComponent("Contents/Info.plist").path),
            "logs": logs,
            "notes": ["Enabled status does not prove live Finder menu display.",
                      "Missing logs may mean the component has not run; unreadable logs may indicate access restrictions.",
                      "Legacy logs, file paths, command arguments, clipboard queues and file contents are excluded.",
                      "Created locally by user request; no automatic upload."]
        ]
        return try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    }
}
