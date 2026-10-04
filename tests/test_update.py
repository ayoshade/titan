"""Update gates, stages and interruption recovery without host transactions."""
import fcntl
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Update(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='titan-update-')
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / 'home with spaces'
        self.root = self.home / 'titan'
        for directory in ('bin', 'lib/titan', 'scripts', 'migrations'):
            (self.root / directory).mkdir(parents=True)
        shutil.copy(ROOT / 'bin/titan', self.root / 'bin/titan')
        shutil.copy(ROOT / 'lib/titan/update.sh', self.root / 'lib/titan/update.sh')
        (self.root / 'version').write_text('0.3.0\n')
        self.fake = self.home / 'fake'
        self.fake.mkdir()
        self.state = self.home / 'state/titan'
        self.record = self.home / 'calls.jsonl'
        self.env = {**os.environ, 'HOME': str(self.home),
                    'XDG_STATE_HOME': str(self.home / 'state'),
                    'PATH': str(self.fake) + ':' + os.environ['PATH'],
                    'TITAN_TEST_RECORD': str(self.record)}
        self.stub(self.fake / 'pacman', '''
if sys.argv[1:] == ['-Qq']:
    if os.environ.get('TITAN_TEST_DATABASE_FAIL'): sys.exit(3)
    print('bash' if os.environ.get('TITAN_TEST_NO_JQ') else 'bash\\njq')
elif sys.argv[1:] == ['-Syu']:
    if os.environ.get('TITAN_TEST_WAIT'):
        Path(os.environ['TITAN_TEST_WAIT']).touch()
        time.sleep(60)
    sys.exit(int(os.environ.get('TITAN_TEST_PACKAGE_FAIL', '0')))
else: sys.exit(2)
''')
        self.stub(self.fake / 'sudo', "os.execvp(sys.argv[1], sys.argv[1:])\n")
        self.stub(self.fake / 'df', '''
value = os.environ.get('TITAN_TEST_SPACE', '2147483648')
print('Avail\\n' + value)
sys.exit(int(os.environ.get('TITAN_TEST_DF_FAIL', '0')))
''')
        self.stub(self.fake / 'snapper', '''
if sys.argv[1:] == ['list-configs'] and os.environ.get('TITAN_TEST_SNAPSHOT'):
    print('root | /')
elif sys.argv[1:3] == ['-c', 'root']:
    sys.exit(int(os.environ.get('TITAN_TEST_SNAPSHOT_FAIL', '0')))
''')
        for script in ('doctor', 'install-agent-skills', 'titan-hooks'):
            self.stub(self.root / 'scripts' / script,
                      "sys.exit(int(os.environ.get('TITAN_TEST_" + script.upper().replace('-', '_') + "_FAIL', '0')))\n")
        self.stub(self.root / 'bin/titan-shell')

    def stub(self, path, body=''):
        path.write_text('#!/usr/bin/python3\nimport json,os,sys,time\nfrom pathlib import Path\n'
                        'with Path(os.environ["TITAN_TEST_RECORD"]).open("a") as f:\n'
                        '    f.write(json.dumps([Path(sys.argv[0]).name, *sys.argv[1:]])+"\\n")\n' + body)
        path.chmod(0o755)

    def cli(self, *args, code=0):
        result = subprocess.run([str(self.root / 'bin/titan'), 'update', *args],
                                env=self.env, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, code, result.stderr + result.stdout)
        return result

    def calls(self):
        return [json.loads(line) for line in self.record.read_text().splitlines()] if self.record.exists() else []

    def status(self):
        return json.loads(self.cli('status', '--json').stdout)

    def test_inspection_creates_no_state_and_does_not_contact_remote_or_sudo(self):
        check = json.loads(self.cli('check', '--json').stdout)
        self.assertTrue(check['ready'])
        self.assertEqual(check['available_root_bytes'], 2147483648)
        self.assertEqual(self.status()['status'], 'idle')
        self.assertFalse(self.state.parent.exists())
        self.assertEqual(self.calls(), [['snapper', 'list-configs'], ['pacman', '-Qq'],
                                       ['df', '--output=avail', '--block-size=1', '/']])

    def test_invalid_arguments_never_query_or_write(self):
        for args in (('--bad',), ('status', '--no-system'), ('--json',), ('check', 'extra')):
            self.cli(*args, code=2)
        self.assertFalse(self.state.parent.exists())
        self.assertEqual(self.calls(), [])

    def test_low_unknown_or_failed_space_measurement_blocks_before_privilege(self):
        for space in ('2147483647', 'unknown', '', '999999999999999999999999999'):
            self.env['TITAN_TEST_SPACE'] = space
            check = json.loads(self.cli('check', '--json', code=1).stdout)
            self.assertFalse(check['ready'])
            self.cli(code=1)
        self.env['TITAN_TEST_SPACE'] = '9999999999'
        self.env['TITAN_TEST_DF_FAIL'] = '1'
        self.cli(code=1)
        self.assertFalse(self.state.parent.exists())
        self.assertFalse(any(call[0] == 'sudo' for call in self.calls()))

    def test_database_failure_and_missing_managed_jq_block(self):
        for variable in ('TITAN_TEST_DATABASE_FAIL', 'TITAN_TEST_NO_JQ'):
            self.env[variable] = '1'
            self.cli('check', '--json', code=1)
            self.cli(code=1)
            self.env.pop(variable)
        self.assertFalse(self.state.parent.exists())
        self.assertFalse(any(call[0] == 'sudo' for call in self.calls()))

    def test_text_readiness_works_without_jq_command(self):
        for command in ('bash', 'readlink', 'dirname', 'flock', 'grep'):
            (self.fake / command).symlink_to(shutil.which(command))
        self.env['PATH'] = str(self.fake)
        result = self.cli('check', code=1)
        self.assertIn('FAIL dependency-jq', result.stdout)
        self.assertIn('PASS root-space', result.stdout)
        self.assertIn('JSON output requires jq', self.cli('check', '--json', code=1).stderr)
        self.assertFalse(self.state.exists())

    def test_live_lock_inspection_preserves_existing_record(self):
        self.state.mkdir(parents=True)
        record = {'schema': 1, 'status': 'running', 'stage': 'packages', 'exit_code': None}
        (self.state / 'update.json').write_text(json.dumps(record))
        with (self.state / 'update.lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertTrue(self.status()['busy'])
            self.assertEqual(self.status()['status'], 'running')
            self.cli('check', '--json', code=1)
            self.cli(code=1)
            self.assertEqual(json.loads((self.state / 'update.json').read_text()), record)
        self.assertEqual(self.status()['status'], 'interrupted')
        self.assertEqual(json.loads((self.state / 'update.json').read_text()), record)

    def test_full_upgrade_preserves_confirmation_and_records_success(self):
        result = self.cli()
        self.assertIn('update completed', result.stdout)
        status = self.status()
        self.assertEqual((status['status'], status['stage'], status['exit_code']), ('completed', 'complete', 0))
        self.assertIn(['sudo', 'pacman', '-Syu'], self.calls())
        self.assertIn(['pacman', '-Syu'], self.calls())
        self.assertEqual((self.state / 'update.json').stat().st_mode & 0o777, 0o600)
        self.assertFalse(any('noconfirm' in str(call) for call in self.calls()))

    def test_no_system_does_not_run_pacman_transaction(self):
        self.cli('--no-system')
        self.assertFalse(self.status()['system'])
        self.assertFalse(any(call[0] == 'sudo' or call == ['pacman', '-Syu'] for call in self.calls()))

    def test_snapshot_failure_stops_before_packages(self):
        self.env['TITAN_TEST_SNAPSHOT'] = '1'
        self.env['TITAN_TEST_SNAPSHOT_FAIL'] = '41'
        self.cli(code=41)
        self.assertEqual((self.status()['stage'], self.status()['exit_code']), ('snapshot', 41))
        self.assertFalse(any(call == ['pacman', '-Syu'] for call in self.calls()))

    def test_package_failure_preserves_exit_and_stops_later_stages(self):
        self.env['TITAN_TEST_PACKAGE_FAIL'] = '37'
        self.cli(code=37)
        status = self.status()
        self.assertEqual((status['status'], status['stage'], status['exit_code']), ('failed', 'packages', 37))
        self.assertFalse(any(call[0] in ('doctor', 'install-agent-skills', 'titan-hooks') for call in self.calls()))
        self.assertFalse((self.state / 'migrations').exists())

    def test_doctor_failure_is_not_reported_as_success(self):
        self.env['TITAN_TEST_DOCTOR_FAIL'] = '1'
        self.cli('--no-system', code=1)
        self.assertEqual((self.status()['status'], self.status()['stage']), ('failed', 'doctor'))
        self.assertFalse(any(call[0] == 'titan-hooks' for call in self.calls()))

    def test_failed_migration_stays_pending_and_can_be_retried(self):
        migration = self.root / 'migrations/123-fixture.sh'
        migration.write_text('#!/bin/bash\nexit 1\n')
        self.cli('--no-system', code=1)
        self.assertEqual(self.status()['stage'], 'migrations')
        self.assertFalse((self.state / 'migrations/123-fixture.sh').exists())
        migration.write_text('#!/bin/bash\nexit 0\n')
        self.cli('--no-system')
        self.assertTrue((self.state / 'migrations/123-fixture.sh').exists())

    def test_sigkill_leaves_read_only_interrupted_status(self):
        self.interrupt(signal.SIGKILL, 'interrupted')

    def test_sigterm_records_failure_and_releases_lock(self):
        self.interrupt(signal.SIGTERM, 'failed')
        self.assertEqual(self.status()['exit_code'], 143)

    def test_sigint_records_failure_and_releases_lock(self):
        self.interrupt(signal.SIGINT, 'failed')
        self.assertEqual(self.status()['exit_code'], 130)

    def interrupt(self, signum, expected_status):
        waiting = self.home / 'waiting'
        self.env['TITAN_TEST_WAIT'] = str(waiting)
        process = subprocess.Popen([str(self.root / 'bin/titan'), 'update'], env=self.env,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                   start_new_session=True)
        try:
            for _ in range(100):
                if waiting.exists(): break
                time.sleep(.05)
            self.assertTrue(waiting.exists())
            self.assertEqual(self.status()['stage'], 'packages')
            os.killpg(process.pid, signum)
            process.wait(timeout=5)
            for _ in range(50):
                if not self.status()['busy']: break
                time.sleep(.02)
            before = (self.state / 'update.json').read_bytes()
            self.assertEqual(self.status()['status'], expected_status)
            self.assertEqual((self.state / 'update.json').read_bytes(), before)
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=5)

    def test_linked_lock_or_record_refuses_without_touching_target(self):
        self.state.mkdir(parents=True)
        target = self.home / 'private'
        target.write_text('keep')
        for name in ('update.lock', 'update.json'):
            link = self.state / name
            link.symlink_to(target)
            self.cli('check', '--json', code=1)
            self.cli(code=1)
            self.assertEqual(target.read_text(), 'keep')
            link.unlink()

    def test_dirty_linked_worktree_blocks_and_omits_private_names(self):
        repo = self.home / 'repo'
        subprocess.run(['git', 'init', '-q', str(repo)], check=True)
        subprocess.run(['git', '-C', str(repo), 'config', 'user.email', 'test@example.invalid'], check=True)
        subprocess.run(['git', '-C', str(repo), 'config', 'user.name', 'Test'], check=True)
        private = repo / 'private filename'
        private.write_text('before')
        subprocess.run(['git', '-C', str(repo), 'add', '.'], check=True)
        subprocess.run(['git', '-C', str(repo), 'commit', '-qm', 'fixture'], check=True)
        linked = self.home / 'linked'
        subprocess.run(['git', '-C', str(repo), 'worktree', 'add', '-q', str(linked)], check=True)
        (linked / 'private filename').write_text('after')
        shutil.move(str(linked / '.git'), self.root / '.git')
        # The gitdir points back to the linked directory; explicitly set worktree.
        self.env['GIT_WORK_TREE'] = str(linked)
        result = self.cli('check', '--json', code=1)
        self.assertIn('tracked changes', result.stdout)
        self.assertNotIn('private filename', result.stdout)
        self.cli(code=1)
        self.assertFalse(self.state.exists())


if __name__ == '__main__':
    unittest.main()
