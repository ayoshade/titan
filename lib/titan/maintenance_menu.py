"""Quickshell menu adapters over the same command families used by agents."""
import json

from apps import CHOICES, default, spawn, terminal, WEBAPPS
from configuration import catalog as config_catalog
from development import recipes
from packages import catalog as package_catalog
from ops import read_json
from paths import ROOT


def row(label, command, detail=''):
    return {'label': label, 'detail': detail, 'action': 'maintenance', 'value': json.dumps(command), 'icon': 'chevron-right'}


def items(kind):
    if kind == 'install-packages':
        return [row(name, ['pkg', 'bundle', name, '--apply'], ', '.join(data['packages'] + data.get('aur', []))) for name, data in package_catalog().items()]
    if kind == 'install-dev':
        return [row(name, ['dev', 'install', name], 'mise environment') for name in recipes()]
    if kind.startswith('defaults-'):
        category = kind.removeprefix('defaults-')
        if category not in CHOICES: raise ValueError('Unknown default category')
        return [row(value, ['defaults', 'set', category, value], 'Current' if value == default(category) else 'Requires installed executable') for value in CHOICES[category]]
    if kind == 'config-reset':
        return [row(item['id'], ['config', 'reset', item['id']], 'Reset to Titan default; previous file is backed up') for item in config_catalog()]
    if kind == 'config-diff':
        return [row(item['id'], ['config', 'diff', item['id']], 'Compare your file with Titan defaults') for item in config_catalog()]
    if kind == 'remove-webapps':
        return [row(data['name'], ['webapp', 'remove', data['id']], 'Remove the managed launcher')
                for data in (read_json(file) for file in sorted(WEBAPPS.glob('*.json')))]
    raise ValueError('Unknown maintenance menu: ' + kind)


def launch(value):
    command = json.loads(value)
    if not isinstance(command, list) or not command or any(not isinstance(item, str) for item in command):
        raise ValueError('Maintenance command must be an argv array')
    if command[0] not in ('pkg', 'dev', 'service', 'defaults', 'config', 'webapp', 'plugin', 'doctor', 'update', 'migrate', '--dialog'):
        raise ValueError('Unknown maintenance command family')
    spawn(terminal([str(ROOT / 'scripts/titan-task'), *command]))
