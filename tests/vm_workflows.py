#!/usr/bin/env python3
"""Acceptance fixtures for disposable Titan QEMU guests, never the host.

Not collected by unittest. tools/vm-workflows invokes this after graphical
login, or on a headless full-package VM with --only development. Installs packages and changes services only in the disposable guest.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import signal
import socket
import subprocess
import sys
import time
import traceback
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--graphical-user')
parser.add_argument('--manifest', required=True, type=Path)
parser.add_argument('--output', required=True, type=Path)
parser.add_argument('--only', choices=('apps', 'preservation', 'services', 'development'))
args = parser.parse_args()
root = Path('/usr/share/titan')
if (Path.home() != Path('/home/tester') or os.getuid() == 0
        or subprocess.run(['systemd-detect-virt', '--vm', '--quiet']).returncode
        or Path('/sys/class/dmi/id/sys_vendor').read_text().strip() != 'QEMU'
        or not (root / 'bin/titan').is_file()):
    sys.exit('Refusing to run outside the disposable Titan QEMU tester account')
if args.only != 'development' and (not args.graphical_user or
        not args.graphical_user.startswith('titanuser') or not args.graphical_user[9:].isdigit()):
    sys.exit('Select the generated graphical acceptance account')
args.output.mkdir(exist_ok=True)
log = (args.output / 'commands.log').open('w')
results = []


def command(*argv, timeout=120, success=True, input=None):
    log.write('$ ' + shlex.join(map(str, argv)) + '\n'); log.flush()
    with subprocess.Popen(list(map(str, argv)), cwd='/', text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, stdin=subprocess.PIPE, start_new_session=True) as process:
        try:
            stdout, stderr = process.communicate(input=input, timeout=timeout)
        except subprocess.TimeoutExpired:
            # Titan operations spawn mise/build jobs; bound the entire fixture group.
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.communicate(timeout=3)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate()
            raise
        result = subprocess.CompletedProcess(list(map(str, argv)), process.returncode, stdout, stderr)
    log.write(result.stdout + result.stderr + f'\n[exit {result.returncode}]\n'); log.flush()
    if success and result.returncode:
        raise RuntimeError(f'{shlex.join(map(str, argv))}: exit {result.returncode}\n{result.stdout[-1500:]}{result.stderr[-1500:]}')
    return result


def titan(*argv, **kwargs):
    return command('titan', *argv, **kwargs)


def wait(check, seconds=90):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        result = check()
        if result:
            return result
        time.sleep(1)
    raise RuntimeError('Timed out waiting for guest behavior')


def stage(name, action):
    print('CHECK ' + name, flush=True)
    started = time.monotonic()
    try:
        action()
        result = {'name': name, 'status': 'pass'}
        print('PASS  ' + name, flush=True)
    except Exception as error:
        result = {'name': name, 'status': 'fail', 'error': str(error)}
        log.write(traceback.format_exc()); log.flush()
        print('FAIL  ' + name + ': ' + str(error), flush=True)
    result['seconds'] = round(time.monotonic() - started, 2)
    results.append(result)
    (args.output / 'results.json').write_text(json.dumps({'schema': 1, 'checks': results}, indent=2) + '\n')


def source_check():
    for relative, digest in json.loads(args.manifest.read_text()).items():
        if hashlib.sha256((root / relative).read_bytes()).hexdigest() != digest:
            raise RuntimeError('Installed source differs from checkout: ' + relative)


def defaults_preservation():
    file = Path.home() / '.config/tmux/tmux.conf'
    original = file.read_bytes()
    custom = original + b'\n# workflow acceptance custom value\nset -g history-limit 12345\n'
    file.write_bytes(custom)
    values = [Path.home() / '.config/titan/preferences.json', Path.home() / '.config/titan/settings.json']
    baseline = {p: p.read_bytes() for p in values}
    try:
        # Reinstall actual packages before exercising setup/migration preservation.
        package = next((Path.home() / 'titan-vm-packages').glob('titan-[0-9]*-any.pkg.tar.zst'))
        command('sudo', 'pacman', '-U', '--noconfirm', package, timeout=180)
        # pacman temporarily removes the watched Lua file during replacement.
        # Like an update run from the desktop, reload after the transaction ends.
        prefix = graphical_prefix()
        command(*prefix, 'hyprctl', 'reload')
        assert not command(*prefix, 'hyprctl', 'configerrors').stdout.strip()
        titan('setup', timeout=120)
        titan('migrate')
        assert file.read_bytes() == custom, 'Package/setup replaced user tmux config'
        assert all(p.read_bytes() == data for p, data in baseline.items()), 'Package/setup changed preferences'
        reset = json.loads(titan('config', 'reset', 'tmux').stdout)
        assert file.read_bytes() == original
        titan('config', 'restore', reset['backup'])
        assert file.read_bytes() == custom, 'Config restore lost user content'
        assert 'pending' not in titan('migrate', '--status').stdout
    finally:
        file.write_bytes(original)


def package_guards():
    baseline = command('pacman', '-Q').stdout
    assert command('sh', '-c', 'command -v paru || command -v yay', success=False).returncode != 0
    for argv in [('pkg', 'aur', '--plan', 'localsend-bin'), ('pkg', 'bundle', 'sharing', '--apply'),
                 ('pkg', 'bundle', 'gaming', '--apply')]:
        result = titan(*argv, success=False)
        assert result.returncode == 1, result.stdout + result.stderr
    assert command('pacman', '-Q').stdout == baseline, 'Refusal caused a partial transaction'


def runtime_node():
    titan('dev', 'install', 'node', timeout=600)
    result = command('mise', 'exec', 'node@lts', '--', 'node', '-e', 'console.log(6*7)')
    assert result.stdout.strip() == '42'
    assert (Path.home() / '.local/share/mise/shims/node').exists()
    command('bash', '-ic', 'node --version')


def runtime_laravel():
    titan('dev', 'install', 'laravel', timeout=1500, input='y\n' * 20)
    command('mise', 'exec', 'php', 'http:composer', '--', 'php', '--version')
    command('mise', 'exec', 'php', 'http:composer', '--', 'composer', '--version')
    bindir = command('mise', 'exec', 'php', 'http:composer', '--', 'composer',
                     'global', 'config', 'bin-dir', '--absolute').stdout.strip()
    executable = Path(bindir) / 'laravel'
    command('mise', 'exec', 'php', '--', executable, '--version')


def developer_contracts():
    # Use real packaged routes with a PATH containing no Python, mise, pacman,
    # sudo or Docker. Inspection and config generation must stand alone.
    with tempfile.TemporaryDirectory(prefix='titan-dev native ', dir=Path.home()) as directory:
        fixture = Path(directory)
        tools = fixture / 'bin'
        tools.mkdir()
        for name in ('bash','dirname','readlink','jq','cat','flock','mkdir','mktemp','ln','rm'):
            (tools / name).symlink_to('/usr/bin/' + name)
        prefix = ['env', 'PATH=' + str(tools), 'XDG_CONFIG_HOME=' + str(fixture / 'config'),
                  'XDG_STATE_HOME=' + str(fixture / 'state')]
        def native(*argv, **kwargs):
            return command(*prefix, root / 'bin/titan', 'dev', *argv, **kwargs)
        recipes = json.loads(native('list').stdout)['environments']
        for name, recipe in recipes.items():
            plan = json.loads(native('plan', name).stdout)
            expected = []
            if recipe.get('packages'): expected.append(['sudo','pacman','-Syu','--needed','--',*recipe['packages']])
            if recipe.get('tools'): expected.append(['mise','use','-g',*recipe['tools']])
            expected.extend(recipe.get('commands', []))
            assert plan == {'schema':1,'commands':expected}
        assert json.loads(native('db','list').stdout)['configured'] == []
        for argv in [('install','node'), ('install','unknown'), ('db','create','unknown'),
                     ('db','create','redis','--port','80'), ('db','create','../escape'),
                     ('db','start','redis')]:
            assert native(*argv,success=False).returncode == 1
        direct = command(*prefix, '/usr/bin/python3', root / 'lib/titan/desktop_cli.py', 'dev','plan','laravel')
        assert json.loads(direct.stdout) == json.loads(native('plan','laravel').stdout)
        assert not (fixture / 'config').exists() and not (fixture / 'state').exists()
        for name in ('postgres','mysql','mariadb','redis','mongodb'):
            native('db','create',name)
            file = fixture / 'config/titan/development/databases' / (name + '.json')
            before = file.read_bytes()
            assert file.stat().st_mode & 0o777 == 0o600
            assert native('db','create',name,success=False).returncode == 1
            assert file.read_bytes() == before
        assert json.loads(native('db','list').stdout)['configured'] == sorted(('postgres','mysql','mariadb','redis','mongodb'))
    # The existing shell maintenance menu continues to generate public routes.
    sys.path.insert(0, str(root / 'lib/titan'))
    from maintenance_menu import items
    menu = items('install-dev')
    assert {row['label'] for row in menu} == set(recipes)
    assert all(json.loads(row['value']) == ['dev','install',row['label']] for row in menu)


def developer_databases():
    units = ('docker.service','docker.socket')
    baseline = {unit: (command('systemctl','is-enabled',unit,success=False).stdout.strip(),
                       command('systemctl','is-active',unit,success=False).stdout.strip()) for unit in units}
    try:
        stage('Docker setup for developer database acceptance', lambda: titan('service','setup','docker',timeout=600,input='y\n'*20))
        if results[-1]['status'] == 'pass':
            for index, name in enumerate(('postgres','mysql','mariadb','redis','mongodb')):
                stage(name + ' custom config, loopback binding and data survive stop/remove/recreate',
                      lambda name=name, index=index: database_check(name, 15000 + index))
    finally:
        for unit, (enabled, active) in baseline.items():
            command('sudo','systemctl','enable' if enabled == 'enabled' else 'disable',unit)
            command('sudo','systemctl','start' if active == 'active' else 'stop',unit)
        for unit, (enabled, active) in baseline.items():
            assert command('systemctl','is-enabled',unit,success=False).stdout.strip() == enabled
            assert command('systemctl','is-active',unit,success=False).stdout.strip() == active


def service_check(name):
    plan = json.loads(titan('service', 'plan', name).stdout)
    assert plan['schema'] == 1 and plan['commands'][0][:5] == ['sudo', 'pacman', '-Syu', '--needed', '--']
    listed = json.loads(titan('service', 'list').stdout)
    assert next(item for item in listed['services'] if item['id'] == name)['bundle'] == name
    titan('service', 'setup', name, timeout=600, input='y\n' * 20)
    service = {'docker': 'docker.service', 'printing': 'cups.service', 'tailscale': 'tailscaled.service'}[name]
    command('systemctl', 'is-active', '--quiet', service)
    command('systemctl', 'is-enabled', '--quiet', service)
    titan('service', 'status', name)
    titan('service', 'disable', name)
    assert command('systemctl', 'is-active', '--quiet', service, success=False).returncode != 0
    assert command('systemctl', 'is-enabled', '--quiet', service, success=False).returncode != 0
    activation = {'docker': ['docker.socket'], 'printing': ['cups.socket', 'cups.path'], 'tailscale': []}[name]
    for unit in activation:
        assert command('systemctl', 'is-active', '--quiet', unit, success=False).returncode != 0, unit + ' can reactivate the service'
        assert command('systemctl', 'is-enabled', '--quiet', unit, success=False).returncode != 0, unit + ' remains enabled'
    if name == 'docker':
        assert command('sudo', 'docker', 'info', timeout=15, success=False).returncode != 0, 'Docker reactivated after disable'
        assert 'docker' not in command('id', '-nG').stdout.split(), 'User added to privileged Docker group'
    titan('service', 'enable', name)
    command('systemctl', 'is-active', '--quiet', service)
    if name != 'docker' or args.only == 'services':
        titan('service', 'disable', name)


def database_check(name, port):
    titan('dev', 'db', 'create', name, '--port', str(port))
    container = 'titan-dev-' + name
    volume = container + '_data'
    file = Path.home() / '.config/titan/development/databases' / (name + '.json')
    # Keep an actual user edit through duplicate creation and every lifecycle.
    data = json.loads(file.read_text())
    data['services'][name]['labels'] = {'titan.acceptance': 'custom preserved'}
    custom = json.dumps(data, indent=2) + '\n'
    file.write_text(custom)
    assert titan('dev','db','create',name,success=False).returncode == 1
    assert file.read_text() == custom
    def execute(*argv, **kwargs):
        return command('sudo', 'docker', 'exec', container, *argv, **kwargs)
    def reachable():
        try:
            with socket.create_connection(('127.0.0.1', port), timeout=1):
                return True
        except OSError:
            return False
    if name == 'postgres':
        readiness = ['pg_isready', '-h', '127.0.0.1', '-U', 'titan', '-d', 'titan']
        write = ['psql', '-h', '127.0.0.1', '-U', 'titan', '-d', 'titan', '-c', "DROP TABLE IF EXISTS acceptance; CREATE TABLE acceptance(value text); INSERT INTO acceptance VALUES ('persisted');"]
        read = ['psql', '-h', '127.0.0.1', '-U', 'titan', '-d', 'titan', '-Atc', 'SELECT value FROM acceptance;']
    elif name in ('mysql', 'mariadb'):
        client = 'mysql' if name == 'mysql' else 'mariadb'
        readiness = [client, '-h127.0.0.1', '-uroot', 'titan', '-e', 'SELECT 1;']
        write = [client, '-h127.0.0.1', '-uroot', 'titan', '-e', "DROP TABLE IF EXISTS acceptance; CREATE TABLE acceptance(value text); INSERT INTO acceptance VALUES ('persisted');"]
        read = [client, '-h127.0.0.1', '-uroot', '-N', 'titan', '-e', 'SELECT value FROM acceptance;']
    elif name == 'redis':
        readiness = ['redis-cli', 'ping']
        write = ['redis-cli', 'set', 'acceptance', 'persisted']
        read = ['redis-cli', '--raw', 'get', 'acceptance']
    else:
        readiness = ['mongosh', '--quiet', '--eval', 'db.runCommand({ping:1})']
        write = ['mongosh', '--quiet', '--eval', 'db.getSiblingDB("titan").acceptance.replaceOne({_id:"fixture"},{value:"persisted"},{upsert:true})']
        read = ['mongosh', '--quiet', '--eval', 'db.getSiblingDB("titan").acceptance.findOne().value']
    try:
        titan('dev', 'db', 'start', name, timeout=600)
        wait(lambda: reachable() and execute(*readiness, success=False).returncode == 0, seconds=180)
        bindings = json.loads(command('sudo', 'docker', 'inspect', container).stdout)[0]['NetworkSettings']['Ports']
        assert bindings and all(binding['HostIp'] == '127.0.0.1' for items in bindings.values() if items for binding in items)
        execute(*write)
        assert execute(*read).stdout.strip() == 'persisted'
        titan('dev', 'db', 'status', name)
        titan('dev', 'db', 'stop', name)
        titan('dev', 'db', 'start', name)
        wait(lambda: execute(*read, success=False).stdout.strip() == 'persisted')
        assert file.read_text() == custom, 'Lifecycle replaced the editable Compose configuration'
        titan('dev', 'db', 'remove', name)
        command('sudo', 'docker', 'volume', 'inspect', volume)
        titan('dev', 'db', 'start', name)
        wait(lambda: execute(*read, success=False).stdout.strip() == 'persisted')
    finally:
        titan('dev', 'db', 'logs', name, success=False)
        titan('dev', 'db', 'remove', name, success=False)
        # Remove only the configuration created by this fixture; retain its volume.
        assert file.read_text() == custom
        file.unlink(missing_ok=True)


def graphical_prefix():
    uid = command('id', '-u', args.graphical_user).stdout.strip()
    runtime = '/run/user/' + uid
    display = command('sudo', '-u', args.graphical_user, 'find', runtime, '-maxdepth', '1', '-type', 's', '-name', 'wayland-*').stdout.splitlines()[0]
    prefix = ['sudo', '-H', '-u', args.graphical_user, 'env', 'XDG_RUNTIME_DIR=' + runtime,
              'WAYLAND_DISPLAY=' + Path(display).name, 'TITAN_ROOT=/usr/share/titan']
    instances = json.loads(command(*prefix, 'hyprctl', 'instances', '-j').stdout)
    return prefix + ['HYPRLAND_INSTANCE_SIGNATURE=' + instances[0]['instance']]


def optional_apps():
    for bundle in ('terminal-foot', 'terminal-ghostty', 'terminal-alacritty', 'editor-helix'):
        titan('pkg', 'bundle', bundle, '--apply', input='y\n' * 20, timeout=600)
    prefix = graphical_prefix()
    baseline = command(*prefix, 'titan', 'defaults', 'get', 'terminal').stdout.strip()
    editor_before = command(*prefix, 'titan', 'defaults', 'get', 'editor').stdout.strip()
    panel_before = json.loads(command(*prefix, 'titan-shell', 'status').stdout).get('panel', '')
    directory = '/home/' + args.graphical_user
    marker = Path(directory) / 'terminal-acceptance.json'
    try:
        command(*prefix, 'titan-shell', 'close')
        command(*prefix, 'foot', '--check-config')
        command(*prefix, 'ghostty', '+validate-config')
        for terminal in ('foot', 'ghostty', 'alacritty'):
            command(*prefix, 'titan', 'defaults', 'set', 'terminal', terminal)
            command('sudo', '-u', args.graphical_user, 'rm', '-f', marker)
            code = (f'print("Titan {terminal} acceptance",flush=True);'
                    'import json,os,time;from pathlib import Path;'
                    f'Path({str(marker)!r}).write_text(json.dumps({{"cwd":os.getcwd()}}));time.sleep(8)')
            command(*prefix, 'titan', 'launch', '--cwd', directory, 'terminal', '--', 'python3', '-c', code)
            wait(lambda: command('sudo', '-u', args.graphical_user, 'test', '-s', marker, success=False).returncode == 0, seconds=20)
            assert json.loads(command('sudo', '-u', args.graphical_user, 'cat', marker).stdout)['cwd'] == directory
            clients = json.loads(command(*prefix, 'hyprctl', '-j', 'clients').stdout)
            assert any(terminal in item.get('class', '').lower() for item in clients), f'{terminal} did not map a window'
            time.sleep(1)  # allow the compositor to present the terminal's text
            screenshot = Path(directory) / ('acceptance-' + terminal + '.png')
            command(*prefix, 'grim', screenshot)
            command('sudo', 'install', '-o', 'tester', '-g', 'tester', '-m', '644', screenshot,
                    args.output / (terminal + '.png'))
            command('sudo', '-u', args.graphical_user, 'rm', '-f', screenshot)
            wait(lambda: not any(terminal in item.get('class', '').lower()
                                for item in json.loads(command(*prefix, 'hyprctl', '-j', 'clients').stdout)), seconds=20)
        command(*prefix, 'titan', 'defaults', 'set', 'editor', 'helix')
        command(*prefix, 'helix', '--health')
        loaded = command(*prefix, 'nvim', '--headless', '+qa')
        assert 'Error' not in loaded.stderr, loaded.stderr
    finally:
        command(*prefix, 'titan', 'defaults', 'set', 'terminal', baseline, success=False)
        command(*prefix, 'titan', 'defaults', 'set', 'editor', editor_before, success=False)
        if panel_before:
            command(*prefix, 'titan-shell', 'ipc', panel_before, success=False)
        command('sudo', '-u', args.graphical_user, 'rm', '-f', marker, success=False)


stage('installed workflow sources match the checkout', source_check)
if results[-1]['status'] != 'pass':
    sys.exit(1)
if args.only == 'preservation':
    stage('package reinstall, setup, migrations and config restore preserve user choices', defaults_preservation)
elif args.only == 'services':
    for name in ('docker', 'printing', 'tailscale'):
        stage(name + ' service plan/list/setup/status/disable/enable', lambda name=name: service_check(name))
elif args.only == 'development':
    choices = {p: p.read_bytes() for p in (Path.home() / '.config/titan').glob('*.json')}
    stage('developer plans, native routes, direct compatibility, private config and menu contracts', developer_contracts)
    stage('Node LTS installs through mise and executes in interactive Bash', runtime_node)
    stage('PHP, Composer and Laravel installer execute after the framework recipe', runtime_laravel)
    stage('developer database acceptance restores Docker service state', developer_databases)
    def choices_preserved():
        assert all(p.read_bytes() == data for p, data in choices.items()), 'Developer operation changed user choices'
    stage('developer operations preserve normal user choice JSON', choices_preserved)
elif not args.only:
    stage('package reinstall, setup, migrations and config restore preserve user choices', defaults_preservation)
    stage('AUR helper and multilib refusals precede any package mutation', package_guards)
    stage('Node LTS installs through mise and executes in interactive Bash', runtime_node)
    stage('PHP, Composer and Laravel installer execute after the framework recipe', runtime_laravel)
    for name in ('docker', 'printing', 'tailscale'):
        stage(name + ' service setup/status/disable', lambda name=name: service_check(name))
    if any(item['name'].startswith('docker ') and item['status'] == 'pass' for item in results):
        for index, name in enumerate(('postgres', 'mysql', 'mariadb', 'redis', 'mongodb')):
            stage(name + ' loopback binding and data survive stop/remove/recreate',
                  lambda name=name, index=index: database_check(name, 15000 + index))
        titan('service', 'disable', 'docker', success=False)
if args.only in (None, 'apps'):
    stage('optional terminals map windows, execute commands in cwd, and editor configs load', optional_apps)
stage('package doctor after workflow operations', lambda: titan('doctor'))
log.close()
sys.exit(int(any(item['status'] != 'pass' for item in results)))
