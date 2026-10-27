#!/usr/bin/env python3
"""Generate Wiki mirrors from canonical docs; never pushes or deletes pages."""
import argparse
from pathlib import Path
import re
import subprocess
from urllib.parse import urlsplit, unquote

ROOT = Path(__file__).resolve().parents[1]
BASE = 'https://github.com/WECLwhy/AstraCreate'
TOPICS = {'quick-start': 'Quick-Start', 'installation': 'Installation',
          'finder-troubleshooting': 'Finder-Troubleshooting', 'features': 'Features',
          'appearance': 'Appearance', 'updates-and-diagnostics': 'Updates-and-Diagnostics'}
PAGES = {ROOT / 'docs/README.md': 'Home', ROOT / 'docs/compatibility.md': 'Compatibility'}
for language in ['zh', 'en']:
    for slug, title in TOPICS.items():
        PAGES[ROOT / f'docs/{language}/{slug}.md'] = f'{title}-{language}'


def generate():
    pages = {}
    for source, title in PAGES.items():
        def link(match):
            label, target = match.groups()
            parsed = urlsplit(target)
            if parsed.scheme or parsed.netloc or not parsed.path:
                return match.group()
            destination = (source.parent / unquote(parsed.path)).resolve()
            relative = destination.relative_to(ROOT).as_posix()
            if destination in PAGES:
                url = BASE + '/wiki/' + PAGES[destination]
            elif label.startswith('!'):
                url = 'https://raw.githubusercontent.com/WECLwhy/AstraCreate/main/' + relative
            else:
                url = BASE + '/blob/main/' + relative
            if parsed.fragment:
                url += '#' + parsed.fragment
            return f'{label}({url})'
        content = re.sub(r'(!?\[[^\]]*\])\(([^\s)]+)\)', link, source.read_text())
        pages[title + '.md'] = content + '\n---\n\n[Canonical source / 正文来源](' + BASE + '/blob/main/' + source.relative_to(ROOT).as_posix() + ')\n'
    sidebar = ['[Home / 首页](' + BASE + '/wiki)', '', '中文：']
    for language in ['zh', 'en']:
        if language == 'en':
            sidebar += ['', 'English:']
        for slug, title in TOPICS.items():
            heading = (ROOT / f'docs/{language}/{slug}.md').read_text().splitlines()[0].removeprefix('# ')
            sidebar.append(f'- [{heading}]({BASE}/wiki/{title}-{language})')
    sidebar += ['', f'[Compatibility / 兼容性]({BASE}/wiki/Compatibility)']
    pages['_Sidebar.md'] = '\n'.join(sidebar) + '\n'
    pages['_Footer.md'] = f'[Download / 下载]({BASE}/releases/latest) · [Support / 反馈]({BASE}/blob/main/SUPPORT.md) · [Privacy / 隐私]({BASE}/blob/main/PRIVACY.md)\n'
    return pages


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('target', type=Path)
    parser.add_argument('--preview', action='store_true', help='Write only to an empty preview directory, without Git access')
    parser.add_argument('--check', action='store_true', help='Fail on mirror drift without writing')
    args = parser.parse_args()
    target = args.target.resolve()
    if args.preview:
        if target.exists() and any(target.iterdir()):
            raise SystemExit('Preview target must be empty')
    else:
        origin = subprocess.check_output(['git', '-C', str(target), 'remote', 'get-url', 'origin'], text=True).strip()
        if origin not in [BASE + '.wiki.git', 'git@github.com:WECLwhy/AstraCreate.wiki.git']:
            raise SystemExit('Target must be the AstraCreate Wiki checkout')
    pages = generate()
    if args.check:
        drift = [name for name, content in pages.items() if not (target / name).is_file() or (target / name).read_text() != content]
        if drift:
            raise SystemExit('Wiki drift: ' + ', '.join(drift))
    else:
        target.mkdir(parents=True, exist_ok=True)
        for name, content in pages.items():
            (target / name).write_text(content)
    print(f'{len(pages)} Wiki files checked/generated; no push or deletion performed.')


if __name__ == '__main__':
    main()
