"""System CLI privacy, validation and failure contracts without host controls."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SystemCommands(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='titan-system-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.tools = self.base / 'bin'
        self.tools.mkdir()
        for name in ('bash', 'dirname', 'readlink', 'jq', 'timeout'):
            (self.tools / name).symlink_to('/usr/bin/' + name)
        self.record = self.base / 'calls.jsonl'
        self.env = {**os.environ, 'PATH': str(self.tools), 'HOME': str(self.base),
                    'XDG_CONFIG_HOME': str(self.base / 'config'),
                    'XDG_STATE_HOME': str(self.base / 'state'),
                    'TITAN_TEST_RECORD': str(self.record)}
        for name in ('nmcli', 'nmtui', 'bluetoothctl', 'wpctl', 'powerprofilesctl'):
            self.stub(name)

    def stub(self, name, body=''):
        path = self.tools / name
        if path.is_symlink(): path.unlink()
        path.write_text('#!/usr/bin/python3\nimport os,sys,json\nfrom pathlib import Path\n'
            'with Path(os.environ["TITAN_TEST_RECORD"]).open("a") as f:\n'
            ' f.write(json.dumps([Path(sys.argv[0]).name,*sys.argv[1:]])+"\\n")\n' + body +
            '\nsys.exit(int(os.environ.get("TITAN_TEST_FAIL", "0")))\n')
        path.chmod(0o755)

    def cli(self, *argv, code=0, direct=False):
        command = ([ '/usr/bin/python3', str(ROOT / 'lib/titan/desktop_cli.py')] if direct
                   else [str(ROOT / 'bin/titan')])
        result = subprocess.run(command + list(argv), env=self.env, text=True,
                                capture_output=True, timeout=10)
        self.assertEqual(result.returncode, code, result.stderr)
        self.assertNotIn('Traceback', result.stderr)
        return result

    def calls(self):
        return [json.loads(row) for row in self.record.read_text().splitlines()] if self.record.exists() else []

    def test_native_routes_and_direct_compatibility_without_python_on_path(self):
        self.stub('nmcli', 'print("ethernet0:ethernet:connected")\n')
        for direct in (False, True):
            self.assertEqual(json.loads(self.cli('network', 'status', direct=direct).stdout),
                             {'schema': 1, 'devices': [{'device': 'ethernet0', 'type': 'ethernet', 'state': 'connected'}]})
            self.cli('audio', 'status', direct=direct)
            self.cli('bluetooth', 'devices', direct=direct)
            self.cli('power', 'current', direct=direct)
            self.assertEqual(set(json.loads(self.cli('battery', direct=direct).stdout)), {'schema', 'batteries', 'power'})
        self.assertFalse((self.base / 'config').exists())
        self.assertFalse((self.base / 'state').exists())

    def test_help_and_bad_syntax_invoke_no_system_tools(self):
        for family, actions in {'battery': [], 'network': ['status','wifi','qr','edit'],
                'bluetooth': ['status','devices','pair','power','connect','disconnect','trust','untrust','remove'],
                'power': ['current','list','set'], 'audio': ['status','default','volume','mute']}.items():
            self.cli(family, '--help')
            for action in actions: self.cli(family, action, '--help')
            self.cli(family, 'bogus', code=2)
        for args in [('network','wifi','toggle'), ('network','qr','--device'),
                     ('battery','extra'), ('audio','volume',''), ('audio','volume','--input',''),
                     ('audio','volume','--input','1','2'), ('audio','volume','1.5'),
                     ('audio','default','nan'), ('audio','mute'), ('audio','mute','on','off'),
                     ('bluetooth','connect'), ('power','set','unknown')]:
            self.cli(*args, code=2)
        self.assertEqual(self.calls(), [])

    def test_audio_ranges_literal_ids_and_input_option_order(self):
        for value in ('-1', '101', '999999999999999999999999999999999999999'):
            self.cli('audio', 'volume', value, code=1)
        for value in ('0', '-7'): self.cli('audio', 'default', value, code=1)
        self.assertEqual(self.calls(), [])
        self.cli('audio', 'volume', '+0040', '--input')
        self.cli('audio', 'volume', '--input', '100')
        self.cli('audio', 'volume', '-0')
        self.cli('audio', 'volume', '--input')
        self.cli('audio', 'mute', '--input', 'on')
        self.cli('audio', 'mute', 'off')
        self.cli('audio', 'default', '+00042')
        self.assertEqual(self.calls(), [
            ['wpctl','set-volume','-l','1','@DEFAULT_AUDIO_SOURCE@','40%'],
            ['wpctl','set-volume','-l','1','@DEFAULT_AUDIO_SOURCE@','100%'],
            ['wpctl','set-volume','-l','1','@DEFAULT_AUDIO_SINK@','0%'],
            ['wpctl','get-volume','@DEFAULT_AUDIO_SOURCE@'],
            ['wpctl','set-mute','@DEFAULT_AUDIO_SOURCE@','1'],
            ['wpctl','set-mute','@DEFAULT_AUDIO_SINK@','0'], ['wpctl','set-default','42']])

    def test_network_status_decodes_escaped_fields_and_omits_private_columns(self):
        self.stub('nmcli', 'print(r"ethernet\\:0:ethernet:connected")\nprint(r"veth\\\\name:ethernet:disconnected")\n')
        rows = json.loads(self.cli('network','status').stdout)['devices']
        self.assertEqual(rows[0]['device'], 'ethernet:0')
        self.assertEqual(rows[1]['device'], 'veth\\name')
        self.assertEqual(self.calls(), [['nmcli','-t','-f','DEVICE,TYPE,STATE','device','status']])
        self.stub('nmcli', 'print("bad:row")\n')
        result = self.cli('network','status',code=1)
        self.assertEqual(result.stdout, '')
        self.assertNotIn('bad:row', result.stderr)

    def test_explicit_interactive_and_credentials_routes_use_inherited_stdio(self):
        self.cli('network','qr','--device','wlan0')
        self.cli('network','qr','--device=wlan1')
        self.cli('network','edit')
        self.cli('bluetooth','pair')
        self.cli('network','wifi','status')
        self.cli('network','wifi','off')
        self.assertEqual(self.calls(), [['nmcli','device','wifi','show-password','ifname','wlan0'],
            ['nmcli','device','wifi','show-password','ifname','wlan1'],
            ['nmtui'], ['bluetoothctl'], ['nmcli','radio','wifi'], ['nmcli','radio','wifi','off']])
        # Only noninteractive calls go through timeout; no terminal prompts are captured.
        self.record.unlink()
        self.stub('timeout', 'sys.exit(124)\n')
        self.cli('network','edit')
        self.cli('bluetooth','pair')
        self.cli('audio','status',code=1)
        self.assertEqual(self.calls(), [['nmtui'], ['bluetoothctl'],
            ['timeout','--foreground','--kill-after=5s','30s','wpctl','status','-n']])

    def test_rejects_injection_and_failed_commands_without_success_json(self):
        for args in [('network','qr','--device','../wlan0'),
                     ('network','qr','--device','wlan0\nsecret'),
                     ('bluetooth','connect','$(touch OWNED)'),
                     ('bluetooth','remove','--option')]:
            self.cli(*args,code=1)
        self.assertEqual(self.calls(), [])
        self.env['TITAN_TEST_FAIL'] = '9'
        for args in [('network','status'), ('network','wifi','on'), ('network','edit'),
                     ('bluetooth','connect','01:23:45:67:89:ab'), ('bluetooth','pair'),
                     ('audio','status'), ('power','current')]:
            self.assertEqual(self.cli(*args,code=1).stdout, '')
        self.env['TITAN_TEST_FAIL'] = '130'
        self.cli('audio','status',code=130)
        self.cli('bluetooth','pair',code=130)

    def test_missing_dependencies_and_timeouts(self):
        (self.tools / 'wpctl').unlink()
        self.cli('audio','status',code=1)
        self.assertEqual(self.calls(), [])
        self.stub('wpctl')
        (self.tools / 'timeout').unlink()
        self.cli('audio','status',code=1)
        self.assertEqual(self.calls(), [])
        self.stub('timeout', 'sys.exit(124)\n')
        self.assertIn('timed out', self.cli('network','status',code=1).stderr)
        self.assertEqual(len(self.calls()), 1)

    def test_policy_marker_refuses_only_nonperformance_profiles(self):
        policy = self.base / 'policy marker'
        def inspect(profile, code):
            result = subprocess.run(['/usr/bin/bash','-euo','pipefail','-c',
                'source "$1/lib/titan/system_status.sh"; titan_system_power_policy "$2" "$3"',
                'bash', str(ROOT), profile, str(policy)],env=self.env,text=True,capture_output=True)
            self.assertEqual(result.returncode, code, result.stderr)
        inspect('balanced', 0)
        policy.touch()
        inspect('balanced', 1)
        inspect('power-saver', 1)
        inspect('performance', 0)
        self.assertEqual(self.calls(), [])

    def test_battery_optional_fields_disappearing_devices_and_no_batteries(self):
        supply = self.base / 'power supply'
        supply.mkdir()
        def device(name, files):
            folder = supply / name
            folder.mkdir()
            for key, value in files.items(): (folder / key).write_text(str(value) + '\n')
        device('BAT0', {'type':'Battery', 'status':'Discharging', 'capacity':'078', 'energy_now':222,
                        'energy_full':300, 'energy_full_design':400, 'cycle_count':15})
        device('AC', {'type':'Mains', 'online':1})
        device('gone', {'type':'Battery'})
        def inspect(code=0):
            result = subprocess.run(['/usr/bin/bash','-euo','pipefail','-c',
                'source "$1/lib/titan/system_status.sh"; titan_system_battery "$2"',
                'bash', str(ROOT), str(supply)], env=self.env, text=True, capture_output=True)
            self.assertEqual(result.returncode, code, result.stderr)
            return result
        value = json.loads(inspect().stdout)
        self.assertEqual(value['batteries'][0]['capacity'], 78)
        self.assertEqual(value['power'], [{'device':'AC', 'online':True}])
        self.assertEqual(len(value['batteries']), 1)
        (supply / 'BAT0/capacity').write_text('bad\n')
        self.assertEqual(inspect(code=1).stdout, '')
        import shutil
        shutil.rmtree(supply)
        self.assertEqual(json.loads(inspect().stdout), {'schema':1,'batteries':[],'power':[]})


if __name__ == '__main__': unittest.main()
