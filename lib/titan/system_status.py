"""Explicit, bounded hardware and system operations. No background probing."""
from __future__ import annotations
import json
import os
from pathlib import Path
import re

from ops import capture, command_parser, emit, plain, require, run


def battery_status(root=Path('/sys/class/power_supply')):
    batteries, power = [], []
    for device in sorted(root.glob('*')):
        try:
            kind = (device / 'type').read_text().strip()
            if kind == 'Battery':
                data = {'device': device.name, 'status': (device / 'status').read_text().strip()}
                for field in ('capacity', 'energy_now', 'energy_full', 'energy_full_design', 'power_now', 'cycle_count'):
                    if (device / field).exists(): data[field] = int((device / field).read_text())
                batteries.append(data)
            elif (device / 'online').exists():
                power.append({'device': device.name, 'online': (device / 'online').read_text().strip() == '1'})
        except OSError: continue
    return {'schema': 1, 'batteries': batteries, 'power': power}


def handle_battery(args):
    emit(battery_status())


def handle_network(args):
    require('nmcli')
    if args.action == 'status':
        # No --show-secrets; SSIDs are omitted from routine agent status.
        devices = []
        data = capture('nmcli', '-t', '-f', 'DEVICE,TYPE,STATE', 'device', 'status')
        for line in data.splitlines():
            fields = line.split(':', 2)
            if len(fields) == 3: devices.append(dict(zip(('device', 'type', 'state'), fields)))
        emit({'schema': 1, 'devices': devices}); return
    if args.action == 'wifi':
        if args.value == 'status': print(capture('nmcli', 'radio', 'wifi'))
        else: run('nmcli', 'radio', 'wifi', args.value)
    elif args.action == 'edit': run('nmtui')
    elif args.action == 'qr':
        # nmcli renders the QR itself; don't pipe credentials through our logs.
        command = ['nmcli', 'device', 'wifi', 'show-password']
        if args.device:
            if not re.fullmatch(r'[A-Za-z0-9_.-]+', args.device): raise ValueError('Invalid network device')
            command += ['ifname', args.device]
        run(*command)


def handle_bluetooth(args):
    require('bluetoothctl')
    if args.action == 'status': run('bluetoothctl', 'show'); return
    if args.action == 'devices': run('bluetoothctl', 'devices'); return
    if args.action == 'power': run('bluetoothctl', 'power', args.value); return
    if args.action == 'pair': run('bluetoothctl'); return
    if not re.fullmatch(r'(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}', args.address): raise ValueError('Invalid Bluetooth address')
    run('bluetoothctl', args.action, args.address, timeout=30)


def handle_power(args):
    require('powerprofilesctl')
    if args.action == 'list': run('powerprofilesctl', 'list')
    elif args.action == 'current': run('powerprofilesctl', 'get')
    else:
        if Path('/etc/systemd/logind.conf.d/99-titan-always-awake.conf').exists() and args.profile != 'performance':
            raise ValueError('This machine has the always-awake/Performance policy; change that policy explicitly first')
        run('powerprofilesctl', 'set', args.profile)


def handle_audio(args):
    require('wpctl')
    if args.action == 'status': run('wpctl', 'status', '-n'); return
    if args.action == 'default':
        if args.id < 1: raise ValueError('Use a positive PipeWire node id')
        run('wpctl', 'set-default', str(args.id)); return
    node = '@DEFAULT_AUDIO_SOURCE@' if args.input else '@DEFAULT_AUDIO_SINK@'
    if args.action == 'volume':
        if args.value is None: run('wpctl', 'get-volume', node)
        else:
            if not 0 <= args.value <= 100: raise ValueError('Volume must be 0–100 percent')
            run('wpctl', 'set-volume', '-l', '1', node, str(args.value) + '%')
    else: run('wpctl', 'set-mute', node, {'on': '1', 'off': '0', 'toggle': 'toggle'}[args.value])


def register(sub):
    parser = command_parser(sub, 'battery', 'Read battery and external-power status as JSON')
    parser.set_defaults(handler=handle_battery)
    parser = command_parser(sub, 'network', 'Network status, radio, local QR display and connection editor')
    actions = parser.add_subparsers(dest='action', required=True)
    actions.add_parser('status'); actions.add_parser('edit')
    item = actions.add_parser('wifi'); item.add_argument('value', choices=('status', 'on', 'off'))
    item = actions.add_parser('qr'); item.add_argument('--device')
    parser.set_defaults(handler=handle_network)
    parser = command_parser(sub, 'bluetooth', 'Bluetooth radio, device lifecycle and interactive pairing')
    actions = parser.add_subparsers(dest='action', required=True)
    for action in ('status', 'devices', 'pair'): actions.add_parser(action)
    item = actions.add_parser('power'); item.add_argument('value', choices=('on', 'off'))
    for action in ('connect', 'disconnect', 'trust', 'untrust', 'remove'):
        item = actions.add_parser(action); item.add_argument('address')
    parser.set_defaults(handler=handle_bluetooth)
    parser = command_parser(sub, 'power', 'Inspect and set power profiles while respecting machine policy')
    actions = parser.add_subparsers(dest='action', required=True)
    for action in ('list', 'current'): actions.add_parser(action)
    item = actions.add_parser('set'); item.add_argument('profile', choices=('performance', 'balanced', 'power-saver'))
    parser.set_defaults(handler=handle_power)
    parser = command_parser(sub, 'audio', 'Inspect audio nodes or choose a default, volume or mute state')
    actions = parser.add_subparsers(dest='action', required=True)
    actions.add_parser('status')
    item = actions.add_parser('default'); item.add_argument('id', type=int)
    item = actions.add_parser('volume'); item.add_argument('value', nargs='?', type=int); item.add_argument('--input', action='store_true')
    item = actions.add_parser('mute'); item.add_argument('value', choices=('on', 'off', 'toggle')); item.add_argument('--input', action='store_true')
    parser.set_defaults(handler=handle_audio)
