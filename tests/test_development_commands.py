"""Developer CLI contracts in isolated directories, without host provisioning."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class DevelopmentCommands(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='titan-dev-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name) / 'home with spaces $(literal)'
        self.base.mkdir()
        self.tools = self.base / 'bin'
        self.tools.mkdir()
        for name in ('bash', 'dirname', 'readlink', 'jq', 'cat', 'flock', 'mkdir', 'mktemp', 'ln', 'rm'):
            (self.tools / name).symlink_to('/usr/bin/' + name)
        self.record = self.base / 'calls.jsonl'
        self.env = {**os.environ, 'PATH': str(self.tools), 'HOME': str(self.base),
                    'XDG_CONFIG_HOME': str(self.base / 'config'),
                    'XDG_STATE_HOME': str(self.base / 'state'),
                    'TITAN_TEST_RECORD': str(self.record)}
        self.config = self.base / 'config/titan/development/databases'
        self.stub('mise')
        self.stub('sudo')
        self.stub('pacman')
        self.stub('docker')

    def stub(self, name, body=''):
        path = self.tools / name
        if path.is_symlink(): path.unlink()
        path.write_text('#!/usr/bin/python3\nimport os,sys,json\nfrom pathlib import Path\n'
            'with Path(os.environ["TITAN_TEST_RECORD"]).open("a") as f:\n'
            ' f.write(json.dumps([Path(sys.argv[0]).name,*sys.argv[1:]])+"\\n")\n' + body)
        path.chmod(0o755)

    def cli(self, *argv, code=0, direct=False):
        command = (['/usr/bin/python3', str(ROOT / 'lib/titan/desktop_cli.py')] if direct
                   else [str(ROOT / 'bin/titan')])
        result = subprocess.run(command + ['dev', *argv], env=self.env, text=True,
                                capture_output=True, timeout=10)
        self.assertEqual(result.returncode, code, result.stderr)
        self.assertNotIn('Traceback', result.stderr)
        return result

    def calls(self):
        return [json.loads(row) for row in self.record.read_text().splitlines()] if self.record.exists() else []

    def recipe_fixture(self, recipe):
        root = self.base / 'catalog root'
        file = root / 'default/catalog/development.json'
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(json.dumps({'fixture': recipe}))
        return root

    def fixture_cli(self, root, action, code=0):
        result = subprocess.run(['/usr/bin/bash', '-euo', 'pipefail', '-c',
            'root=$1; source "$2/lib/titan/development.sh"; titan_dev "$3" fixture',
            'bash', str(root), str(ROOT), action], env=self.env, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, code, result.stderr)
        return result

    def test_all_plans_and_direct_callers_without_provisioning_tools_or_state(self):
        for name in ('mise', 'pacman', 'sudo', 'docker'): (self.tools / name).unlink()
        recipes = json.loads((ROOT / 'default/catalog/development.json').read_text())
        for direct in (False, True):
            self.assertEqual(json.loads(self.cli('list', direct=direct).stdout)['environments'], recipes)
            for name, recipe in recipes.items():
                commands = []
                if recipe.get('packages'): commands.append(['sudo','pacman','-Syu','--needed','--',*recipe['packages']])
                if recipe.get('tools'): commands.append(['mise','use','-g',*recipe['tools']])
                commands.extend(recipe.get('commands', []))
                self.assertEqual(json.loads(self.cli('plan', name, direct=direct).stdout), {'schema':1,'commands':commands})
            self.assertEqual(json.loads(self.cli('db','list',direct=direct).stdout)['configured'], [])
        self.assertEqual(self.calls(), [])
        self.assertFalse((self.base / 'config').exists())
        self.assertFalse((self.base / 'state').exists())

    def test_help_and_bad_syntax_never_provision(self):
        self.cli('--help')
        for action in ('list','plan','install','tools','upgrade','db'): self.cli(action,'--help')
        for action in ('list','create','start','stop','status','logs','remove'): self.cli('db',action,'--help')
        for argv in [(), ('bogus',), ('bogus','--help'), ('list','extra'), ('install',),
                     ('plan','node','ruby'), ('db',), ('db','bogus'), ('db','list','extra'),
                     ('db','create'), ('db','create','redis','--port'),
                     ('db','create','redis','--port='), ('db','create','redis','--port','1.5'),
                     ('db','start','redis','--port','15432'), ('db','remove','redis','--volumes')]:
            self.cli(*argv, code=2)
        self.cli('install','unknown',code=1)
        self.assertEqual(self.calls(), [])
        self.assertFalse((self.base / 'state').exists())

    def test_recipe_argv_order_policy_and_failure_stops_later_commands(self):
        recipe = json.loads((ROOT / 'default/catalog/development.json').read_text())['rails']
        self.env['MISE_MINIMUM_RELEASE_AGE'] = '7d'
        self.stub('mise', 'assert os.environ["MISE_MINIMUM_RELEASE_AGE"] == "7d"\n')
        self.cli('install','rails')
        expected = [['sudo','pacman','-Syu','--needed','--',*recipe['packages']],
                    ['mise','use','-g',*recipe['tools']],*recipe['commands']]
        self.assertEqual(self.calls(), expected)
        for tool, body, code, wanted in [
                ('sudo','sys.exit(9)\n',1,expected[:1]),
                ('sudo','sys.exit(130)\n',130,expected[:1]),
                ('mise','sys.exit(9)\n',1,expected[:2])]:
            self.record.unlink()
            self.stub('sudo')
            self.stub('mise')
            self.stub(tool, body)
            self.cli('install','rails',code=code)
            self.assertEqual(self.calls(), wanted)

    def test_missing_dependencies_refuse_before_first_transaction(self):
        for name in ('mise','pacman','sudo'):
            (self.tools / name).unlink()
            self.cli('install','rails',code=1)
            self.assertEqual(self.calls(), [])
            self.stub(name)
        root = self.recipe_fixture({'packages':['bash'], 'tools':['node'], 'commands':[['absent-command']]})
        self.fixture_cli(root, 'install', code=1)
        self.assertEqual(self.calls(), [])
        (self.tools / 'jq').unlink()
        self.cli('list', code=1)
        self.cli('plan','node',code=1)
        self.assertFalse((self.base / 'state').exists())

    def test_malformed_catalog_fields_refuse_before_mutation(self):
        for recipe in [{'packages':['--root']}, {'packages':['bash\n']}, {'tools':'node'},
                       {'tools':['bad\0arg']}, {'tools':[None]}, {'tools':None},
                       {'commands':[[]]}, {'commands':[['']]}, {'commands':[['mise',42]]},
                       {'commands':[['mise','bad\0arg']]}, {'commands':'mise'}]:
            root = self.recipe_fixture(recipe)
            self.fixture_cli(root, 'install', code=1)
        self.assertEqual(self.calls(), [])
        self.assertFalse((self.base / 'config').exists())

    def test_catalog_arguments_keep_quotes_spaces_and_trailing_newlines(self):
        value = 'literal $(touch OWNED) `date` "quotes"\n'
        root = self.recipe_fixture({'tools':[value], 'commands':[['mise','exec',value,'--','literal','']]})
        self.fixture_cli(root,'install')
        self.assertEqual(self.calls(), [['mise','use','-g',value],['mise','exec',value,'--','literal','']])
        self.assertFalse((ROOT / 'OWNED').exists())

    def test_database_private_atomic_creation_custom_config_and_literal_lifecycles(self):
        self.cli('db','create','postgres','--port=+0015432')
        file = self.config / 'postgres.json'
        data = json.loads(file.read_text())
        self.assertEqual(data['services']['postgres']['ports'], ['127.0.0.1:15432:5432'])
        self.assertEqual(file.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o700)
        custom = file.read_bytes() + b'\n'
        file.write_bytes(custom)
        self.cli('db','create','postgres',code=1)
        for action in ('start','stop','status','logs','remove'): self.cli('db',action,'postgres')
        base = ['sudo','docker','compose','-f',str(file)]
        self.assertEqual(self.calls(), [base+['up','-d'],base+['stop'],base+['ps','--format','json'],
                                       base+['logs','--tail','100'],base+['down']])
        self.assertEqual(file.read_bytes(), custom)
        self.assertEqual(json.loads(self.cli('db','list').stdout)['configured'], ['postgres'])
        self.assertEqual(sorted(p.name for p in self.config.iterdir()), ['postgres.json'])
        self.record.unlink()
        self.stub('sudo','sys.exit(17)\n')
        self.cli('db','start','postgres',code=1)
        self.stub('sudo','sys.exit(130)\n')
        self.cli('db','stop','postgres',code=130)
        self.assertEqual(file.read_bytes(), custom)

    def test_database_invalid_ports_paths_missing_tools_and_existing_links(self):
        for port in ('0','80','65536','-1','999999999999999999999999999999999999999'):
            self.cli('db','create','redis','--port',port,code=1)
        for name in ('../escape','$(touch OWNED)','name\n',''):
            self.cli('db','create',name,code=1)
            self.cli('db','remove',name,code=1)
        self.cli('db','create','unknown',code=1)
        self.cli('db','start','redis',code=1)
        self.assertEqual(self.calls(), [])
        self.assertFalse((self.base / 'config').exists())
        self.assertFalse((self.base / 'state').exists())
        self.config.mkdir(parents=True)
        linked = self.config / 'redis.json'
        linked.symlink_to(self.base / 'foreign')
        self.cli('db','create','redis',code=1)
        self.assertTrue(linked.is_symlink())
        self.assertFalse((self.base / 'foreign').exists())
        linked.unlink()
        self.cli('db','create','redis')
        (self.tools / 'docker').unlink()
        self.cli('db','start','redis',code=1)
        self.assertEqual(self.calls(), [])

    def test_creation_serializes_with_the_existing_python_lock(self):
        state = self.base / 'state/titan'
        state.mkdir(parents=True)
        with (state / 'databases.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            process = subprocess.Popen([str(ROOT/'bin/titan'),'dev','db','create','redis'],
                                       env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                time.sleep(.3)
                self.assertIsNone(process.poll())
                self.assertFalse(self.config.exists())
                fcntl.flock(lock, fcntl.LOCK_UN)
                stdout, stderr = process.communicate(timeout=5)
                self.assertEqual(process.returncode, 0, stderr)
                self.assertTrue(Path(stdout.strip()).is_file())
            finally:
                if process.poll() is None: process.kill(); process.communicate()
        # Concurrent independent creators cannot replace the winner's config.
        processes = [subprocess.Popen([str(ROOT/'bin/titan'),'dev','db','create','postgres','--port',str(port)],
                     env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE) for port in (15432,25432)]
        codes = []
        for process in processes:
            process.communicate(timeout=5); codes.append(process.returncode)
        self.assertEqual(sorted(codes), [0,1])
        self.assertIn(json.loads((self.config/'postgres.json').read_text())['services']['postgres']['ports'],
                      [['127.0.0.1:15432:5432'],['127.0.0.1:25432:5432']])
        self.assertFalse(any(p.name.startswith('.') for p in self.config.iterdir()))

    def test_atomic_publication_preserves_a_file_created_outside_the_lock(self):
        self.stub('ln', 'Path(sys.argv[-1]).write_text("foreign editor content\\n")\n'
                       'os.execv("/usr/bin/ln", ["ln",*sys.argv[1:]])\n')
        self.cli('db','create','redis',code=1)
        self.assertEqual((self.config / 'redis.json').read_text(), 'foreign editor content\n')
        self.assertEqual(sorted(p.name for p in self.config.iterdir()), ['redis.json'])

    def test_invalid_database_catalog_refuses_without_creating_state(self):
        root = self.base / 'database catalog root'
        file = root / 'default/catalog/databases.json'
        file.parent.mkdir(parents=True)
        valid = {'image':'redis:7','port':6379,'data_path':'/data'}
        for spec in [[], {**valid,'port':0}, {**valid,'port':6379.5},
                     {**valid,'image':None}, {**valid,'image':'bad\0image'},
                     {**valid,'environment':[]}, {**valid,'command':[42]}]:
            file.write_text(json.dumps({'redis':spec}))
            result = subprocess.run(['/usr/bin/bash','-euo','pipefail','-c',
                'root=$1; source "$2/lib/titan/development.sh"; titan_dev db create redis',
                'bash',str(root),str(ROOT)],env=self.env,text=True,capture_output=True,timeout=10)
            self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.calls(), [])
        self.assertFalse((self.base / 'state').exists())
        self.assertFalse((self.base / 'config').exists())


if __name__ == '__main__': unittest.main()
