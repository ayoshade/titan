#!/usr/bin/env python3
"""Update readiness/transaction/interruption checks confined to a Titan VM."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shlex
import signal
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
        Path('/sys/class/dmi/id/sys_vendor').read_text().strip() != 'QEMU'):
    raise SystemExit('Refusing to run outside the disposable QEMU tester account')
args.output.mkdir(exist_ok=True)
log = (args.output / 'commands.log').open('w')
results = []
fixture = Path(tempfile.mkdtemp(prefix='titan-update-', dir='/home/tester'))
env = {**os.environ, 'XDG_STATE_HOME': str(fixture / 'state')}
state = fixture / 'state/titan'


def run(*argv, code=0, input=None, timeout=180):
    log.write('$ ' + shlex.join(map(str, argv)) + '\n'); log.flush()
    result = subprocess.run(list(map(str, argv)), text=True, capture_output=True,
                            input=input, env=env, timeout=timeout)
    log.write(result.stdout + result.stderr); log.flush()
    if result.returncode != code:
        raise RuntimeError(f'{argv[0]} exited {result.returncode}, expected {code}: {result.stderr[-1500:]}')
    return result.stdout


def cli(*argv, **kwargs):
    return run(root / 'bin/titan', *argv, **kwargs)


def status():
    return json.loads(cli('update', 'status', '--json'))


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


def readiness():
    assert json.loads(cli('update', 'check', '--json'))['ready']
    assert status()['status'] == 'idle'
    assert not state.exists(), 'inspection created Titan state'


def update_lock():
    state.mkdir(parents=True)
    with (state / 'update.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        check = json.loads(cli('update', 'check', '--json', code=1))
        assert any(item['id'] == 'update-lock' and item['status'] == 'fail' for item in check['checks'])
        cli('update', '--no-system', code=1)
        assert not (state / 'update.json').exists()


def pacman_lock():
    # Own only a lock created with O_EXCL, and remove it by verified inode.
    path = Path('/var/lib/pacman/db.lck')
    script = 'import os; fd=os.open("/var/lib/pacman/db.lck",os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600); print(os.fstat(fd).st_ino); os.close(fd)'
    inode = int(run('sudo', 'python3', '-c', script))
    try:
        check = json.loads(cli('update', 'check', '--json', code=1))
        assert any(item['id'] == 'pacman-lock' and item['status'] == 'fail' for item in check['checks'])
        cli('update', code=1)
        assert not (state / 'update.json').exists()
    finally:
        script = 'import os,sys; p="/var/lib/pacman/db.lck"; assert os.stat(p).st_ino==int(sys.argv[1]); os.unlink(p)'
        run('sudo', 'python3', '-c', script, str(inode))


def real_update():
    # Keep the real account's choices; bypass already-tested migrations only
    # in this isolated machine-state directory. No runtime source overlay.
    cli('migrate', '--mark-all')
    before = {path: path.read_bytes() for path in (Path.home() / '.config/titan').glob('*.json')}
    cli('update', input='y\n', timeout=360)
    record = status()
    assert (record['status'], record['stage'], record['exit_code'], record['busy']) == ('completed', 'complete', 0, False)
    assert (state / 'update.json').stat().st_mode & 0o777 == 0o600
    assert all(path.read_bytes() == data for path, data in before.items())


def failed_and_interrupted_migration():
    # Test-only guest migration, explicitly installed into this disposable VM.
    migration = root / 'migrations/9999999999-update-fixture.sh'
    source = fixture / 'migration.sh'
    source.write_text('#!/bin/bash\nexit 47\n')
    run('sudo', 'install', '-m', '644', source, migration)
    try:
        cli('update', '--no-system', code=1)
        assert (status()['status'], status()['stage']) == ('failed', 'migrations')
        assert not (state / 'migrations' / migration.name).exists()
        waiting = fixture / 'waiting'
        worker_pid = fixture / 'worker-pid'
        # An inherited worker must keep the lock even after the parent exits.
        source.write_text('#!/bin/bash\nsleep 120 &\nprintf "%s\\n" "$!" > ' + shlex.quote(str(worker_pid)) +
                          '\nprintf ready > ' + shlex.quote(str(waiting)) + '\nwait\n')
        run('sudo', 'install', '-m', '644', source, migration)
        process = subprocess.Popen([str(root / 'bin/titan'), 'update', '--no-system'], env=env,
                                   stdout=log, stderr=log, start_new_session=True)
        try:
            for _ in range(150):
                if waiting.exists(): break
                time.sleep(.1)
            assert waiting.exists(), 'migration did not reach waiting phase'
            assert status()['stage'] == 'migrations'
            # Kill just updater shells; its migration and sleep retain the fd.
            children = Path(f'/proc/{process.pid}/task/{process.pid}/children').read_text().split()
            os.kill(process.pid, signal.SIGKILL)
            for pid in children: os.kill(int(pid), signal.SIGKILL)
            process.wait(timeout=10)
            assert status()['busy'], 'worker lost inherited update lock'
            cli('update', 'check', '--json', code=1)
            os.killpg(process.pid, signal.SIGKILL)
            for _ in range(100):
                if not status()['busy']: break
                time.sleep(.05)
            saved = (state / 'update.json').read_bytes()
            assert status()['status'] == 'interrupted'
            assert (state / 'update.json').read_bytes() == saved
        finally:
            try: os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError: pass
            process.wait(timeout=10)
        source.write_text('#!/bin/bash\nexit 0\n')
        run('sudo', 'install', '-m', '644', source, migration)
        cli('update', '--no-system')
        assert status()['status'] == 'completed'
        assert (state / 'migrations' / migration.name).exists()
    finally:
        run('sudo', 'rm', '-f', '--', migration)


stage('installed update sources match checkout', sources)
if results[-1]['status'] != 'pass': raise SystemExit(1)
stage('real package readiness and read-only status', readiness)
stage('held update lock refuses without replacing status', update_lock)
stage('real pacman lock refuses before transaction', pacman_lock)
stage('real full Arch update completes with private stage record', real_update)
stage('failed migration and killed updater retain worker lock and allow retry', failed_and_interrupted_migration)
raise SystemExit(any(item['status'] != 'pass' for item in results))
