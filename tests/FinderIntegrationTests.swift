import Foundation

@main
enum FinderIntegrationTests {
    static func main() throws {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let app = scratch.appendingPathComponent("App With Spaces.app")
        let info = app.appendingPathComponent("Contents/PlugIns/AstraCreateFinderExtension.appex/Contents/Info.plist")
        try FileManager.default.createDirectory(at: info.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: info)

        var calls: [(String, [String])] = []
        let success = FinderIntegration(run: { tool, args in
            calls.append((tool, args))
            return .init(status: 0, output: "")
        }, diagnostics: nil)
        try success.register(appURL: app)
        precondition(calls.count == 3)
        precondition(calls[0].1 == ["-f", app.path])
        precondition(calls[1].1 == ["-a", app.appendingPathComponent("Contents/PlugIns/AstraCreateFinderExtension.appex").path])
        precondition(calls[2].1 == ["-e", "use", "-i", "com.astracreate.finder.extension"])
        precondition(!calls.contains { $0.0.hasSuffix("killall") }, "Registration must not restart Finder")
        try success.restartFinder()
        precondition(calls.last!.1 == ["-u", NSUserName(), "Finder"])

        for failedStep in 1...3 {
            var count = 0
            let integration = FinderIntegration(run: { _, _ in
                count += 1
                return .init(status: count == failedStep ? 7 : 0, output: "test failure")
            }, diagnostics: nil)
            do {
                try integration.register(appURL: app)
                fatalError("Must reject nonzero exit")
            } catch let error as FinderIntegration.CommandFailure {
                precondition(error.result.status == 7 && error.localizedDescription.contains("test failure"))
                precondition(count == failedStep, "Must stop at the first failure")
            }
        }
        do {
            try success.register(appURL: scratch.appendingPathComponent("missing.app"))
            fatalError("Must reject missing extension")
        } catch is CocoaError { }
        let failedRestart = FinderIntegration(run: { _, _ in .init(status: 1, output: "No matching processes") }, diagnostics: nil)
        do {
            try failedRestart.restartFinder()
            fatalError("Must not report a failed restart as success")
        } catch is FinderIntegration.CommandFailure { }

        // Real subprocess checks only run /bin/sh and never touch registration/Finder.
        let result = try FinderIntegration.execute("/bin/sh", ["-c", "echo out; echo err >&2; exit 9"])
        precondition(result.status == 9 && result.output.contains("out") && result.output.contains("err"))
        print("Passed Finder registration ordering, paths, failure handling and scoped restart checks (mocked system actions).")
    }
}
