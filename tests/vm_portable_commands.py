#!/usr/bin/env python3
"""Real package/cache fixtures, confined to a disposable Titan QEMU tester."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--manifest', required=True, type=Path)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args()
root = Path('/usr/share/titan')
if (Path.home() != Path('/home/tester') or os.getuid() == 0 or
        subprocess.run(['systemd-detect-virt', '--vm', '--quiet']).returncode or
        Path('/sys/class/dmi/id/sys_vendor').read_text().strip() != 'QEMU' or
        not (root / 'bin/titan').is_file()):
    raise SystemExit('Refusing to run outside the disposable Titan QEMU tester account')
args.output.mkdir(exist_ok=True)
log = (args.output / 'commands.log').open('w')
results = []


def run(*argv, code=0, input=None, env=None, cwd=None, timeout=120):
    log.write('$ ' + shlex.join(map(str, argv)) + '\n'); log.flush()
    result = subprocess.run(list(map(str, argv)), text=True, capture_output=True,
                            input=input, env=env, cwd=cwd, timeout=timeout)
    log.write(result.stdout + result.stderr); log.flush()
    if result.returncode != code:
        raise RuntimeError(f'{argv[0]} exited {result.returncode}, expected {code}: {result.stderr[-1000:]}')
    return result.stdout


def cli(*argv, **kwargs):
    return run(root / 'bin/titan', *argv, **kwargs)


def stage(name, check):
    try:
        check()
        results.append({'name': name, 'status': 'pass'})
        print('PASS ' + name, flush=True)
    except Exception as error:
        results.append({'name': name, 'status': 'fail', 'error': str(error)})
        print('FAIL ' + name + ': ' + str(error), flush=True)
    (args.output / 'results.json').write_text(json.dumps({'schema': 1, 'checks': results}, indent=2) + '\n')


def verify_sources():
    for name, digest in json.loads(args.manifest.read_text()).items():
        if hashlib.sha256((root / name).read_bytes()).hexdigest() != digest:
            raise RuntimeError('Installed source differs: ' + name)


stage('installed sources match checkout', verify_sources)
if results[-1]['status'] != 'pass': raise SystemExit(1)
fixture = Path(tempfile.mkdtemp(prefix='titan-portable-', dir='/home/tester'))
package = 'titan-portable-fixture-' + str(int(time.time()))
cache = Path('/var/cache/pacman/pkg')


def predicates_and_plans():
    cli('cmd', 'present', 'bash', 'pacman', 'mise')
    cli('cmd', 'missing', 'titan-fixture-absent-command')
    cli('cmd', 'present', 'titan-fixture-absent-command', code=1)
    cli('pkg', 'present', 'bash', 'jq')
    cli('pkg', 'missing', 'bash', 'jq', code=1)
    cli('pkg', 'missing', package)
    for argv in (('pkg', 'drop', '--plan', package), ('pkg', 'cache-prune', '--plan'), ('dev', 'upgrade', '--plan')):
        assert json.loads(cli(*argv))['schema'] == 1
    assert json.loads(cli('pkg', 'last-upgrade', '--json'))['last_upgrade'] is not None


def cache_retention():
    # Install the optional tool only in this VM, through a full upgrade.
    run('sudo', 'pacman', '-Syu', '--needed', '--noconfirm', 'pacman-contrib', timeout=300)
    for version in (1, 2, 3):
        payload = fixture / str(version)
        (payload / 'etc').mkdir(parents=True)
        (payload / 'etc' / (package + '.conf')).write_text('default\n')
        (payload / '.PKGINFO').write_text(
            f'pkgname = {package}\npkgver = {version}-1\npkgdesc = disposable test fixture\n'
            'arch = any\nsize = 8\ndepend = bash\n' + f'backup = etc/{package}.conf\n')
        archive = fixture / f'{package}-{version}-1-any.pkg.tar.zst'
        run('bsdtar', '--zstd', '-cf', archive, '-C', payload, '.PKGINFO', 'etc')
        run('sudo', 'cp', archive, cache)
    cli('pkg', 'cache-prune', '--keep', '1', code=2)
    assert all((cache / f'{package}-{version}-1-any.pkg.tar.zst').exists() for version in (1, 2, 3))
    cli('pkg', 'cache-prune')
    assert not (cache / f'{package}-1-1-any.pkg.tar.zst').exists()
    assert all((cache / f'{package}-{version}-1-any.pkg.tar.zst').exists() for version in (2, 3))


def package_removal():
    run('sudo', 'pacman', '-U', '--noconfirm', fixture / f'{package}-3-1-any.pkg.tar.zst')
    config = Path('/etc') / (package + '.conf')
    run('sudo', 'tee', config, input='custom content retained\n')
    cli('pkg', 'present', package)
    cli('pkg', 'drop', package + '-absent', package, package, input='y\n')
    cli('pkg', 'missing', package)
    cli('pkg', 'present', 'bash')
    assert Path(str(config) + '.pacsave').read_text() == 'custom content retained\n'
    cli('pkg', 'drop', package, package + '-absent')


def pinned_mise_upgrade():
    # Reuse the guest's already-installed Node, but keep its global config intact.
    guest_config = Path('/home/tester/.config/mise/config.toml')
    guest_before = guest_config.read_bytes()
    node = next(item for item in json.loads(run('mise', 'ls', 'node', '--json')) if item['installed'])
    config = fixture / 'mise-config'
    config.mkdir()
    global_file = config / 'config.toml'
    original = f'[tools]\nnode = "{node["version"]}"\n'
    global_file.write_text(original)
    env = {**os.environ, 'XDG_CONFIG_HOME': str(config), 'MISE_CONFIG_DIR': str(config),
           'MISE_GLOBAL_CONFIG_FILE': str(global_file),
           'MISE_DATA_DIR': '/home/tester/.local/share/mise', 'MISE_MINIMUM_RELEASE_AGE': '7d'}
    configs = json.loads(run('mise', 'config', 'ls', '--json', env=env, cwd='/'))
    assert [item['path'] for item in configs] == [str(global_file)], configs
    before = json.loads(run('mise', 'ls', 'node', '--json', env=env, cwd='/'))
    assert any(item.get('active') and item.get('requested_version') == node['version'] and
               item.get('source', {}).get('path') == str(global_file) for item in before)
    cli('dev', 'tools', env=env, cwd='/')
    cli('dev', 'upgrade', env=env, cwd='/')
    installed = json.loads(run('mise', 'ls', 'node', '--json', env=env, cwd='/'))
    assert global_file.read_text() == original
    assert guest_config.read_bytes() == guest_before
    assert any(item['installed'] and item['version'] == node['version'] and
               item.get('requested_version') == node['version'] and
               item.get('source', {}).get('path') == str(global_file) for item in installed)


stage('real dependency predicates and side-effect-free plans', predicates_and_plans)
stage('real paccache retains two fixture versions', cache_retention)
stage('idempotent package removal retains custom config and dependencies', package_removal)
stage('real mise upgrade respects an installed exact-version pin', pinned_mise_upgrade)
raise SystemExit(any(item['status'] != 'pass' for item in results))
