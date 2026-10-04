"""Default applications and reproducible native, TUI and web launchers."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from urllib.parse import urlsplit

from ops import atomic, capture, command_parser, emit, identifier, locked, plain, read_json, require, run, write_json
from paths import CONFIG, HOME, ROOT

CHOICES = {
    'terminal': {'kitty': 'kitty', 'foot': 'foot', 'ghostty': 'ghostty', 'alacritty': 'alacritty'},
    'browser': {'firefox': 'firefox', 'chromium': 'chromium', 'brave': 'brave'},
    'editor': {'nvim': 'nvim', 'vim': 'vim', 'helix': 'helix', 'code': 'code', 'zed': 'zeditor', 'emacs': 'emacs'},
    'agent': {'codex': 'codex', 'claude': 'claude', 'opencode': 'opencode'},
}
DEFAULTS = {'terminal': 'kitty', 'browser': 'firefox', 'editor': 'nvim', 'agent': 'codex'}
GUI_EDITORS = {'code', 'zed', 'emacs'}
BROWSER_DESKTOP = {'firefox': 'firefox.desktop', 'chromium': 'chromium.desktop', 'brave': 'brave-browser.desktop'}
TERMINAL_DESKTOP = {'kitty': 'kitty.desktop', 'foot': 'foot.desktop', 'ghostty': 'com.mitchellh.ghostty.desktop', 'alacritty': 'Alacritty.desktop'}
DATA = Path(os.environ.get('XDG_DATA_HOME', HOME / '.local/share'))
WEBAPPS = CONFIG / 'webapps'


def default(kind):
    choice = read_json(CONFIG / 'defaults.json').get(kind, DEFAULTS[kind])
    if not isinstance(choice, str) or choice not in CHOICES[kind]:
        raise ValueError(f'Invalid {kind} preference; run titan defaults reset {kind}')
    return choice


def terminal(command=(), cwd=None, app_id=None):
    choice = default('terminal')
    argv = [CHOICES['terminal'][choice]]
    if choice == 'kitty':
        if cwd: argv += ['--directory', str(cwd)]
        if app_id: argv += ['--class', app_id]
    elif choice == 'foot':
        if cwd: argv += ['--working-directory=' + str(cwd)]
        if app_id: argv += ['--app-id=' + app_id]
    elif choice == 'ghostty':
        if cwd: argv += ['--working-directory=' + str(cwd)]
        if app_id: argv += ['--class=' + app_id]
    else:
        if cwd: argv += ['--working-directory', str(cwd)]
        if app_id: argv += ['--class', app_id]
    if command:
        argv += ['-e', *map(str, command)]
    return argv


def browser(urls=(), private=False, webapp=False):
    choice = default('browser')
    binary = CHOICES['browser'][choice]
    if choice == 'firefox':
        return [binary, '--private-window' if private else '--new-window', *urls]
    if webapp and len(urls) == 1:
        return [binary, '--app=' + urls[0]]
    return [binary, '--incognito' if private else '--new-window', *urls]


def editor(files=(), cwd=None):
    choice = default('editor')
    cmd = [CHOICES['editor'][choice], *map(str, files)]
    return cmd if choice in GUI_EDITORS else terminal(cmd, cwd)


def spawn(argv, cwd=None):
    require(argv[0])
    return subprocess.Popen(list(map(str, argv)), cwd=cwd, start_new_session=True,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def focused_cwd():
    """Prefer the foreground descendant of a terminal, without reading cmdlines."""
    try:
        window = json.loads(capture('hyprctl', '-j', 'activewindow'))
        pid = int(window['pid'])
        for _ in range(8):
            children = Path(f'/proc/{pid}/task/{pid}/children').read_text().split()
            if not children: break
            pid = int(children[-1])
        cwd = Path(f'/proc/{pid}/cwd').resolve(strict=True)
        if cwd.is_dir(): return cwd
    except (OSError, KeyError, ValueError, subprocess.SubprocessError):
        pass
    return HOME


def focus(app_id):
    """Match exact application class, then use the installed Hyprland Lua API."""
    if not os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
        return False
    windows = json.loads(capture('hyprctl', '-j', 'clients'))
    window = next((w for w in windows if w.get('class') == app_id), None)
    if window and re.fullmatch(r'0x[0-9a-fA-F]+', window.get('address', '')):
        target = json.dumps('address:' + window['address'])
        run('hyprctl', 'dispatch', f'hl.dsp.window.focus({{window={target}}})', stdout=subprocess.DEVNULL)
        return True
    return False


def http_url(url):
    plain(url)
    if any(c.isspace() for c in url):
        raise ValueError('URL whitespace must be percent-encoded')
    if not re.match(r'^[A-Za-z][A-Za-z0-9+.-]*:', url):
        url = 'https://' + url
    parts = urlsplit(url)
    if parts.scheme.lower() not in ('http', 'https') or not parts.hostname or parts.username or parts.password:
        raise ValueError('Use an HTTP(S) URL without embedded credentials')
    return url


def desktop_string(value):
    return value.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t')


def desktop_arg(value):
    # Exec has its own escaping, followed by the desktop string escaping layer.
    value = value.replace('%', '%%')
    for character in ('\\', '"', '`', '$'):
        value = value.replace(character, '\\' + character)
    return '"' + value + '"'


def webapp_path(app_id):
    return DATA / 'applications' / ('titan-webapp-' + identifier(app_id) + '.desktop')


def install_webapp(name, url, icon='web-browser'):
    plain(name)
    if len(name) > 100 or '/' in name:
        raise ValueError('Use an app name of at most 100 characters without slashes')
    url = http_url(url)
    if not re.fullmatch(r'[A-Za-z0-9_.-]+', icon):
        raise ValueError('Use an installed icon name (e.g. web-browser)')
    app_id = re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')[:60]
    if not app_id: app_id = hashlib.sha256(name.encode()).hexdigest()[:16]
    with locked('webapps'):
        file = WEBAPPS / (app_id + '.json')
        launcher = webapp_path(app_id)
        if file.exists() or launcher.exists() or launcher.is_symlink():
            raise ValueError(f'{app_id} already exists; remove it before reinstalling')
        # An absolute Titan entrypoint also works before bootstrap adds titan to PATH.
        argv = [str(ROOT / 'bin/titan'), 'webapp', 'launch', app_id]
        text = '\n'.join(['[Desktop Entry]', 'Type=Application', 'Version=1.0',
                          'Name=' + desktop_string(name), 'Icon=' + icon,
                          'Exec=' + desktop_string(' '.join(desktop_arg(x) for x in argv)),
                          'Terminal=false', 'Categories=Network;', 'X-Titan-WebApp=' + app_id, ''])
        write_json(file, {'schema': 1, 'id': app_id, 'name': name, 'url': url, 'icon': icon})
        try:
            atomic(launcher, text)
        except Exception:
            file.unlink()
            raise
    if shutil.which('update-desktop-database'):
        run('update-desktop-database', DATA / 'applications', stdout=subprocess.DEVNULL)
    print(app_id)


def handle_defaults(args):
    if args.action == 'list':
        emit({'schema': 1, 'defaults': {k: default(k) for k in DEFAULTS}, 'choices': CHOICES})
        return
    if args.action == 'get':
        print(default(args.kind)); return
    with locked('defaults'):
        values = read_json(CONFIG / 'defaults.json')
        if args.action == 'reset':
            require(CHOICES[args.kind][DEFAULTS[args.kind]])
            if args.kind == 'browser':
                run('xdg-settings', 'set', 'default-web-browser', BROWSER_DESKTOP[DEFAULTS[args.kind]])
            elif args.kind == 'terminal':
                atomic(CONFIG.parent / 'xdg-terminals.list', TERMINAL_DESKTOP[DEFAULTS[args.kind]] + '\n')
            values.pop(args.kind, None)
        else:
            if args.value not in CHOICES[args.kind]:
                raise ValueError('Choices: ' + ', '.join(CHOICES[args.kind]))
            require(CHOICES[args.kind][args.value])
            if args.kind == 'browser':
                require('xdg-settings')
                run('xdg-settings', 'set', 'default-web-browser', BROWSER_DESKTOP[args.value])
            elif args.kind == 'terminal':
                atomic(CONFIG.parent / 'xdg-terminals.list', TERMINAL_DESKTOP[args.value] + '\n')
            values[args.kind] = args.value
        write_json(CONFIG / 'defaults.json', values)


def handle_webapp(args):
    if args.action == 'install':
        install_webapp(args.name, args.url, args.icon); return
    if args.action == 'list':
        emit([read_json(file) for file in sorted(WEBAPPS.glob('*.json'))]); return
    file = WEBAPPS / (identifier(args.id) + '.json')
    data = read_json(file)
    if not data: raise ValueError('Unknown web app: ' + args.id)
    if args.action == 'launch':
        app_id = 'titan-webapp-' + args.id
        if not focus(app_id):
            argv = browser([http_url(data['url'])], webapp=True)
            if default('browser') != 'firefox': argv.insert(1, '--class=' + app_id)
            spawn(argv)
        return
    with locked('webapps'):
        launcher = webapp_path(args.id)
        if launcher.is_symlink(): raise ValueError('Refusing a symlinked launcher')
        if launcher.exists() and ('X-Titan-WebApp=' + args.id + '\n') not in launcher.read_text():
            raise ValueError('Launcher ownership marker changed; preserving it')
        launcher.unlink(missing_ok=True)
        file.unlink()


def handle_launch(args):
    cwd = Path(args.cwd).expanduser().resolve(strict=True) if args.cwd else focused_cwd()
    if not cwd.is_dir(): raise ValueError('Working directory must be a directory')
    if args.focus and focus(plain(args.focus)): return
    values = args.arguments
    if values[:1] == ['--']: values = values[1:]
    if args.kind == 'terminal': argv = terminal(values, cwd)
    elif args.kind == 'editor': argv = editor(values, cwd)
    elif args.kind in ('browser', 'web'):
        argv = browser([http_url(v) for v in values], private=args.private, webapp=args.kind == 'web')
    elif args.kind == 'files': argv = ['thunar', str(cwd), *values]
    elif args.kind == 'agent':
        binary = CHOICES['agent'][default('agent')]
        require(binary); argv = terminal([binary, *values], cwd)
    elif args.kind == 'tui':
        if not values: raise ValueError('Supply a TUI executable')
        require(values[0]); argv = terminal(values, cwd)
    else:
        if not values: raise ValueError('Supply an executable')
        argv = values
    spawn(argv, cwd)


def register(sub):
    parser = command_parser(sub, 'defaults', 'Select the default terminal, browser, editor or agent')
    actions = parser.add_subparsers(dest='action', required=True)
    actions.add_parser('list')
    for action in ('get', 'set', 'reset'):
        item = actions.add_parser(action)
        item.add_argument('kind', choices=CHOICES)
        if action == 'set': item.add_argument('value')
    parser.set_defaults(handler=handle_defaults)
    parser = command_parser(sub, 'launch', 'Launch applications with selected defaults and focused working directory')
    parser.add_argument('--cwd')
    parser.add_argument('--focus', help='Focus an existing window with this exact class')
    parser.add_argument('--private', action='store_true')
    parser.add_argument('kind', choices=('terminal', 'editor', 'browser', 'web', 'files', 'tui', 'agent', 'app'))
    parser.add_argument('arguments', nargs='*')
    parser.set_defaults(handler=handle_launch)
    parser = command_parser(sub, 'webapp', 'Install and manage user web-app launchers')
    actions = parser.add_subparsers(dest='action', required=True)
    item = actions.add_parser('install')
    item.add_argument('name'); item.add_argument('url'); item.add_argument('--icon', default='web-browser')
    actions.add_parser('list')
    for action in ('launch', 'remove'):
        item = actions.add_parser(action); item.add_argument('id')
    parser.set_defaults(handler=handle_webapp)
