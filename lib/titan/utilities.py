"""Archives, worktrees, tmux layouts, SSH forwards and owned rsync watchers."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import tarfile
import time

from ops import capture, command_parser, emit, identifier, locked, read_json, require, run, write_json
from paths import ROOT, RUNTIME, STATE

JOBS = STATE / 'jobs'


def handle_archive(args):
    source = Path(args.source).expanduser().resolve(strict=True)
    destination = Path(args.destination).expanduser().absolute() if args.destination else None
    if args.action == 'compress':
        destination = destination or source.with_name(source.name + '.tar.gz')
        if destination.exists() or destination.is_symlink(): raise ValueError('Output already exists')
        if source.is_dir() and destination.is_relative_to(source): raise ValueError('Output cannot be inside the archived directory')
        created = None
        try:
            with tarfile.open(destination, 'x:gz') as archive:
                created = destination.stat()
                archive.add(source, arcname=source.name)
        except Exception:
            if created and destination.exists() and not destination.is_symlink():
                current = destination.stat()
                if (created.st_dev, created.st_ino) == (current.st_dev, current.st_ino): destination.unlink()
            raise
        print(destination); return
    destination = destination or source.with_name(source.name.removesuffix('.tar.gz') + '-extracted')
    if destination.exists() or destination.is_symlink(): raise ValueError('Extract into a new directory to preserve existing files')
    with tarfile.open(source, 'r:*') as archive:
        # Python's data filter rejects traversal, escaping links and device nodes.
        # Inspect all headers before writing the destination.
        for member in archive.getmembers(): tarfile.data_filter(member, str(destination))
        destination.mkdir(mode=0o700)
        archive.extractall(destination, filter='data')
    print(destination)


def handle_worktree(args):
    require('git')
    if args.action == 'list': run('git', 'worktree', 'list', '--porcelain'); return
    if args.action == 'add':
        run('git', 'check-ref-format', '--branch', args.branch, stdout=subprocess.DEVNULL)
        base = Path(capture('git', 'rev-parse', '--show-toplevel'))
        destination = Path(args.path).expanduser().absolute() if args.path else base.with_name(base.name + '--' + args.branch.replace('/', '-'))
        run('git', 'worktree', 'add', '-b', args.branch, '--', destination, stdout=subprocess.DEVNULL)
        print(destination)
        return
    path = Path(args.path).expanduser().resolve(strict=True)
    main = Path(capture('git', 'rev-parse', '--git-common-dir')).resolve().parent
    if path == main: raise ValueError('Cannot remove the main worktree')
    listed = capture('git', 'worktree', 'list', '--porcelain')
    if 'worktree ' + str(path) + '\n' not in listed + '\n': raise ValueError('Path is not a registered worktree')
    branch = capture('git', '-C', path, 'branch', '--show-current')
    if capture('git', '-C', path, 'status', '--porcelain'):
        raise ValueError('Worktree has local changes; preserving it')
    run('git', 'worktree', 'remove', '--', path)
    if args.delete_branch and branch:
        run('git', 'branch', '-d', '--', branch)  # refuses unmerged work


def forward_socket(name):
    RUNTIME.mkdir(parents=True, exist_ok=True, mode=0o700)
    return RUNTIME / ('ssh-' + hashlib.sha256(identifier(name).encode()).hexdigest()[:16])


def handle_forward(args):
    require('ssh')
    if args.action == 'list':
        result = []
        for file in sorted(JOBS.glob('forward-*.json')):
            job = read_json(file)
            test = subprocess.run(['ssh', '-S', str(forward_socket(job['id'])), '-O', 'check', job['host']],
                                  capture_output=True, timeout=5)
            result.append({**job, 'active': test.returncode == 0})
        emit({'schema': 1, 'forwards': result}); return
    name = identifier(args.id)
    file = JOBS / ('forward-' + name + '.json')
    with locked('forward'):
        if args.action == 'stop':
            job = read_json(file)
            if not job: raise ValueError('Unknown managed forward')
            if forward_socket(name).exists():
                run('ssh', '-S', forward_socket(name), '-O', 'exit', job['host'], timeout=5)
            file.unlink(); return
        if file.exists(): raise ValueError('Forward id exists; stop it before creating another')
        if not re.fullmatch(r'(?:[A-Za-z0-9_.-]+@)?[A-Za-z0-9][A-Za-z0-9_.-]*', args.host):
            raise ValueError('Use an SSH host alias or user@host')
        for port in (args.local_port, args.remote_port):
            if not 1024 <= port <= 65535: raise ValueError('Use ports 1024–65535')
        run('ssh', '-MNf', '-o', 'ExitOnForwardFailure=yes', '-o', 'ControlMaster=yes',
            '-S', forward_socket(name), '-L', f'127.0.0.1:{args.local_port}:127.0.0.1:{args.remote_port}', args.host)
        write_json(file, {'schema': 1, 'id': name, 'host': args.host,
                          'local_port': args.local_port, 'remote_port': args.remote_port})


def watch_unit(name):
    return 'titan-watch-' + identifier(name) + '.service'


def watch_worker(source, destination):
    # One event watcher per explicitly started job. No deleting destination files.
    run('rsync', '-a', '-s', '--', source.rstrip('/') + '/', destination)
    process = subprocess.Popen(['inotifywait', '-m', '-r', '-q', '-e', 'close_write,create,delete,move', '--', source],
                               stdout=subprocess.PIPE, text=True)
    try:
        for _ in process.stdout:
            time.sleep(.25)
            run('rsync', '-a', '-s', '--', source.rstrip('/') + '/', destination)
    finally:
        process.terminate()
        process.wait(timeout=5)


def handle_watch(args):
    if args.action == 'worker': return watch_worker(args.source, args.destination)
    if args.action == 'list':
        result = []
        for file in sorted(JOBS.glob('watch-*.json')):
            job = read_json(file)
            test = subprocess.run(['systemctl', '--user', 'is-active', '--quiet', watch_unit(job['id'])])
            result.append({**job, 'active': test.returncode == 0})
        emit({'schema': 1, 'watchers': result}); return
    name = identifier(args.id)
    file = JOBS / ('watch-' + name + '.json')
    with locked('watch'):
        if args.action == 'stop':
            if not file.exists(): raise ValueError('Unknown managed watcher')
            run('systemctl', '--user', 'stop', watch_unit(name))
            file.unlink(); return
        if file.exists(): raise ValueError('Watcher id exists; stop it before creating another')
        source = Path(args.source).expanduser().resolve(strict=True)
        if not source.is_dir(): raise ValueError('Source must be a directory')
        if args.destination.startswith('-') or not args.destination or '\n' in args.destination:
            raise ValueError('Invalid destination')
        if ':' not in args.destination:
            dest = Path(args.destination).expanduser().resolve()
            if dest == source or dest.is_relative_to(source): raise ValueError('Destination cannot be inside the source')
            destination = str(dest)
        else:
            if not re.fullmatch(r'(?:[\w.-]+@)?[\w.-]+:.+', args.destination): raise ValueError('Use host:path for a remote destination')
            destination = args.destination
        require('rsync'); require('inotifywait'); require('systemd-run')
        run('systemd-run', '--user', '--collect', '--unit=' + watch_unit(name),
            ROOT / 'scripts/titan-utilities', 'watch', 'worker', str(source), destination)
        write_json(file, {'schema': 1, 'id': name, 'source': str(source), 'destination': destination})


def handle_tmux(args):
    from apps import CHOICES, default
    require('tmux')
    directory = Path(args.cwd).expanduser().resolve(strict=True)
    if not directory.is_dir(): raise ValueError('Working directory must be a directory')
    session = identifier(args.session)
    if subprocess.run(['tmux', 'has-session', '-t', '=' + session], capture_output=True).returncode == 0:
        raise ValueError('Session already exists; attach with tmux attach -t ' + session)
    editor = CHOICES['editor'][default('editor')]
    agent = CHOICES['agent'][default('agent')]
    if args.layout == 'dev': commands = [[editor], [agent], [os.environ.get('SHELL', '/bin/bash')]]
    elif args.layout == 'square': commands = [[editor], ['git', 'diff'], [os.environ.get('SHELL', '/bin/bash')], [agent]]
    else:
        if not 1 <= args.count <= 16: raise ValueError('Use 1–16 panes')
        if not args.command: raise ValueError('Supply a command for the swarm')
        commands = [args.command] * args.count
    for command in commands: require(command[0])
    run('tmux', 'new-session', '-d', '-s', session, '-c', directory, shlex.join(commands[0]))
    try:
        for command in commands[1:]:
            run('tmux', 'split-window', '-t', '=' + session + ':', '-c', directory, shlex.join(command))
            run('tmux', 'select-layout', '-t', '=' + session + ':', 'tiled')
        first = capture('tmux', 'list-panes', '-t', '=' + session + ':', '-F', '#{pane_id}').splitlines()[0]
        run('tmux', 'select-pane', '-t', first)
    except Exception:
        print('Layout is partially created; attach to inspect it: ' + session)
        raise
    if args.attach:
        run('tmux', 'switch-client' if os.environ.get('TMUX') else 'attach-session', '-t', '=' + session)
    else: print(session)


def register(sub):
    parser = command_parser(sub, 'archive', 'Compress paths or safely extract into a new directory')
    parser.add_argument('action', choices=('compress', 'extract')); parser.add_argument('source'); parser.add_argument('destination', nargs='?')
    parser.set_defaults(handler=handle_archive)
    parser = command_parser(sub, 'worktree', 'Create and remove clean Git worktrees')
    actions = parser.add_subparsers(dest='action', required=True)
    actions.add_parser('list')
    item = actions.add_parser('add'); item.add_argument('branch'); item.add_argument('--path')
    item = actions.add_parser('remove'); item.add_argument('path'); item.add_argument('--delete-branch', action='store_true')
    parser.set_defaults(handler=handle_worktree)
    parser = command_parser(sub, 'forward', 'Manage owned localhost SSH port forwards')
    actions = parser.add_subparsers(dest='action', required=True)
    actions.add_parser('list')
    item = actions.add_parser('start'); item.add_argument('id'); item.add_argument('host'); item.add_argument('local_port', type=int); item.add_argument('remote_port', type=int)
    item = actions.add_parser('stop'); item.add_argument('id')
    parser.set_defaults(handler=handle_forward)
    parser = command_parser(sub, 'watch', 'Manage event-driven rsync watchers without destination deletion')
    actions = parser.add_subparsers(dest='action', required=True)
    actions.add_parser('list')
    item = actions.add_parser('start'); item.add_argument('id'); item.add_argument('source'); item.add_argument('destination')
    item = actions.add_parser('stop'); item.add_argument('id')
    item = actions.add_parser('worker', help='Internal watcher process'); item.add_argument('source'); item.add_argument('destination')
    parser.set_defaults(handler=handle_watch)
    parser = command_parser(sub, 'tmux', 'Create developer, square or swarm tmux layouts')
    parser.add_argument('layout', choices=('dev', 'square', 'swarm')); parser.add_argument('--session', default='titan-dev')
    parser.add_argument('--cwd', default=os.getcwd()); parser.add_argument('--attach', action='store_true')
    parser.add_argument('--count', type=int, default=4); parser.add_argument('command', nargs='*')
    parser.set_defaults(handler=handle_tmux)
