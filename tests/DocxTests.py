#!/usr/bin/env python3
"""Execute both production DOCX writers and inspect their generated OOXML packages."""
from pathlib import Path
import subprocess
import tempfile
import textwrap
import zipfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
R = 'http://schemas.openxmlformats.org/package/2006/relationships'
CT = 'http://schemas.openxmlformats.org/package/2006/content-types'
CACHE = ROOT / 'build/tests/module-cache'
CACHE.mkdir(parents=True, exist_ok=True)

def function(source, name):
    lines = source.splitlines(keepends=True)
    start = next(i for i, line in enumerate(lines) if f'private func {name}(' in line)
    indent = len(lines[start]) - len(lines[start].lstrip())
    end = next(i for i in range(start + 1, len(lines)) if lines[i].rstrip() == ' ' * indent + '}')
    return textwrap.dedent(''.join(lines[start:end + 1]))

with tempfile.TemporaryDirectory(prefix='AstraCreate-docx-tests-') as scratch:
    scratch = Path(scratch)
    for name in ['Main', 'Helper']:
        source = (ROOT / f'src/{name}.swift').read_text()
        swift = scratch / f'{name}.swift'
        swift.write_text('import Foundation\n' + '\n'.join(function(source, fn) for fn in ['write', 'writeDocxTemplate', 'writeCommonProps']) + '\ntry writeDocxTemplate(to: URL(fileURLWithPath: CommandLine.arguments[1]))\n')
        executable = scratch / name
        subprocess.run(['xcrun', 'swiftc', '-module-cache-path', str(CACHE), str(swift), '-o', str(executable)], check=True)
        parts = scratch / f'{name}-parts'
        subprocess.run([str(executable), str(parts)], check=True)
        archive = scratch / f'{name}.docx'
        with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as z:
            for p in parts.rglob('*'):
                if p.is_file():
                    z.write(p, p.relative_to(parts))
        with zipfile.ZipFile(archive) as z:
            assert z.testzip() is None
            settings = ET.fromstring(z.read('word/settings.xml'))
            mode = settings.find(f'{{{W}}}compat/{{{W}}}compatSetting')
            assert mode is not None and mode.attrib == {f'{{{W}}}name': 'compatibilityMode', f'{{{W}}}uri': 'http://schemas.microsoft.com/office/word', f'{{{W}}}val': '15'}, name
            rels = ET.fromstring(z.read('word/_rels/document.xml.rels'))
            assert len([r for r in rels if r.get('Type') == 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings' and r.get('Target') == 'settings.xml']) == 1, name
            types = ET.fromstring(z.read('[Content_Types].xml'))
            assert len([t for t in types if t.get('PartName') == '/word/settings.xml' and t.get('ContentType') == 'application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml']) == 1, name
            for n in z.namelist():
                if n.endswith(('.xml', '.rels')): ET.fromstring(z.read(n))
            core = ET.fromstring(z.read('docProps/core.xml'))
            assert not any((e.text or '').strip() for e in core if e.tag.split('}')[-1] in ['creator', 'lastModifiedBy']), name
        print(f'{name}: generated DOCX compatibility mode, relationships, content types and empty author fields passed.')
