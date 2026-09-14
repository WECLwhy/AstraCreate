import Foundation

/// Cutting only records paths. Moving occurs exclusively during paste.
struct FileMoveClipboard {
    let url: URL

    struct Payload: Codable {
        var operation = "move"
        var paths: [String]
    }
    struct Result {
        var moved: [URL] = []
        var unchanged: [URL] = []
        var failures: [String] = []
    }

    func paths() -> [String] {
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.operation == "move" else { return [] }
        return payload.paths
    }

    func store(_ paths: [String]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(Payload(paths: paths)).write(to: url, options: .atomic)
    }

    func paste(into directory: URL) throws -> Result {
        let fm = FileManager.default
        let sourcePaths = paths()
        var result = Result()
        var remaining: [String] = []
        let destinationFolder = directory.resolvingSymlinksInPath().standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: destinationFolder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw CocoaError(.fileNoSuchFile)
        }
        for path in sourcePaths {
            let source = URL(fileURLWithPath: path).standardizedFileURL
            guard fm.fileExists(atPath: source.path) else {
                remaining.append(path)
                result.failures.append(source.lastPathComponent)
                continue
            }
            // Pasting back into the same directory must never rename the source.
            if source.deletingLastPathComponent().resolvingSymlinksInPath() == destinationFolder {
                result.unchanged.append(source)
                continue
            }
            // Prevent moving a folder into itself or a descendant.
            var sourceIsDirectory: ObjCBool = false
            _ = fm.fileExists(atPath: source.path, isDirectory: &sourceIsDirectory)
            let canonicalSource = source.resolvingSymlinksInPath().path
            if sourceIsDirectory.boolValue && (destinationFolder.path == canonicalSource || destinationFolder.path.hasPrefix(canonicalSource + "/")) {
                remaining.append(path)
                result.failures.append(source.lastPathComponent)
                continue
            }
            var destination = destinationFolder.appendingPathComponent(source.lastPathComponent)
            var index = 2
            while fm.fileExists(atPath: destination.path) {
                let ext = source.pathExtension
                let base = source.deletingPathExtension().lastPathComponent
                let name = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
                destination = destinationFolder.appendingPathComponent(name)
                index += 1
            }
            do {
                try fm.moveItem(at: source, to: destination)
                result.moved.append(destination)
            } catch {
                remaining.append(path)
                result.failures.append(source.lastPathComponent)
            }
        }
        // Retain failed items for retry. Successful items must not be moved twice.
        try store(remaining)
        return result
    }
}
