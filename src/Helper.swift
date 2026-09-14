import Foundation

private let logURL = URL(fileURLWithPath: "/tmp/AstraCreateHost.log")

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

    var baseName: String {
        switch self {
        case .docx: return "新建 Word 文档"
        case .xlsx: return "新建 Excel 表格"
        case .pptx: return "新建 PowerPoint 演示文稿"
        }
    }
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
    let directory = URL(fileURLWithPath: path)
    log("helper command \(command) path \(directory.path)")
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
    default: log("helper unknown command \(command)")
    }
}

private func createTextFile(in directory: URL) {
    let output = uniqueFile(in: directory, base: "新建文本文件", ext: "txt")
    FileManager.default.createFile(atPath: output.path, contents: Data(), attributes: nil)
    log("created txt \(output.path)")
    reveal(output)
}

private func createMarkdownFile(in directory: URL) {
    let output = uniqueFile(in: directory, base: "新建 Markdown 文件", ext: "md")
    FileManager.default.createFile(atPath: output.path, contents: Data(), attributes: nil)
    log("created md \(output.path)")
    reveal(output)
}

private func createOfficeFile(kind: OfficeKind, in directory: URL) {
    let output = uniqueFile(in: directory, base: kind.baseName, ext: kind.ext)
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
        case .pptx: break
        }
        let status = runProcess("/usr/bin/zip", arguments: ["-Xqr", output.path, "."], currentDirectory: temp)
        log("zip status \(status), output \(output.path)")
        reveal(output)
    } catch {
        log("failed \(kind.ext): \(error)")
    }
    try? FileManager.default.removeItem(at: temp)
}

private func createPowerPointFile(at output: URL) {
    let executable = URL(fileURLWithPath: CommandLine.arguments[0])
    let appBundle = executable
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let template = appBundle.appendingPathComponent("Contents/Resources/blank.pptx")

    do {
        try FileManager.default.copyItem(at: template, to: output)
        log("created pptx \(output.path)")
        reveal(output)
    } catch {
        log("failed pptx copy from \(template.path): \(error)")
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

private func cut(paths: [String]) {
    let existing = paths.filter { FileManager.default.fileExists(atPath: $0) }
    guard !existing.isEmpty else {
        log("cut skipped: no selected paths")
        return
    }

    let payload: [String: Any] = ["operation": "move", "paths": existing]
    do {
        let data = try JSONSerialization.data(withJSONObject: payload)
        try data.write(to: clipboardURL(), options: .atomic)
        log("cut stored \(existing.count) item(s)")
    } catch {
        log("cut failed: \(error)")
    }
}

private func paste(into directory: URL) {
    guard let data = try? Data(contentsOf: clipboardURL()),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let operation = object["operation"] as? String,
          operation == "move" else {
        log("paste skipped: no cut clipboard")
        return
    }

    let paths = (object["paths"] as? [Any] ?? []).compactMap { $0 as? String }
    var revealed: [URL] = []
    for path in paths {
        let source = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: source.path) else {
            log("paste missing source \(source.path)")
            continue
        }

        let destination = uniqueDestination(for: source, in: directory)
        do {
            try FileManager.default.moveItem(at: source, to: destination)
            revealed.append(destination)
            log("moved \(source.path) -> \(destination.path)")
        } catch {
            log("move failed \(source.path): \(error)")
        }
    }

    try? FileManager.default.removeItem(at: clipboardURL())
    log("paste completed with \(revealed.count) moved item(s)")
    if let first = revealed.first {
        reveal(first)
    }
}

private func clipboardURL() -> URL {
    URL(fileURLWithPath: "/private/tmp/AstraCreateClipboard.json")
}

private func uniqueDestination(for source: URL, in directory: URL) -> URL {
    let name = source.deletingPathExtension().lastPathComponent
    let ext = source.pathExtension
    var index = 1
    while true {
        let suffix = index == 1 ? "" : " \(index)"
        let fileName = ext.isEmpty ? "\(name)\(suffix)" : "\(name)\(suffix).\(ext)"
        let candidate = directory.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        index += 1
    }
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
        return process.terminationStatus
    } catch {
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
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/></Types>
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
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
    """, to: root.appendingPathComponent("word/_rels/document.xml.rels"))
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

let args = CommandLine.arguments
log("helper launch args \(args.dropFirst().joined(separator: " "))")
guard args.count >= 3 else {
    log("helper skipped: missing args")
    exit(2)
}
let selectedPaths = parseSelectedPaths(args.dropFirst(3).first)
run(command: args[1], path: args[2], selectedPaths: selectedPaths)
