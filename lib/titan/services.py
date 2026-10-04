"""Explicit optional service lifecycles over reviewed package recipes."""
from __future__ import annotations
import subprocess

from ops import command_parser, emit, require, run
from packages import bundle, plan_install

SERVICES = {
    'docker': {'bundle': 'docker', 'unit': 'docker.service'},
    'printing': {'bundle': 'printing', 'unit': 'cups.service'},
    'tailscale': {'bundle': 'tailscale', 'unit': 'tailscaled.service'},
}


def commands(name):
    service = SERVICES[name]
    return [plan_install(bundle(service['bundle'])['packages']),
            ['sudo', 'systemctl', 'enable', '--now', '--', service['unit']]]


def handle(args):
    if args.action == 'list':
        result = []
        for name, service in SERVICES.items():
            installed = subprocess.run(['systemctl', 'cat', service['unit']], capture_output=True).returncode == 0
            active = subprocess.run(['systemctl', 'is-active', '--quiet', service['unit']], capture_output=True).returncode == 0
            result.append({'id': name, **service, 'installed': installed, 'active': active})
        emit({'schema': 1, 'services': result}); return
    if args.action == 'plan':
        emit({'schema': 1, 'commands': commands(args.name)}); return
    if args.action == 'setup':
        for command in commands(args.name): run(*command)
        return
    service = SERVICES[args.name]
    if args.action in ('enable', 'disable'):
        require('systemctl')
        run('systemctl', 'cat', service['unit'], stdout=subprocess.DEVNULL)
        run('sudo', 'systemctl', args.action, '--now', '--', service['unit']); return
    if args.action == 'status':
        result = subprocess.run(['systemctl', 'status', '--no-pager', service['unit']])
        return result.returncode
    require('tailscale')
    if args.action == 'login': run('sudo', 'tailscale', 'up')
    elif args.action == 'logout': run('sudo', 'tailscale', 'logout')
    elif args.action == 'receive':
        from pathlib import Path
        path = Path(args.destination).expanduser().resolve(strict=True)
        if not path.is_dir(): raise ValueError('Select an existing destination directory')
        run('sudo', 'tailscale', 'file', 'get', '--', path)


def register(sub):
    parser = command_parser(sub, 'service', 'Set up and control reviewed optional system services')
    actions = parser.add_subparsers(dest='action', required=True)
    actions.add_parser('list')
    for action in ('plan', 'setup', 'enable', 'disable', 'status'):
        item = actions.add_parser(action); item.add_argument('name', choices=SERVICES)
    for action in ('login', 'logout'):
        item = actions.add_parser(action); item.add_argument('name', choices=('tailscale',))
    item = actions.add_parser('receive'); item.add_argument('name', choices=('tailscale',)); item.add_argument('destination')
    parser.set_defaults(handler=handle)
