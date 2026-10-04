"""Dependency contracts and transaction boundaries, without host package writes."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PortableCommands(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='titan-portable-')
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / 'home with spaces'
        self.home.mkdir()
        self.fake = self.home / 'bin'
        self.fake.mkdir()
        self.record = self.home / 'calls.jsonl'
        self.env = {**os.environ, 'HOME': str(self.home),
                    'XDG_CONFIG_HOME': str(self.home / 'config'),
                    'XDG_STATE_HOME': str(self.home / 'state'),
                    'PATH': str(self.fake) + ':' + os.environ['PATH'],
                    'TITAN_TEST_RECORD': str(self.record)}
        self.stub('pacman', '''
if sys.argv[1:] == ['-Qq']:
    if os.environ.get('TITAN_TEST_QUERY_FAIL'): sys.exit(1)
    print('bash\\njq\\nfoo+bar')
''')
        self.stub('sudo', '''
if os.environ.get('TITAN_TEST_UPGRADE_FAIL'): sys.exit(1)
''')

    def stub(self, name, body=''):
        path = self.fake / name
        path.write_text('#!/usr/bin/python3\nimport json,os,sys\nfrom pathlib import Path\n'
                        'with Path(os.environ["TITAN_TEST_RECORD"]).open("a") as f:\n'
                        '    f.write(json.dumps([Path(sys.argv[0]).name, *sys.argv[1:]])+"\\n")\n' + body)
        path.chmod(0o755)
        return path

    def cli(self, *args, code=0):
        result = subprocess.run([str(ROOT / 'bin/titan'), *args], env=self.env,
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, code, result.stderr)
        self.assertNotIn('Traceback', result.stderr)
        return result

    def calls(self):
        return [json.loads(line) for line in self.record.read_text().splitlines()] if self.record.exists() else []

    def test_command_predicates_do_not_execute_inputs(self):
        literal = self.stub('literal $(touch OWNED)')
        self.cli('cmd', 'present', 'bash', str(literal))
        self.cli('cmd', 'missing', 'bash', str(literal), code=1)
        self.cli('cmd', 'present', 'bash', 'titan-nonexistent-test-command', code=1)
        self.cli('cmd', 'missing', 'bash', 'titan-nonexistent-test-command')
        self.assertEqual(self.calls(), [])
        self.assertFalse((ROOT / 'OWNED').exists())

    def test_predicates_validate_every_argument(self):
        for family in ('cmd', 'pkg'):
            for action in ('present', 'missing'):
                self.cli(family, action, code=2)
                self.cli(family, action, 'absent', '--bad', code=2)
                self.cli(family, action, '', code=2)
        self.assertEqual(self.calls(), [])

    def test_package_predicates_distinguish_absence_and_database_failure(self):
        self.assertEqual(self.cli('pkg', 'present', 'bash', 'foo+bar').stdout, 'bash\nfoo+bar\n')
        self.cli('pkg', 'missing', 'bash', 'foo+bar', code=1)
        self.cli('pkg', 'present', 'bash', 'absent', code=1)
        self.cli('pkg', 'missing', 'bash', 'absent')
        self.env['TITAN_TEST_QUERY_FAIL'] = '1'
        self.cli('pkg', 'present', 'bash', code=3)
        self.cli('pkg', 'missing', 'bash', code=3)
        self.cli('pkg', 'drop', 'bash', code=1)
        self.assertTrue(all(call == ['pacman', '-Qq'] for call in self.calls()))

    def test_plans_have_no_process_or_user_state_side_effects(self):
        for action, prefix in (('add', ['sudo', 'pacman', '-Syu', '--needed', '--']),
                               ('drop', ['sudo', 'pacman', '-R', '--'])):
            plan = json.loads(self.cli('pkg', action, '--plan', 'foo+bar').stdout)
            self.assertEqual(plan, {'schema': 1, 'commands': [prefix + ['foo+bar']]})
        self.assertEqual(json.loads(self.cli('dev', 'upgrade', '--plan').stdout),
                         {'schema': 1, 'commands': [['mise', 'upgrade']]})
        self.assertEqual(json.loads(self.cli('pkg', 'cache-prune', '--plan').stdout),
                         {'schema': 1, 'commands': [['sudo', 'paccache', '-r', '-k', '2']]})
        self.assertEqual(self.calls(), [])
        self.assertFalse((self.home / 'config').exists())
        self.assertFalse((self.home / 'state').exists())

    def test_all_catalog_plans_preserve_the_existing_contract(self):
        catalog = json.loads((ROOT / 'default/catalog/packages.json').read_text())
        self.assertEqual(json.loads(self.cli('pkg', 'list').stdout)['bundles'], catalog)
        for name, recipe in catalog.items():
            with self.subTest(name=name):
                plan = json.loads(self.cli('pkg', 'bundle', name).stdout)
                expected = ['sudo', 'pacman', '-Syu']
                if recipe['packages']: expected += ['--needed', '--', *recipe['packages']]
                self.assertEqual(plan['commands'][0], expected)
                self.assertEqual(plan['repositories'], recipe.get('repositories', []))
                self.assertEqual(plan['after_install'], recipe.get('after_install', []))
        self.assertEqual(self.calls(), [])

    def test_package_arguments_remain_literal_and_invalid_names_never_run(self):
        self.cli('pkg', 'search', '--query $(touch OWNED)')
        self.assertEqual(self.calls(), [['pacman', '-Ss', '--', '--query $(touch OWNED)']])
        self.record.unlink()
        for action in ('drop', 'present', 'missing'):
            for name in ('../file', '--root', '$(touch OWNED)', 'bash\nExec=bad'):
                self.cli('pkg', action, name, code=2)
        self.assertEqual(self.calls(), [])

    def test_package_add_uses_full_upgrade_and_retains_confirmation(self):
        self.cli('pkg', 'add', 'foo+bar', 'bash')
        self.assertEqual(self.calls(), [['sudo', 'pacman', '-Syu', '--needed', '--', 'foo+bar', 'bash']])

    def test_remove_ignores_absent_packages_and_duplicates(self):
        self.cli('pkg', 'drop', 'absent', 'bash', 'bash', 'foo+bar')
        self.assertEqual(self.calls(), [['pacman', '-Qq'], ['sudo', 'pacman', '-R', '--', 'bash', 'foo+bar']])
        self.record.unlink()
        self.cli('pkg', 'drop', 'absent')
        self.assertEqual(self.calls(), [['pacman', '-Qq']])

    def test_bundle_missing_repository_refuses_before_transaction(self):
        self.stub('pacman-conf', "print('core\\nextra')\n")
        self.cli('pkg', 'bundle', 'gaming', '--apply', code=1)
        self.assertEqual(self.calls(), [['pacman-conf', '--repo-list']])

    def test_aur_failure_stops_before_build_and_preserves_upgrade_order(self):
        self.stub('paru')
        self.env['TITAN_TEST_UPGRADE_FAIL'] = '1'
        self.cli('pkg', 'aur', 'test-package', code=1)
        self.assertEqual(self.calls(), [['sudo', 'pacman', '-Syu']])
        self.record.unlink()
        self.env.pop('TITAN_TEST_UPGRADE_FAIL')
        self.cli('pkg', 'bundle', 'sharing', '--apply')
        self.assertEqual(self.calls(), [['sudo', 'pacman', '-Syu'], ['paru', '-S', '--needed', '--', 'localsend-bin']])

    def test_cache_retention_validates_before_privilege(self):
        self.stub('paccache')
        for keep in ('0', '1', '-1', '02', '1000', '$(touch OWNED)'):
            self.cli('pkg', 'cache-prune', '--keep', keep, code=2)
        self.cli('pkg', 'cache-prune', '--keep', code=2)
        self.assertEqual(self.calls(), [])
        self.cli('pkg', 'cache-prune', '--keep', '3')
        self.assertEqual(self.calls(), [['sudo', 'paccache', '-r', '-k', '3']])

    def test_mise_preserves_caller_policy_and_propagates_failure(self):
        self.stub('mise', "print(os.environ.get('MISE_MINIMUM_RELEASE_AGE', 'unset'))\nsys.exit(int(os.environ.get('TITAN_TEST_MISE_FAIL', '0')))\n")
        self.env['MISE_MINIMUM_RELEASE_AGE'] = '7d'
        self.assertEqual(self.cli('dev', 'upgrade').stdout.strip(), '7d')
        self.cli('dev', 'tools')
        self.env['TITAN_TEST_MISE_FAIL'] = '1'
        self.cli('dev', 'upgrade', code=1)
        self.assertEqual(self.calls(), [['mise', 'upgrade'], ['mise', 'ls'], ['mise', 'upgrade']])

    def test_upgrade_history_handles_empty_and_non_upgrade_logs(self):
        log = self.home / 'pacman.log'
        log.write_text('[2026-10-01T12:00:00+0000] [PACMAN] Running upgraded\n'
                       '[2026-10-02T12:00:00+0000] [ALPM] upgraded bash (1 -> 2)\n'
                       '[2026-10-03T12:00:00+0000] [ALPM] installed jq (1)\n')
        def inspect():
            return subprocess.run(['bash', '-euo', 'pipefail', '-c',
                'source "$1/lib/titan/packages.sh"; titan_pkg_last_upgrade --json "$2"',
                'bash', str(ROOT), str(log)], env=self.env, capture_output=True, text=True, timeout=10)
        result = inspect()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {'schema': 1, 'last_upgrade': '2026-10-02T12:00:00+0000'})
        log.write_text('')
        self.assertIsNone(json.loads(inspect().stdout)['last_upgrade'])
        log.unlink()
        self.assertNotEqual(inspect().returncode, 0)

    def test_direct_python_callers_delegate_and_help_lists_new_actions(self):
        result = subprocess.run(['/usr/bin/python3', str(ROOT / 'lib/titan/desktop_cli.py'),
                                 'pkg', 'missing', 'absent'], env=self.env,
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        help_text = self.cli('pkg', '--help').stdout
        for action in ('missing', 'last-upgrade', 'cache-prune'): self.assertIn(action, help_text)
        self.cli('pkg', 'unknown', '--help', code=2)
        self.cli('dev', 'upgrade', '--unexpected', code=2)


if __name__ == '__main__':
    unittest.main()
