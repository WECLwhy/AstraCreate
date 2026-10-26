import Foundation

@main
enum DiagnosticsTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let host = root.appendingPathComponent("host")
        let ext = root.appendingPathComponent("extension")
        let logger = Diagnostics(directory: host, component: "host")
        let secret = "/Users/Private Person/secret-client.docx?token=secret-value"
        let error = NSError(domain: NSCocoaErrorDomain, code: 513,
                            userInfo: [NSLocalizedDescriptionKey: secret, NSFilePathErrorKey: secret])
        precondition(logger.record(.fileCreateFailed, error: error, operation: secret))
        let url = host.appendingPathComponent("host.jsonl")
        var text = try String(contentsOf: url, encoding: .utf8)
        precondition(!text.contains("Private Person") && !text.contains("secret-value"))
        var log = Diagnostics.readLog(at: url)
        precondition((log["events"] as! [[String: Any]]).first?["errorCode"] as? Int == 513)
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        precondition((attrs[.posixPermissions] as! NSNumber).intValue == 0o600)
        precondition(!Diagnostics(directory: host, component: "../escape").record(.appStarted))
        precondition(!Diagnostics(directory: URL(fileURLWithPath: "/dev/null/no-directory"), component: "host").record(.appStarted))

        // Inject arbitrary fields/unknown events and an attacker-controlled error domain.
        var row: [String: Any] = ["event": "fileCreateFailed", "component": "host",
                                 "time": "2026-10-26T01:02:03Z", "message": secret,
                                 "errorDomain": secret, "errorCode": 42, "operation": secret, "version": secret]
        var fixture = try JSONSerialization.data(withJSONObject: row)
        fixture.append(10)
        row["event"] = secret
        fixture.append(try JSONSerialization.data(withJSONObject: row))
        fixture.append(contentsOf: "\ninvalid-json\n".utf8)
        try fixture.write(to: url)
        let exported = try Diagnostics.exportData(hostDirectory: host, extensionDirectory: ext, extensionEnabled: false)
        text = String(decoding: exported, as: UTF8.self)
        precondition(!text.contains("Private Person") && !text.contains("secret-value") && !text.contains("message"))
        let report = try JSONSerialization.jsonObject(with: exported) as! [String: Any]
        let logs = report["logs"] as! [String: [String: Any]]
        precondition(logs["extension"]?["state"] as? String == "missing")
        precondition(logs["helper"]?["state"] as? String == "missing")
        precondition(logs["host"]?["droppedRecords"] as? Int == 2)
        precondition(report["extensionEnabled"] as? Bool == false)

        // Only new structured log files are read. Legacy logs and clipboard stay out.
        try Data(secret.utf8).write(to: host.appendingPathComponent("extension.log"))
        try Data(secret.utf8).write(to: host.appendingPathComponent("clipboard.json"))
        // Exercise bounded retention across enough writes to rotate repeatedly.
        for value in 0..<3500 { precondition(logger.record(.processFailed, value: value)) }
        let bytes = try Data(contentsOf: url)
        precondition(bytes.count <= Diagnostics.maxBytes)
        log = Diagnostics.readLog(at: url)
        let rows = log["events"] as! [[String: Any]]
        precondition(rows.last?["value"] as? Int == 3499)
        precondition(log["droppedRecords"] as? Int == 0)
        // Writers sharing a file must not interleave JSON records.
        try Data().write(to: url)
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            precondition(logger.record(.processFailed, value: index))
        }
        precondition((Diagnostics.readLog(at: url)["events"] as! [[String: Any]]).count == 100)
        // Oversized and symlink inputs must not be copied into an export.
        try Data(repeating: 65, count: Diagnostics.maxBytes + 1).write(to: url)
        precondition(Diagnostics.readLog(at: url)["state"] as? String == "invalid_or_oversized")
        try FileManager.default.removeItem(at: url)
        let privateFile = root.appendingPathComponent("private.txt")
        try Data(secret.utf8).write(to: privateFile)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: privateFile)
        precondition(!logger.record(.appStarted))
        precondition(Diagnostics.readLog(at: url)["state"] as? String == "unreadable")
        let privateContents = try String(contentsOf: privateFile, encoding: .utf8)
        precondition(privateContents == secret)
        print("Passed diagnostic retention, concurrent writes, privacy filtering, missing/invalid logs, permissions and symlink checks.")
    }
}
