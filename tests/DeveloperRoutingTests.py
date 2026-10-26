"""Exercise the real host/helper command handlers with only UI/system effects stubbed."""
import json
from pathlib import Path
import subprocess
import tempfile
import textwrap

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / 'build/tests/module-cache'


def function(source, name):
    lines = source.splitlines(keepends=True)
    start = next(i for i, line in enumerate(lines) if f'private func {name}(' in line)
    indent = len(lines[start]) - len(lines[start].lstrip())
    end = next(i for i in range(start + 1, len(lines)) if lines[i].rstrip() == ' ' * indent + '}')
    return textwrap.dedent(''.join(lines[start:end + 1]))


stubs = '''
import Foundation
enum AppLanguage { case zh, en }
enum OfficeKind { case docx, xlsx, pptx }
enum DiagnosticEvent { case commandReceived, unknownCommand, fileCreateFailed }
var unknownCommands = 0
var failures = 0
var revealed = 0
struct Diagnostics {
    static func local(_ component: String = "host") -> Diagnostics { Diagnostics() }
    func record(_ event: DiagnosticEvent, error: Error? = nil, operation: String? = nil) {
        if event == .unknownCommand { unknownCommands += 1 }
        if event == .fileCreateFailed { failures += 1 }
    }
}
func loadAppLanguage() -> AppLanguage { CommandLine.arguments[2] == "en" ? .en : .zh }
func log(_ message: String) {}
func reveal(_ url: URL) { revealed += 1 }
func showCreateFileError() {}
func createOfficeFile(kind: OfficeKind, in directory: URL) { fatalError("Unexpected Office route") }
func createTextFile(in directory: URL) { fatalError("Unexpected TXT route") }
func createMarkdownFile(in directory: URL) { fatalError("Unexpected Markdown route") }
func openTerminal(at directory: URL) { fatalError("Unexpected Terminal route") }
func openVSCode(at directory: URL) { fatalError("Unexpected VS Code route") }
func cut(paths: [String]) { fatalError("Unexpected cut route") }
func paste(into directory: URL) { fatalError("Unexpected paste route") }
'''
driver = '''
for command in ["json", "js", "ts", "vue", "html", "css", "yaml", "pdf"] {
    run(command: command, path: CommandLine.arguments[1], selectedPaths: [])
}
precondition(revealed == 7 && unknownCommands == 1 && failures == 0)
run(command: "json", path: CommandLine.arguments[1] + "/missing", selectedPaths: [])
precondition(revealed == 7 && failures == 1)
'''

with tempfile.TemporaryDirectory(prefix='AstraCreate-developer-routing-') as scratch:
    scratch = Path(scratch)
    for writer in ['Main', 'Helper']:
        directory = scratch / writer
        directory.mkdir()
        source = (ROOT / f'src/{writer}.swift').read_text()
        harness = directory / 'main.swift'
        harness.write_text(stubs + '\n'.join(function(source, name) for name in ['run', 'createSourceFile']) + driver)
        executable = directory / 'test-handler'
        subprocess.run(['xcrun', 'swiftc', '-module-cache-path', str(CACHE), str(harness), str(ROOT / 'src/SourceFileTemplates.swift'), '-o', str(executable)], check=True)
        for language in ['zh', 'en']:
            output = directory / language
            output.mkdir()
            subprocess.run([str(executable), str(output), language], check=True)
            files = list(output.iterdir())
            assert len(files) == 7
            assert {f.suffix for f in files} == {'.json', '.js', '.ts', '.vue', '.html', '.css', '.yaml'}
            for file in files:
                text = file.read_text(encoding='utf-8')
                if file.suffix == '.json':
                    assert json.loads(text) == {}
                if writer == 'Main' and language == 'en':
                    assert file.name.startswith('New ')
                else:
                    assert file.name.startswith('新建 ')
        print(f'{writer}: actual developer command handlers created seven files, revealed successes and logged failure/unknown-PDF routes (UI/system effects stubbed).')
