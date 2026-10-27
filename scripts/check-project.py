#!/usr/bin/env python3
"""Offline version, docs, privacy and release-package checks. Never installs."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import plistlib
import re
import stat
import struct
import subprocess
import tempfile
from urllib.parse import unquote, urlsplit
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SKIP = {'.git', 'build', 'dist', '.build', '__pycache__'}
TOKENS = re.compile(rb'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|AKIA[A-Z0-9]{16}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----)')
IDENTITY = re.compile(rb'/(?:Users|home)/[^/\s\x00]+/')


def metadata_tags(data):
    endian = '<' if data[:2] == b'II' else '>'
    assert data[:2] in [b'II', b'MM'], 'Invalid TIFF metadata'
    tags, seen = [], set()
    def walk(offset):
        assert offset + 2 <= len(data), 'Invalid metadata offset'
        if offset in seen:
            return
        seen.add(offset)
        count = struct.unpack_from(endian + 'H', data, offset)[0]
        assert count < 1024 and offset + 2 + count * 12 <= len(data), 'Invalid metadata entries'
        for index in range(count):
            tag, _, _, value = struct.unpack_from(endian + 'HHII', data, offset + 2 + index * 12)
            tags.append(tag)
            if tag in [34665, 34853, 40965]:
                walk(value)
    walk(struct.unpack_from(endian + 'I', data, 4)[0])
    return tags


def inspect(name, data):
    # Only these exact, synthetic privacy-filter regression fixtures are exempt.
    safe = data
    fixtures = {'tests/DiagnosticsTests.swift': b'/Users/Private Person/',
                'tests/ExtensionDiagnosticsTests.m': b'/' + b'Users' + b'/private/'}
    for suffix, value in fixtures.items():
        if name.endswith(suffix):
            safe = safe.replace(value, b'/EXAMPLE/')
    assert not TOKENS.search(safe), f'Credential pattern in {name} (value suppressed)'
    assert not IDENTITY.search(safe), f'Personal absolute path in {name} (value suppressed)'
    if data.startswith(b'\x89PNG\r\n\x1a\n'):
        offset = 8
        while offset + 12 <= len(data):
            length = int.from_bytes(data[offset:offset + 4], 'big')
            kind = data[offset + 4:offset + 8]
            assert offset + 12 + length <= len(data), f'Invalid PNG: {name}'
            assert kind not in [b'tEXt', b'iTXt', b'zTXt'], f'Unreviewed PNG text metadata: {name}'
            if kind == b'eXIf':
                tags = metadata_tags(data[offset + 8:offset + 8 + length])
                assert set(tags) <= {34665, 40961, 40962, 40963}, f'Identity-capable EXIF: {name}'
            offset += length + 12
    if data.startswith(b'icns'):
        offset = 8
        while offset + 8 <= len(data):
            length = int.from_bytes(data[offset + 4:offset + 8], 'big')
            assert length >= 8 and offset + length <= len(data), f'Invalid ICNS: {name}'
            inspect(name + '/icon', data[offset + 8:offset + length])
            offset += length
    if name.endswith(('.docx', '.xlsx', '.pptx')):
        with zipfile.ZipFile(io.BytesIO(data)) as office:
            if 'docProps/core.xml' in office.namelist():
                for field in ET.fromstring(office.read('docProps/core.xml')):
                    if field.tag.split('}')[-1] in ['creator', 'lastModifiedBy']:
                        assert not (field.text or '').strip(), f'Office author metadata: {name}'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package-dir', type=Path)
    args = parser.parse_args()
    app = plistlib.loads((ROOT / 'AppInfo.plist').read_bytes())
    extension = plistlib.loads((ROOT / 'ExtensionInfo.plist').read_bytes())
    for key in ['CFBundleShortVersionString', 'CFBundleVersion']:
        assert app[key] == extension[key], f'Host/extension {key} mismatch'
    version = app['CFBundleShortVersionString']
    assert re.fullmatch(r'[0-9]+(?:\.[0-9]+){0,3}', version), 'Invalid version'
    count = 0
    for path in ROOT.rglob('*'):
        rel = path.relative_to(ROOT)
        if any(part in SKIP for part in rel.parts) or not path.is_file():
            continue
        assert not path.is_symlink(), f'Unreviewed symlink: {rel}'
        inspect(rel.as_posix(), path.read_bytes())
        count += 1
        if path.suffix == '.md':
            for target in re.findall(r'!?\[[^\]]*\]\(([^\s)]+)\)', path.read_text()):
                parsed = urlsplit(target)
                if parsed.scheme or parsed.netloc or not parsed.path:
                    continue
                destination = (path.parent / unquote(parsed.path)).resolve()
                assert destination.is_relative_to(ROOT) and destination.exists(), f'Broken local link in {rel}: {target}'
    for name in ['bug_report.yml', 'feature_request.yml']:
        form = json.loads((ROOT / '.github/ISSUE_TEMPLATE' / name).read_text())
        assert form['name'] and form['description'] and form['body'], f'Incomplete form: {name}'
        ids = [field['id'] for field in form['body'] if 'id' in field]
        assert len(ids) == len(set(ids)), f'Duplicate form IDs: {name}'
    if args.package_dir:
        directory = args.package_dir.resolve()
        names = [f'AstraCreate-{version}.pkg', f'AstraCreate-Finder-{version}-source.zip']
        expected = {name: hashlib.sha256((directory / name).read_bytes()).hexdigest() for name in names}
        lines = (directory / f'AstraCreate-{version}-SHA256SUMS.txt').read_text().splitlines()
        assert len(lines) == 2, 'Expected exactly two checksum entries'
        for line in lines:
            digest, name = line.split(None, 1)
            assert expected.pop(name.strip()) == digest, 'Checksum mismatch'
        assert not expected, 'Missing checksum entries'
        with zipfile.ZipFile(directory / names[1]) as archive:
            assert archive.testzip() is None, 'Source ZIP CRC failure'
            for entry in archive.infolist():
                parts = Path(entry.filename).parts
                assert parts and parts[0] == 'AstraCreate-Finder' and '..' not in parts and not entry.filename.startswith('/'), 'Unsafe ZIP path'
                assert not set(parts) & SKIP and not stat.S_ISLNK(entry.external_attr >> 16), 'Private/symlink ZIP entry'
                assert not any(part == '.env' or part.startswith('.env.') for part in parts), 'Environment file in ZIP'
                assert Path(entry.filename).suffix not in ['.pem', '.key', '.p12', '.cer'], 'Credential file in ZIP'
                if not entry.is_dir():
                    inspect(entry.filename, archive.read(entry))
        with tempfile.TemporaryDirectory(prefix='AstraCreate-pkg-audit-') as tmp:
            expanded = Path(tmp) / 'expanded'
            subprocess.run(['/usr/sbin/pkgutil', '--expand-full', str(directory / names[0]), str(expanded)], check=True)
            installed = expanded / 'Payload/Applications/AstraCreate.app'
            info = plistlib.loads((installed / 'Contents/Info.plist').read_bytes())
            assert info['CFBundleShortVersionString'] == version and info['CFBundleVersion'] == app['CFBundleVersion'], 'PKG version mismatch'
            subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(installed)], check=True)
            for path in expanded.rglob('*'):
                if path.is_file():
                    inspect(path.relative_to(expanded).as_posix(), path.read_bytes())
        print('Release PKG/source ZIP/checksums/privacy verified; no installation performed.')
    print(f'Checked {count} project files, versions, local documentation links and privacy patterns.')


if __name__ == '__main__':
    main()
