import Foundation

/// Optional developer formats. Kept off by default in both settings and Finder.
enum SourceFileKind: String, CaseIterable {
    case json, js, ts, vue, html, css, yaml

    var displayName: String {
        switch self {
        case .js: return "JavaScript"
        case .ts: return "TypeScript"
        case .vue: return "Vue"
        default: return rawValue.uppercased()
        }
    }

    func baseName(english: Bool) -> String {
        english ? "New \(displayName) File" : "新建 \(displayName) 文件"
    }

    func contents(english: Bool) -> Data {
        let text: String
        switch self {
        case .json: text = "{}\n"
        case .js, .ts, .css, .yaml: text = ""
        case .vue:
            text = "<script setup>\n</script>\n\n<template>\n  <main></main>\n</template>\n\n<style scoped>\n</style>\n"
        case .html:
            let language = english ? "en" : "zh-CN"
            let title = english ? "Untitled" : "未命名"
            text = "<!doctype html>\n<html lang=\"\(language)\">\n<head>\n  <meta charset=\"utf-8\">\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n  <title>\(title)</title>\n</head>\n<body>\n</body>\n</html>\n"
        }
        return Data(text.utf8)
    }

    func create(in directory: URL, english: Bool) throws -> URL {
        let data = contents(english: english)
        let base = baseName(english: english)
        var number = 1
        while true {
            let name = number == 1 ? base : "\(base) \(number)"
            let output = directory.appendingPathComponent(name).appendingPathExtension(rawValue)
            do {
                // Exclusive creation also protects against another action winning the same name.
                try data.write(to: output, options: .withoutOverwriting)
                return output
            } catch CocoaError.fileWriteFileExists {
                number += 1
            }
        }
    }
}
