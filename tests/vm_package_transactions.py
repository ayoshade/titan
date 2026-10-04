#!/usr/bin/env python3
"""Real package-family transactions confined to an owned Titan QEMU guest."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import pty
import select
import shlex
import subprocess
import tempfile
import time
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--manifest', required=True, type=Path)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args()
root = Path('/usr/share/titan')
if (Path.home() != Path('/home/tester') or os.getuid() == 0 or
        subprocess.run(['systemd-detect-virt', '--vm', '--quiet']).returncode or
        Path('/sys/class/dmi/id/sys_vendor').read_text().strip() != 'QEMU'):
    raise SystemExit('Refusing to run outside the disposable QEMU tester account')
args.output.mkdir(exist_ok=True)
log = (args.output / 'commands.log').open('w')
results = []
fixture = Path(tempfile.mkdtemp(prefix='titan-packages-', dir='/home/tester'))
package = 'titan-package-fixture-' + uuid.uuid4().hex[:12]
repository = Path('/var/lib') / package
env = {**os.environ, 'XDG_CONFIG_HOME': str(fixture / 'config'),
       'XDG_STATE_HOME': str(fixture / 'state')}
choices = {p: p.read_bytes() for p in (Path.home() / '.config/titan').glob('*.json')}


def run(*argv, code=0, input=None, environment=None, timeout=180):
    log.write('$ ' + shlex.join(map(str, argv)) + '\n'); log.flush()
    result = subprocess.run(list(map(str, argv)), text=True, capture_output=True,
                            input=input, env=environment or env, timeout=timeout)
    log.write(result.stdout + result.stderr); log.flush()
    if result.returncode != code:
        raise RuntimeError(f'{argv[0]} exited {result.returncode}, expected {code}: {result.stderr[-1500:]}')
    return result.stdout


def cli(*argv, **kwargs):
    return run(root / 'bin/titan', 'pkg', *argv, **kwargs)


def dialog(action):
    # Send each response after its prompt, like the maintenance terminal.
    argv = [str(root / 'scripts/titan-task'), '--dialog', action]
    log.write('$ ' + shlex.join(argv) + ' [PTY]\n'); log.flush()
    master, slave = pty.openpty()
    process = subprocess.Popen(argv, stdin=slave, stdout=slave, stderr=slave, env=env,
                               start_new_session=True)
    os.close(slave)
    output = b''
    prompts = [(b'Package names: ', (package + '\n').encode()),
               (b'[Y/n]', b'y\n'), (b'Press Enter to close', b'\n')]
    answered = 0
    deadline = time.monotonic() + 360
    try:
        while time.monotonic() < deadline:
            if select.select([master], [], [], 0.2)[0]:
                try: chunk = os.read(master, 65536)
                except OSError: break  # PTYs report EIO when the slave closes.
                if not chunk: break
                output += chunk
                if answered < len(prompts) and prompts[answered][0] in output:
                    os.write(master, prompts[answered][1])
                    answered += 1
            elif process.poll() is not None:
                break
        if process.poll() is None: process.wait(timeout=5)
        assert process.returncode == 0 and answered == len(prompts), (process.returncode, answered)
        return output.decode(errors='replace')
    finally:
        log.write(output.decode(errors='replace')); log.flush()
        os.close(master)
        if process.poll() is None:
            # Only this fixture's process group, never a guest-wide kill.
            import signal
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=10)


def menu_rows():
    # workflow's legacy startup creates state; keep it outside the plan fixture.
    menu_env = {**env, 'XDG_CONFIG_HOME': str(fixture / 'menu-config'),
                'XDG_STATE_HOME': str(fixture / 'menu-state'),
                'XDG_RUNTIME_DIR': str(fixture / 'menu-runtime')}
    return json.loads(run(root / 'bin/workflow', 'maintenance-list', 'install-packages', environment=menu_env))


def stage(name, check):
    try:
        check()
        results.append({'name': name, 'status': 'pass'})
        print('PASS ' + name, flush=True)
    except Exception as error:
        results.append({'name': name, 'status': 'fail', 'error': str(error)})
        print('FAIL ' + name + ': ' + str(error), flush=True)
    (args.output / 'results.json').write_text(json.dumps({'schema': 1, 'checks': results}, indent=2) + '\n')


def sources():
    for name, digest in json.loads(args.manifest.read_text()).items():
        assert hashlib.sha256((root / name).read_bytes()).hexdigest() == digest, name


def plans_and_menus():
    tools = fixture / 'native-bin'
    tools.mkdir()
    for name in ('bash', 'dirname', 'readlink', 'jq'):
        (tools / name).symlink_to('/usr/bin/' + name)
    native = {**env, 'PATH': str(tools)}
    catalog = json.loads(cli('list', environment=native))['bundles']
    for name, recipe in catalog.items():
        plan = json.loads(cli('bundle', name, environment=native))
        expected = ['sudo', 'pacman', '-Syu']
        if recipe['packages']: expected += ['--needed', '--', *recipe['packages']]
        assert plan['commands'][0] == expected
        assert plan['after_install'] == recipe.get('after_install', [])
        assert plan['repositories'] == recipe.get('repositories', [])
    assert json.loads(cli('add', '--plan', package, environment=native))['commands'] == [
        ['sudo', 'pacman', '-Syu', '--needed', '--', package]]
    cli('remove', '--plan', package, environment=native)
    cli('aur', '--plan', package, environment=native, code=1)
    cli('bundle', 'sharing', '--apply', environment=native, code=1)
    assert not (fixture / 'state').exists() and not (fixture / 'config').exists()
    rows = menu_rows()
    assert len(rows) == len(catalog)
    assert all(json.loads(row['value']) == ['pkg', 'bundle', row['label'], '--apply'] for row in rows)
    direct = json.loads(run('python3', root / 'lib/titan/desktop_cli.py', 'pkg', 'bundle', 'pdf'))
    assert direct == json.loads(cli('bundle', 'pdf'))


def refusals():
    before = run('pacman', '-Q')
    cli('add', '--root', code=2)
    cli('remove', '../etc', code=2)
    cli('bundle', 'titan-unknown-fixture', '--apply', code=1)
    repos = run('pacman-conf', '--repo-list').splitlines()
    assert 'multilib' not in repos, 'Fixture expects the unmodified guest repository policy'
    cli('bundle', 'gaming', '--apply', code=1)
    tools = fixture / 'guard-bin'
    tools.mkdir()
    for name in ('bash', 'dirname', 'readlink', 'jq', 'pacman', 'sudo'):
        (tools / name).symlink_to('/usr/bin/' + name)
    restricted = {**env, 'PATH': str(tools)}
    cli('aur', package, environment=restricted, code=1)
    cli('bundle', 'sharing', '--apply', environment=restricted, code=1)
    assert run('pacman', '-Q') == before, 'Refusal changed installed packages'


def prepare_repository():
    payload = fixture / 'payload'
    (payload / 'etc').mkdir(parents=True)
    (payload / 'etc' / (package + '.conf')).write_text('default\n')
    (payload / '.PKGINFO').write_text(
        f'pkgname = {package}\npkgver = 1-1\npkgdesc = disposable test fixture\n'
        'arch = any\nsize = 8\ndepend = bash\n' + f'backup = etc/{package}.conf\n')
    archive = fixture / f'{package}-1-1-any.pkg.tar.zst'
    run('bsdtar', '--zstd', '-cf', archive, '-C', payload, '.PKGINFO', 'etc')
    run('sudo', 'mkdir', '-m', '755', repository)
    run('sudo', 'cp', archive, repository)
    run('sudo', 'repo-add', repository / (package + '.db.tar.zst'), repository / archive.name)
    config = Path('/etc/pacman.conf')
    baseline = config.read_bytes()
    (fixture / 'pacman.conf.before').write_bytes(baseline)
    updated = baseline.decode() + f'\n[{package}]\nSigLevel = Optional TrustAll\nServer = file://{repository}\n'
    run('sudo', 'tee', config, input=updated)
    return baseline


def install_confirmation():
    cli('add', package, input='n\n', code=1, timeout=360)
    cli('missing', package)
    output = dialog('package-add')
    assert 'starting full system upgrade' in output.lower(), 'Install omitted full Arch upgrade'
    cli('present', package)
    assert package in cli('search', package)
    assert package in cli('info', package)
    assert package in cli('installed')
    # --needed repeats preserve installed files rather than reinstalling.
    config = Path('/etc') / (package + '.conf')
    run('sudo', 'tee', config, input='custom content retained\n')
    cli('add', package, input='y\n', timeout=360)
    assert config.read_text() == 'custom content retained\n'


def removal_confirmation():
    config = Path('/etc') / (package + '.conf')
    cli('remove', package, input='n\n', code=1)
    cli('present', package)
    assert config.read_text() == 'custom content retained\n'
    dialog('package-remove')
    cli('missing', package)
    cli('present', 'bash')
    assert Path(str(config) + '.pacsave').read_text() == 'custom content retained\n'
    cli('remove', package, code=1)  # Strict removal still reports an absent package.
    cli('drop', package)           # Idempotent removal remains distinct.


def bundle_and_preservation():
    # Use the exact command generated for the existing Install menu.
    rows = menu_rows()
    command = next(json.loads(row['value']) for row in rows if row['label'] == 'terminal-foot')
    output = run(root / 'scripts/titan-task', *command, input='y\n' * 10, timeout=360)
    assert 'starting full system upgrade' in output.lower()
    cli('present', 'foot')
    assert all(path.read_bytes() == data for path, data in choices.items())
    assert not (fixture / 'state').exists() and not (fixture / 'config').exists()


stage('installed package routes and recipe/menu helpers match checkout', sources)
if results[-1]['status'] != 'pass': raise SystemExit(1)
stage('native read-only plans and unchanged maintenance menu commands', plans_and_menus)
stage('invalid arguments, repository and missing-helper refusals leave packages intact', refusals)
baseline = None
try:
    baseline = prepare_repository()
    stage('real full-upgrade install honors cancellation, task dialog and --needed', install_confirmation)
    stage('real removal honors cancellation and retains modified config and dependencies', removal_confirmation)
    stage('real menu bundle performs full upgrade and preserves user choices', bundle_and_preservation)
finally:
    # Restore only this fixture's repository/configuration; never touch host state.
    if baseline is None and (fixture / 'pacman.conf.before').exists():
        baseline = (fixture / 'pacman.conf.before').read_bytes()
    if baseline is not None:
        run('sudo', 'tee', '/etc/pacman.conf', input=baseline.decode())
    if subprocess.run(['pacman', '-Q', package], capture_output=True).returncode == 0:
        run('sudo', 'pacman', '-R', '--noconfirm', '--', package)
    if repository.exists(): run('sudo', 'rm', '-r', '--', repository)
    run('sudo', 'rm', '-f', '--', '/var/lib/pacman/sync/' + package + '.db',
        '/var/lib/pacman/sync/' + package + '.db.sig')
raise SystemExit(any(item['status'] != 'pass' for item in results))
