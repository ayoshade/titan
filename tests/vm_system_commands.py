#!/usr/bin/env python3
"""Real system control acceptance confined to an owned Titan QEMU guest."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
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
fixture = Path(tempfile.mkdtemp(prefix='titan-system-', dir='/home/tester'))
env = {**os.environ, 'XDG_CONFIG_HOME': str(fixture / 'config'),
       'XDG_STATE_HOME': str(fixture / 'state'), 'XDG_RUNTIME_DIR': f'/run/user/{os.getuid()}'}
choices = {p: p.read_bytes() for p in (Path.home() / '.config/titan').glob('*.json')}


def run(*argv, code=0, environment=None, input=None, error=None):
    log.write('$ ' + shlex.join(map(str, argv)) + '\n'); log.flush()
    result = subprocess.run(list(map(str, argv)), text=True, capture_output=True,
                            input=input, env=environment or env, timeout=45)
    log.write(result.stdout + result.stderr); log.flush()
    if result.returncode != code:
        raise RuntimeError(f'{argv[0]} exited {result.returncode}, expected {code}: {result.stderr[-1500:]}')
    if error is not None: assert error in result.stderr, result.stderr
    return result.stdout


def cli(*argv, **kwargs):
    return run(root / 'bin/titan', *argv, **kwargs)


def privileged_cli(*argv, **kwargs):
    # SSH has no active graphical Polkit session. Authenticate only in this VM.
    return run('sudo', root / 'bin/titan', *argv, **kwargs)


def stage(name, check):
    try:
        check()
        results.append({'name': name, 'status': 'pass'})
        print('PASS ' + name, flush=True)
    except Exception as error:
        results.append({'name': name, 'status': 'fail', 'error': str(error)})
        print('FAIL ' + name + ': ' + str(error), flush=True)
    (args.output / 'results.json').write_text(json.dumps({'schema':1,'checks':results}, indent=2) + '\n')


def sources():
    for name, digest in json.loads(args.manifest.read_text()).items():
        assert hashlib.sha256((root / name).read_bytes()).hexdigest() == digest, name
    assert not (root / 'lib/titan/system_status.py').exists(), 'retired module still packaged'


def native_reads():
    tools = fixture / 'bin'
    tools.mkdir()
    for name in ('bash', 'dirname', 'readlink', 'jq', 'timeout', 'nmcli', 'wpctl', 'bluetoothctl', 'powerprofilesctl'):
        (tools / name).symlink_to('/usr/bin/' + name)
    native = {**env, 'PATH': str(tools)}
    assert json.loads(cli('battery', environment=native)) == {'schema':1,'batteries':[],'power':[]}
    for family in ('network','audio','bluetooth','power'):
        cli(family,'--help',environment=native)
    result = json.loads(cli('network','status',environment=native))
    assert result['schema'] == 1 and result['devices']
    assert all(set(row) == {'device','type','state'} for row in result['devices'])
    direct = json.loads(run('/usr/bin/python3', root / 'lib/titan/desktop_cli.py', 'network','status',environment=native))
    assert direct == result
    assert not (fixture / 'config').exists() and not (fixture / 'state').exists()


def network_radio():
    before = run('nmcli','radio','wifi').strip()
    try:
        target = 'off' if before == 'enabled' else 'on'
        privileged_cli('network','wifi',target)
        assert cli('network','wifi','status').strip() == ('disabled' if target == 'off' else 'enabled')
        cli('network','wifi','--help')
        cli('network','qr','--device','../invalid',code=1)
    finally:
        privileged_cli('network','wifi','on' if before == 'enabled' else 'off')
    assert run('nmcli','radio','wifi').strip() == before


def audio():
    # Real PipeWire nodes exercise controls without any physical audio hardware.
    old_default = None
    old = subprocess.run(['wpctl','inspect','@DEFAULT_AUDIO_SINK@'],env=env,text=True,capture_output=True)
    if old.returncode == 0:
        import re
        match = re.search(r'^id (\d+)', old.stdout)
        if match: old_default = match[1]
    name = 'titan-system-' + uuid.uuid4().hex[:12]
    run('pw-cli','create-node','adapter', '{ factory.name=support.null-audio-sink node.name=' + name +
        ' media.class=Audio/Sink object.linger=true audio.position=[ FL FR ] }')
    identifier = None
    try:
        nodes = json.loads(run('pw-dump'))
        identifier = next(str(row['id']) for row in nodes if row.get('info',{}).get('props',{}).get('node.name') == name)
        cli('audio','status')
        cli('audio','default',identifier)
        assert name in run('wpctl','inspect','@DEFAULT_AUDIO_SINK@')
        cli('audio','volume','37')
        assert '0.37' in cli('audio','volume')
        cli('audio','mute','on')
        assert '[MUTED]' in cli('audio','volume')
        cli('audio','mute','toggle')
        assert '[MUTED]' not in cli('audio','volume')
        cli('audio','volume','101',code=1)
        assert '0.37' in cli('audio','volume')
        cli('audio','default','0',code=1)
        cli('audio','volume','--input','--help')
    finally:
        if old_default and old_default != identifier: cli('audio','default',old_default)
        elif identifier: run('wpctl','clear-default','0')
        if identifier: run('pw-cli','destroy',identifier)


def power_policy():
    before = cli('power','current').strip()
    profiles = cli('power','list')
    try:
        privileged_cli('power','set','power-saver')
        assert cli('power','current').strip() == 'power-saver'
        policy = Path('/etc/systemd/logind.conf.d/99-titan-always-awake.conf')
        assert not policy.exists(), 'Policy fixture must not replace an existing policy'
        run('sudo','mkdir','-p',policy.parent)
        # Marker is inspected by Titan only; logind is never restarted/reloaded.
        run('sudo','python3','-c',
            'import os,sys; fd=os.open(sys.argv[1],os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600); os.close(fd)', policy)
        try:
            privileged_cli('power','set','balanced',code=1)
            assert cli('power','current').strip() == 'power-saver'
            if 'performance:' in profiles:
                privileged_cli('power','set','performance')
                assert cli('power','current').strip() == 'performance'
            else:
                # QEMU's placeholder driver offers only balanced/power-saver.
                privileged_cli('power','set','performance',code=1,error="invalid choice: 'performance'")
                assert cli('power','current').strip() == 'power-saver'
        finally:
            run('sudo','rm','--',policy)
    finally:
        privileged_cli('power','set',before)
    assert cli('power','current').strip() == before


def bluetooth_without_adapter():
    # The unit can be skipped by its kernel/adapter condition in a cloud VM.
    if subprocess.run(['systemctl','is-active','--quiet','bluetooth.service']).returncode:
        cli('bluetooth','status',code=1,error='timed out')
        cli('bluetooth','connect','invalid',code=1)
        return
    # QEMU has no Bluetooth controller. Native diagnostics/refusals remain visible.
    for action, argv in [('status',['show']), ('devices',['devices']), ('power',['power','on'])]:
        reference = subprocess.run(['timeout','--foreground','--kill-after=5s','30s','bluetoothctl',*argv],
                                   env=env,text=True,capture_output=True,timeout=40)
        actual = cli('bluetooth',action,*(['on'] if action == 'power' else []),code=0 if reference.returncode == 0 else 1)
        assert actual == reference.stdout
    cli('bluetooth','connect','invalid',code=1)
    cli('bluetooth','trust','01:23:45:67:89:ab',code=1)


def preservation():
    assert all(p.read_bytes() == content for p, content in choices.items())
    assert not (fixture / 'config').exists() and not (fixture / 'state').exists()


# Services exist in titan-desktop, but a cloud boot may not activate them.
units = ['NetworkManager.service','bluetooth.service','power-profiles-daemon.service']
user_units = ['pipewire.service','wireplumber.service']
started, user_started = [], []
try:
    for unit in units:
        if subprocess.run(['systemctl','is-active','--quiet',unit]).returncode:
            started.append(unit)
            run('sudo','systemctl','start',unit)
    # User services need normal account defaults rather than isolated XDG config.
    service_env = {**os.environ, 'XDG_RUNTIME_DIR': env['XDG_RUNTIME_DIR']}
    for unit in user_units:
        if subprocess.run(['systemctl','--user','is-active','--quiet',unit],env=service_env).returncode:
            user_started.append(unit)
            run('systemctl','--user','start',unit,environment=service_env)
    stage('installed runtime hashes and retired Python module', sources)
    stage('native no-state inspection and direct compatibility', native_reads)
    stage('real Wi-Fi radio toggle and restoration', network_radio)
    stage('real PipeWire default, volume, mute and refusals', audio)
    stage('real power profiles, policy refusal and restoration', power_policy)
    stage('Bluetooth unavailable-daemon timeout or controller refusal', bluetooth_without_adapter)
    stage('user choice and no-state preservation', preservation)
finally:
    for unit in reversed(user_started): run('systemctl','--user','stop',unit,environment=service_env)
    for unit in reversed(started): run('sudo','systemctl','stop',unit)
    log.close()
raise SystemExit(0 if results and all(row['status'] == 'pass' for row in results) else 1)
