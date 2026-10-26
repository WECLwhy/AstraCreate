import Foundation

@main
struct SourceFileTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        precondition(SourceFileKind(rawValue: "pdf") == nil)
        for english in [false, true] {
            for kind in SourceFileKind.allCases {
                let first = try kind.create(in: root, english: english)
                let original = try Data(contentsOf: first)
                precondition(first.pathExtension == kind.rawValue)
                precondition(first.deletingPathExtension().lastPathComponent == kind.baseName(english: english))
                let second = try kind.create(in: root, english: english)
                precondition(second != first && second.deletingPathExtension().lastPathComponent.hasSuffix(" 2"))
                let preserved = try Data(contentsOf: first)
                precondition(preserved == original)
                let text = String(decoding: original, as: UTF8.self)
                switch kind {
                case .json:
                    let object = try JSONSerialization.jsonObject(with: original)
                    precondition(object is [String: Any])
                case .html:
                    precondition(text.contains("<!doctype html>") && text.contains("charset=\"utf-8\""))
                    precondition(text.contains(english ? "lang=\"en\"" : "lang=\"zh-CN\""))
                case .vue:
                    precondition(text.contains("<script setup>") && text.contains("<template>") && text.contains("<style scoped>"))
                default:
                    precondition(original.isEmpty)
                }
            }
        }
        // A colliding directory and a symlink must also remain untouched.
        let collision = root.appendingPathComponent("collision", isDirectory: true)
        try FileManager.default.createDirectory(at: collision, withIntermediateDirectories: true)
        let firstName = collision.appendingPathComponent("New JSON File.json", isDirectory: true)
        try FileManager.default.createDirectory(at: firstName, withIntermediateDirectories: false)
        let target = collision.appendingPathComponent("existing.txt")
        try Data("keep me".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: collision.appendingPathComponent("New JSON File 2.json"), withDestinationURL: target)
        let third = try SourceFileKind.json.create(in: collision, english: true)
        precondition(third.lastPathComponent == "New JSON File 3.json")
        let preservedTarget = try String(contentsOf: target, encoding: .utf8)
        precondition(preservedTarget == "keep me")
        // Simultaneous requests may choose the same name; exclusive writes retry safely.
        let concurrent = root.appendingPathComponent("concurrent", isDirectory: true)
        try FileManager.default.createDirectory(at: concurrent, withIntermediateDirectories: true)
        let group = DispatchGroup()
        let lock = NSLock()
        var paths = Set<String>()
        var failures = 0
        for _ in 0..<12 {
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }
                do {
                    let url = try SourceFileKind.json.create(in: concurrent, english: true)
                    lock.lock(); paths.insert(url.path); lock.unlock()
                } catch { lock.lock(); failures += 1; lock.unlock() }
            }
        }
        group.wait()
        precondition(failures == 0 && paths.count == 12)
        do {
            _ = try SourceFileKind.json.create(in: root.appendingPathComponent("missing"), english: true)
            fatalError("Missing destination must fail")
        } catch { }
        print("Passed seven UTF-8 developer formats, bilingual names, template structure, PDF exclusion, collision/symlink preservation, concurrent creation and missing destination checks.")
    }
}
