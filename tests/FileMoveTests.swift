import Foundation

@main
struct FileMoveTests {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("AstraCreate-move-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        let source = root.appendingPathComponent("source")
        let destination = root.appendingPathComponent("destination")
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        let clipboard = FileMoveClipboard(url: root.appendingPathComponent("state/clipboard.json"))
        func check(_ condition: Bool, _ label: String) { precondition(condition, label) }
        let first = source.appendingPathComponent("file.txt")
        let contents = Data("original".utf8)
        try contents.write(to: first)
        let before = try fm.attributesOfItem(atPath: first.path)[.systemFileNumber] as! NSNumber
        try clipboard.store([first.path])
        check(try Data(contentsOf: first) == contents, "Cut changed contents")
        let unchanged = try clipboard.paste(into: source)
        check(unchanged.moved.isEmpty && unchanged.unchanged == [first], "Same-directory paste moved file")
        check((try fm.attributesOfItem(atPath: first.path)[.systemFileNumber] as! NSNumber) == before, "Same-directory paste replaced file")
        check(clipboard.paths().isEmpty, "Completed same-directory paste should clear pending items")
        try Data("existing destination".utf8).write(to: destination.appendingPathComponent("file.txt"))
        let missing = source.appendingPathComponent("missing.txt")
        try clipboard.store([first.path, missing.path])
        let mixed = try clipboard.paste(into: destination)
        check(mixed.moved.count == 1 && mixed.failures == ["missing.txt"], "Partial failure results")
        check(!fm.fileExists(atPath: first.path), "Successful move left source")
        check(try Data(contentsOf: destination.appendingPathComponent("file 2.txt")) == contents, "Collision destination contents")
        check(try String(contentsOf: destination.appendingPathComponent("file.txt"), encoding: .utf8) == "existing destination", "Overwrite regression")
        check(clipboard.paths() == [missing.path], "Failed item was lost")
        try Data("retry".utf8).write(to: missing)
        let retry = try clipboard.paste(into: destination)
        check(retry.moved.count == 1 && clipboard.paths().isEmpty, "Retry failed")
        let child = source.appendingPathComponent("nested")
        try fm.createDirectory(at: child, withIntermediateDirectories: true)
        try clipboard.store([source.path])
        let recursive = try clipboard.paste(into: child)
        check(recursive.moved.isEmpty && recursive.failures == ["source"] && clipboard.paths() == [source.path], "Recursive move was allowed")
        do {
            _ = try clipboard.paste(into: root.appendingPathComponent("does-not-exist"))
            preconditionFailure("Invalid destination accepted")
        } catch { check(clipboard.paths() == [source.path], "Invalid destination erased pending items") }
        print("Passed cut integrity, same-directory, collision, partial failure, retry, recursive move and invalid destination tests.")
    }
}
