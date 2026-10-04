"""Titan's own optional QML extension registry; manifests never run install code."""
from __future__ import annotations
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import tempfile

from ops import atomic, capture, command_parser, emit, identifier, locked, plain, read_json, run, write_json
from paths import CONFIG, GENERATED, ROOT, STATE

PLUGINS = CONFIG / 'plugins'
REGISTRY = CONFIG / 'plugins.json'


def validate(folder):
    folder = Path(folder).expanduser().absolute()
    if folder.is_symlink() or not folder.is_dir(): raise ValueError('Use a regular plugin directory')
    for file in folder.rglob('*'):
        if file.is_symlink(): raise ValueError('Plugin symlinks are not supported')
        if not file.is_dir() and not file.is_file(): raise ValueError('Plugin contains a special file')
    data = read_json(folder / 'manifest.json')
    if data.get('schema') != 1: raise ValueError('Manifest requires schema: 1')
    plugin_id = data.get('id', '')
    if not isinstance(plugin_id, str) or not re.fullmatch(r'[a-z][a-z0-9_-]*\.[a-z][a-z0-9_.-]*', plugin_id) or plugin_id.startswith('titan.'):
        raise ValueError('Use a namespaced id such as local.clock; titan.* is reserved')
    plain(data.get('name', '')); plain(data.get('version', ''))
    if len(data['id']) > 80 or len(data['name']) > 100: raise ValueError('Plugin identity is too long')
    plain(data.get('entry', ''))
    path = PurePosixPath(data['entry'])
    if path.is_absolute() or '..' in path.parts or path.suffix != '.qml' or not (folder / path).is_file():
        raise ValueError('Manifest entry must be an existing relative .qml file')
    kinds = data.get('kinds', [])
    if not isinstance(kinds, list) or not kinds or any(kind not in ('panel', 'service') for kind in kinds):
        raise ValueError('This Titan extension API supports panel and service kinds')
    return data


def enabled_plugins():
    values = read_json(REGISTRY).get('enabled', [])
    if not isinstance(values, list) or any(not isinstance(value, str) for value in values):
        raise ValueError('Plugin registry enabled field must be a list of ids')
    return values


def refresh():
    enabled = enabled_plugins()
    items = []
    for folder in sorted(PLUGINS.glob('*')):
        if not folder.is_dir() or folder.name.startswith('.'): continue
        manifest = validate(folder)
        if manifest['id'] != folder.name: raise ValueError('Plugin folder/id mismatch')
        if manifest['id'] in enabled:
            items.append({'id': manifest['id'], 'source': (folder / manifest['entry']).as_uri()})
    write_json(GENERATED / 'plugins.json', items)
    return items


def handle(args):
    if args.action == 'validate': emit(validate(args.path)); return
    if args.action == 'refresh': emit(refresh()); return
    if args.action == 'list':
        enabled = enabled_plugins()
        result = []
        for folder in sorted(PLUGINS.glob('*')):
            if not folder.is_dir() or folder.name.startswith('.'): continue
            manifest = validate(folder)
            result.append({**manifest, 'enabled': manifest['id'] in enabled, 'path': str(folder)})
        emit({'schema': 1, 'plugins': result}); return
    with locked('plugins'):
        if args.action in ('install', 'add'):
            PLUGINS.mkdir(parents=True, exist_ok=True, mode=0o700)
            with tempfile.TemporaryDirectory(prefix='.stage-', dir=PLUGINS) as stage:
                source = Path(stage) / 'source'
                if args.action == 'add':
                    from apps import http_url
                    url = http_url(args.url)
                    run('git', '-c', 'core.hooksPath=/dev/null', 'clone', '--depth', '1', '--', url, source)
                else:
                    validate(args.path)
                    shutil.copytree(Path(args.path).expanduser(), source)
                manifest = validate(source)
                destination = PLUGINS / manifest['id']
                if destination.exists(): raise ValueError('Plugin id is already installed')
                shutil.move(str(source), destination)
            print(manifest['id'])
            # Installing files never enables code implicitly.
            refresh(); return
        folder = PLUGINS / identifier(args.id)
        manifest = validate(folder)
        enabled = enabled_plugins()
        if args.action == 'enable':
            if args.id not in enabled: enabled.append(args.id)
        else: enabled = [item for item in enabled if item != args.id]
        write_json(REGISTRY, {'schema': 1, 'enabled': enabled})
        if args.action == 'remove':
            backup = STATE / 'plugin-backups' / (args.id + '-' + str(__import__('time').time_ns()))
            backup.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            shutil.move(str(folder), backup)
            print(backup)
        refresh()


def register(sub):
    parser = command_parser(sub, 'plugin', 'Manage optional Titan panel/service QML extensions')
    actions = parser.add_subparsers(dest='action', required=True)
    for action in ('list', 'refresh'): actions.add_parser(action)
    for action in ('install', 'validate'):
        item = actions.add_parser(action); item.add_argument('path')
    item = actions.add_parser('add'); item.add_argument('url')
    for action in ('enable', 'disable', 'remove'):
        item = actions.add_parser(action); item.add_argument('id')
    parser.set_defaults(handler=handle)
