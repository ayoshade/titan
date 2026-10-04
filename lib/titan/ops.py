"""Shared primitives for Titan's modular user operations."""
from __future__ import annotations

import contextlib
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from paths import CONFIG, ROOT, STATE


def run(*argv, **kwargs):
    return subprocess.run([str(arg) for arg in argv], check=True, **kwargs)


def capture(*argv):
    return run(*argv, capture_output=True, text=True).stdout.strip()


def require(binary):
    if not shutil.which(binary):
        raise ValueError(f'{binary} is not installed; see titan pkg list')


def identifier(value):
    if not isinstance(value, str) or not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_.-]{0,79}', value):
        raise ValueError('Use a name containing letters, numbers, dots, underscores or hyphens')
    return value


def plain(value):
    if not isinstance(value, str) or not value or any(ord(c) < 32 or ord(c) == 127 for c in value):
        raise ValueError('Empty values and control characters are not allowed')
    return value


def read_json(path, default=None):
    fallback = {} if default is None else default
    try:
        value = json.loads(Path(path).read_text())
        if not isinstance(value, type(fallback)):
            raise ValueError(f'Unexpected JSON type in {path}')
        return value
    except FileNotFoundError:
        return fallback


def atomic(path, content):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, name = tempfile.mkstemp(prefix='.' + path.name, dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(content)
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def write_json(path, value):
    atomic(path, json.dumps(value, indent=2, ensure_ascii=False) + '\n')


def emit(value):
    print(json.dumps(value, indent=2, ensure_ascii=False))


@contextlib.contextmanager
def locked(name):
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (STATE / (identifier(name) + '.lock')).open('a') as stream:
        fcntl.flock(stream, fcntl.LOCK_EX)
        yield


def command_parser(sub, name, description):
    return sub.add_parser(name, description=description, help=description)


def hook(name, *args, strict=False):
    """User hooks are argv programs, bounded and isolated from the operation."""
    import sys
    identifier(name)
    base = CONFIG / 'hooks'
    files = [base / name]
    folder = base / (name + '.d')
    if folder.is_dir():
        files.extend(sorted(folder.iterdir()))
    failed = []
    for file in files:
        if not file.is_file() or file.name.endswith('.sample'):
            continue
        try:
            run('bash', file, *args, timeout=30, stdout=sys.stderr, stderr=sys.stderr)
        except (OSError, subprocess.SubprocessError) as error:
            failed.append(file.name)
            print(f'titan: hook {file.name} failed: {error}', file=sys.stderr)
    if failed and strict:
        raise ValueError('Failed hooks: ' + ', '.join(failed))


def register_hooks(sub):
    parser = command_parser(sub, 'hook', 'Run user hooks from ~/.config/titan/hooks')
    parser.add_argument('name')
    parser.add_argument('arguments', nargs='*')
    parser.set_defaults(handler=lambda args: hook(args.name, *args.arguments, strict=True))
