import Foundation

/// Runs only after the user requests repair. A successful command is not proof
/// that macOS has enabled or loaded the extension; the UI checks FinderSync too.
struct FinderIntegration {
    struct CommandResult {
        let status: Int32
        let output: String
    }

    struct CommandFailure: LocalizedError {
        let tool: String
        let result: CommandResult
        var errorDescription: String? {
            "\(tool) (exit \(result.status)): \(result.output.prefix(500))"
        }
    }

    var run: (String, [String]) throws -> CommandResult = execute
    var diagnostics: Diagnostics? = .local()

    func register(appURL: URL) throws {
        let extensionURL = appURL.appendingPathComponent("Contents/PlugIns/AstraCreateFinderExtension.appex")
        guard FileManager.default.fileExists(atPath: extensionURL.appendingPathComponent("Contents/Info.plist").path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        try checked("/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister", ["-f", appURL.path])
        try checked("/usr/bin/pluginkit", ["-a", extensionURL.path])
        try checked("/usr/bin/pluginkit", ["-e", "use", "-i", "com.astracreate.finder.extension"])
    }

    func restartFinder() throws {
        try checked("/usr/bin/killall", ["-u", NSUserName(), "Finder"])
    }

    private func checked(_ executable: String, _ arguments: [String]) throws {
        let result = try run(executable, arguments)
        let event: DiagnosticEvent
        switch URL(fileURLWithPath: executable).lastPathComponent {
        case "lsregister": event = .launchServicesResult
        case "pluginkit": event = arguments.first == "-a" ? .extensionRegistrationResult : .extensionActivationResult
        default: event = .finderRestartResult
        }
        diagnostics?.record(event, value: Int(result.status))
        guard result.status == 0 else {
            throw CommandFailure(tool: URL(fileURLWithPath: executable).lastPathComponent, result: result)
        }
    }

    static func execute(_ executable: String, _ arguments: [String]) throws -> CommandResult {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return CommandResult(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }
}
