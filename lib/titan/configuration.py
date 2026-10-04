"""Copy-once application defaults, inspectable backups and recovery."""
from __future__ import annotations

import datetime
import difflib
import hashlib
import os
from pathlib import Path
import re
import xml.sax.saxutils

from ops import atomic, capture, command_parser, emit, hook, identifier, locked, plain, read_json, run, write_json
from paths import CONFIG, GENERATED, HOME, ROOT, STATE

XDG_CONFIG = Path(os.environ.get('XDG_CONFIG_HOME', HOME / '.config'))
SOURCES = ROOT / 'default/config'
BACKUPS = STATE / 'config-backups'


def catalog():
    return read_json(SOURCES / 'manifest.json', [])


def entry(name):
    item = next((item for item in catalog() if item['id'] == name), None)
    if item is None: raise ValueError('Unknown configuration: ' + name)
    return item


def target(item):
    return XDG_CONFIG / item['path']


def render(item):
    text = (SOURCES / item['path']).read_text()
    for key, value in {'ROOT': ROOT, 'CONFIG': XDG_CONFIG, 'STATE': STATE, 'GENERATED': GENERATED}.items():
        text = text.replace('@@' + key + '@@', str(value))
    return text


def safe_destination(file):
    # A linked directory is user owned too. Never reset through it.
    for part in [file, *file.parents]:
        if part == XDG_CONFIG.parent: break
        if part.is_symlink():
            raise ValueError(f'Refusing to replace configuration through symlink: {part}')
    if file.exists() and not file.is_file():
        raise ValueError('Not a regular configuration file: ' + str(file))


def backup(item):
    file = target(item)
    safe_destination(file)
    if not file.exists(): return None
    token = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ') + '-' + item['id']
    folder = BACKUPS / token
    folder.mkdir(parents=True, mode=0o700)
    atomic(folder / 'content', file.read_bytes().decode('utf-8'))
    write_json(folder / 'metadata.json', {'schema': 1, 'id': item['id'], 'path': item['path'],
                                         'sha256': hashlib.sha256(file.read_bytes()).hexdigest()})
    return token


def install_defaults(names=()):
    wanted = [entry(name) for name in names] if names else catalog()
    result = []
    with locked('config'):
        for item in wanted:
            file = target(item)
            if file.exists() or file.is_symlink():
                result.append({'id': item['id'], 'status': 'preserved'})
                continue
            # Do not traverse a foreign linked parent even on first install.
            try:
                safe_destination(file)
            except ValueError:
                result.append({'id': item['id'], 'status': 'preserved-linked-directory'})
                continue
            atomic(file, render(item))
            result.append({'id': item['id'], 'status': 'installed'})
    return result


def handle_config(args):
    if args.action == 'list':
        result = []
        for item in catalog():
            file = target(item)
            status = 'symlink' if file.is_symlink() else 'missing'
            if file.is_file() and not file.is_symlink():
                status = 'default' if file.read_text() == render(item) else 'customized'
            result.append({**item, 'target': str(file), 'status': status})
        emit({'schema': 1, 'files': result}); return
    if args.action == 'install':
        emit(install_defaults(args.ids)); return
    if args.action == 'backups':
        emit([{'backup': file.parent.name, **read_json(file)} for file in sorted(BACKUPS.glob('*/metadata.json'))]); return
    if args.action == 'restore':
        token = identifier(args.backup)
        folder = BACKUPS / token
        metadata = read_json(folder / 'metadata.json')
        if not metadata: raise ValueError('Unknown backup: ' + token)
        item = entry(metadata['id'])
        content = (folder / 'content').read_bytes().decode('utf-8')
        if metadata['path'] != item['path'] or hashlib.sha256(content.encode()).hexdigest() != metadata['sha256']:
            raise ValueError('Backup metadata or content changed')
        with locked('config'):
            safe_destination(target(item))
            previous = backup(item)
            atomic(target(item), content)
        emit({'restored': token, 'previous_backup': previous}); return
    item = entry(args.id)
    file = target(item)
    if args.action == 'diff':
        current = file.read_text() if file.is_file() else ''
        print(''.join(difflib.unified_diff(current.splitlines(keepends=True), render(item).splitlines(keepends=True),
                                         fromfile=str(file), tofile='Titan default')), end='')
        return
    with locked('config'):
        safe_destination(file)
        token = backup(item)
        if args.action == 'reset': atomic(file, render(item))
    emit({'id': item['id'], 'backup': token})


def fonts():
    families = capture('fc-list', '--format', '%{family}\n')
    return sorted({family.strip() for line in families.splitlines() for family in line.split(',') if family.strip()})


def handle_font(args):
    if args.action == 'list':
        emit(fonts()); return
    if args.action == 'current':
        print(read_json(CONFIG / 'font.json').get('family', 'JetBrains Mono')); return
    family = plain(args.family)
    if family not in fonts(): raise ValueError('Font family is not installed; use titan font list')
    with locked('font'):
        write_json(CONFIG / 'font.json', {'family': family})
        atomic(GENERATED / 'kitty-font.conf', 'font_family ' + family + '\n')
        document = ('<?xml version="1.0"?>\n<!DOCTYPE fontconfig SYSTEM "fonts.dtd">\n<fontconfig>\n'
               ' <match target="pattern"><test name="family"><string>monospace</string></test>\n'
               ' <edit name="family" mode="prepend_first" binding="strong"><string>'
               + xml.sax.saxutils.escape(family) + '</string></edit></match>\n</fontconfig>\n')
        atomic(XDG_CONFIG / 'fontconfig/conf.d/99-titan-monospace.conf', document)
    run(ROOT / 'scripts/apply-theme')
    hook('font-set', family)


def register(sub):
    parser = command_parser(sub, 'config', 'Install, compare, back up and restore application dotfiles')
    actions = parser.add_subparsers(dest='action', required=True)
    for action in ('list', 'backups'): actions.add_parser(action)
    item = actions.add_parser('install'); item.add_argument('ids', nargs='*')
    for action in ('diff', 'backup', 'reset'):
        item = actions.add_parser(action); item.add_argument('id')
    item = actions.add_parser('restore'); item.add_argument('backup')
    parser.set_defaults(handler=handle_config)
    parser = command_parser(sub, 'font', 'List installed fonts and select the monospace family')
    actions = parser.add_subparsers(dest='action', required=True)
    for action in ('list', 'current'): actions.add_parser(action)
    item = actions.add_parser('set'); item.add_argument('family')
    parser.set_defaults(handler=handle_font)
