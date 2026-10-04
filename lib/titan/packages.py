"""Reviewed optional bundles and package operations; no implicit installation."""
from __future__ import annotations
import re
import shutil

from ops import capture, command_parser, emit, read_json, require, run
from paths import ROOT


def catalog():
    return read_json(ROOT / 'default/catalog/packages.json')


def package_names(values):
    if not values or any(not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9@._+-]*', name) for name in values):
        raise ValueError('Supply valid package names, without options or paths')
    return values


def bundle(name):
    if name not in catalog(): raise ValueError('Unknown bundle: ' + name)
    return catalog()[name]


def plan_install(names):
    return ['sudo', 'pacman', '-Syu', '--needed', '--', *package_names(names)]


def handle(args):
    if args.action == 'list':
        emit({'schema': 1, 'bundles': catalog()}); return
    if args.action == 'bundle':
        data = bundle(args.name)
        commands = [plan_install(data['packages'])] if data['packages'] else [['sudo', 'pacman', '-Syu']]
        if data.get('aur'):
            helper = next((name for name in ('paru', 'yay') if shutil.which(name)), 'paru')
            commands.append([helper, '-S', '--needed', '--', *package_names(data['aur'])])
        if args.apply:
            require('pacman')
            if data.get('repositories'):
                configured = capture('pacman-conf', '--repo-list').splitlines()
                missing = set(data['repositories']) - set(configured)
                if missing: raise ValueError('Enable required repositories explicitly first: ' + ', '.join(sorted(missing)))
            # Preflight every executable before starting the package transaction.
            for command in commands: require(command[0])
            for command in commands: run(*command)
        else:
            emit({'schema': 1, 'bundle': args.name, 'commands': commands, 'repositories': data.get('repositories', []),
                  'after_install': data.get('after_install', [])})
        return
    require('pacman')
    if args.action == 'search':
        run('pacman', '-Ss', '--', args.query); return
    if args.action == 'installed':
        run('pacman', '-Q'); return
    names = package_names(args.names)
    if args.action == 'info': run('pacman', '-Si', '--', *names)
    elif args.action == 'present':
        result = run('pacman', '-Qq', '--', *names, capture_output=True, text=True)
        print(result.stdout, end='')
    elif args.action == 'add':
        command = plan_install(names)
        if args.plan: emit({'schema': 1, 'commands': [command]})
        else: run(*command)
    elif args.action == 'remove':
        # pacman prompts; retain dependency packages and configuration by default.
        command = ['sudo', 'pacman', '-R', '--', *names]
        if args.plan: emit({'schema': 1, 'commands': [command]})
        else: run(*command)
    elif args.action == 'aur':
        helper = next((name for name in ('paru', 'yay') if shutil.which(name)), None)
        if not helper: raise ValueError('Install and review an AUR helper (paru or yay) separately')
        if args.plan:
            emit({'schema': 1, 'commands': [['sudo', 'pacman', '-Syu'], [helper, '-S', '--needed', '--', *names]]})
        else:
            run('sudo', 'pacman', '-Syu')
            run(helper, '-S', '--needed', '--', *names)


def register(sub):
    parser = command_parser(sub, 'pkg', 'Package search, full upgrades and reviewed optional bundles')
    actions = parser.add_subparsers(dest='action', required=True)
    for action in ('list', 'installed'): actions.add_parser(action)
    item = actions.add_parser('bundle'); item.add_argument('name'); item.add_argument('--apply', action='store_true')
    item = actions.add_parser('search'); item.add_argument('query')
    for action in ('info', 'present', 'add', 'remove', 'aur'):
        item = actions.add_parser(action); item.add_argument('names', nargs='+')
        if action in ('add', 'remove', 'aur'): item.add_argument('--plan', action='store_true')
    parser.set_defaults(handler=handle)
