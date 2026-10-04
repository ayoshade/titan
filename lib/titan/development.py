"""Mise environment recipes and local development database lifecycles."""
from __future__ import annotations
import json
import os
from pathlib import Path

from ops import atomic, command_parser, emit, identifier, locked, read_json, require, run
from packages import plan_install
from paths import CONFIG, ROOT


def recipes():
    return read_json(ROOT / 'default/catalog/development.json')


def recipe_commands(name):
    if name not in recipes(): raise ValueError('Unknown environment: ' + name)
    data = recipes()[name]
    commands = []
    if data.get('packages'): commands.append(plan_install(data['packages']))
    if data.get('tools'): commands.append(['mise', 'use', '-g', *data['tools']])
    commands.extend(data.get('commands', []))
    return commands


def databases():
    return read_json(ROOT / 'default/catalog/databases.json')


def db_file(name):
    return CONFIG / 'development/databases' / (identifier(name) + '.json')


def database_config(name, port=None):
    if name not in databases(): raise ValueError('Unknown database: ' + name)
    spec = databases()[name]
    port = spec['port'] if port is None else port
    if not 1024 <= port <= 65535: raise ValueError('Use an unprivileged TCP port (1024–65535)')
    service = {'image': spec['image'], 'container_name': 'titan-dev-' + name,
               'ports': [f'127.0.0.1:{port}:{spec["port"]}'], 'restart': 'unless-stopped',
               'volumes': [f'data:{spec["data_path"]}']}
    if spec.get('environment'): service['environment'] = spec['environment']
    if spec.get('command'): service['command'] = spec['command']
    return {'name': 'titan-dev-' + name, 'services': {name: service}, 'volumes': {'data': {}}}


def handle(args):
    if args.action == 'list':
        emit({'schema': 1, 'environments': recipes()}); return
    if args.action in ('plan', 'install'):
        commands = recipe_commands(args.name)
        if args.action == 'plan': emit({'schema': 1, 'commands': commands}); return
        require('mise')
        for command in commands: run(*command)
        return
    if args.action == 'tools':
        require('mise'); run('mise', 'ls'); return
    if args.action == 'upgrade':
        require('mise'); run('mise', 'upgrade'); return
    if args.db_action == 'list':
        emit({'schema': 1, 'databases': databases(), 'configured': sorted(p.stem for p in (CONFIG / 'development/databases').glob('*.json'))})
        return
    if args.db_action == 'create':
        data = database_config(args.name, args.port)
        file = db_file(args.name)
        with locked('databases'):
            if file.exists(): raise ValueError('Database configuration exists; preserving it')
            atomic(file, json.dumps(data, indent=2) + '\n')
        print(file); return
    file = db_file(args.name)
    if not file.is_file(): raise ValueError('Create the configuration first: titan dev db create ' + args.name)
    require('docker')
    base = ['sudo', 'docker', 'compose', '-f', str(file)]
    if args.db_action == 'start': run(*base, 'up', '-d')
    elif args.db_action == 'stop': run(*base, 'stop')
    elif args.db_action == 'status': run(*base, 'ps', '--format', 'json')
    elif args.db_action == 'logs': run(*base, 'logs', '--tail', '100')
    # `down` keeps volumes. There is deliberately no data deletion shortcut.
    elif args.db_action == 'remove': run(*base, 'down')


def register(sub):
    parser = command_parser(sub, 'dev', 'Install repeatable mise environments and manage local Docker databases')
    actions = parser.add_subparsers(dest='action', required=True)
    for action in ('list', 'tools', 'upgrade'): actions.add_parser(action)
    for action in ('plan', 'install'):
        item = actions.add_parser(action); item.add_argument('name')
    db = actions.add_parser('db')
    dbactions = db.add_subparsers(dest='db_action', required=True)
    dbactions.add_parser('list')
    item = dbactions.add_parser('create'); item.add_argument('name'); item.add_argument('--port', type=int)
    for action in ('start', 'stop', 'status', 'logs', 'remove'):
        item = dbactions.add_parser(action); item.add_argument('name')
    parser.set_defaults(handler=handle)
