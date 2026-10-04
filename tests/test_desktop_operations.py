"""Exercise user-layer operations with real files and isolated HOME/XDG roots."""
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Operations(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='titan-ops-')
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / 'home with spaces'
        self.home.mkdir()
        self.config = self.home / '.config'
        self.state = self.home / '.local/state'
        self.data = self.home / '.local/share'
        self.env = {**os.environ, 'HOME': str(self.home), 'XDG_CONFIG_HOME': str(self.config),
                    'XDG_STATE_HOME': str(self.state), 'XDG_DATA_HOME': str(self.data),
                    'XDG_RUNTIME_DIR': str(self.home / 'runtime'), 'CODEX_HOME': str(self.home / '.codex')}
        for key in ('HYPRLAND_INSTANCE_SIGNATURE', 'WAYLAND_DISPLAY', 'TMUX'):
            self.env.pop(key, None)

    def cli(self, *args, success=True):
        result = subprocess.run([str(ROOT / 'bin/titan'), *args], env=self.env,
                                text=True, capture_output=True, timeout=15)
        if success: self.assertEqual(result.returncode, 0, result.stderr)
        else: self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertNotIn('Traceback', result.stderr)
        return result

    def test_copy_once_reset_and_restore_keep_custom_content(self):
        self.cli('config', 'install', 'tmux')
        file = self.config / 'tmux/tmux.conf'
        default = file.read_text()
        self.assertIn(str(self.config), default)
        self.assertNotIn('@@', default)
        original = b'# custom \xe2\x98\xbd\r\nset -g mouse off\r\n'
        file.write_bytes(original)
        self.cli('config', 'install', 'tmux')
        self.assertEqual(file.read_bytes(), original)
        reset = json.loads(self.cli('config', 'reset', 'tmux').stdout)
        self.assertEqual(file.read_text(), default)
        self.cli('config', 'restore', reset['backup'])
        self.assertEqual(file.read_bytes(), original)
        self.assertEqual(len(json.loads(self.cli('config', 'backups').stdout)), 2)

    def test_linked_directory_and_unknown_config_are_preserved(self):
        foreign = self.home / 'personal-tmux'
        foreign.mkdir()
        self.config.mkdir()
        (self.config / 'tmux').symlink_to(foreign)
        result = json.loads(self.cli('config', 'install', 'tmux').stdout)
        self.assertEqual(result[0]['status'], 'preserved-linked-directory')
        self.cli('config', 'reset', 'tmux', success=False)
        self.cli('config', 'reset', '../.bashrc', success=False)
        self.assertEqual(list(foreign.iterdir()), [])

    def test_all_dotfiles_parse_and_existing_config_survives(self):
        self.cli('config', 'install')
        self.cli('config', 'install')
        files = json.loads(self.cli('config', 'list').stdout)['files']
        self.assertTrue(all(item['status'] == 'default' for item in files))
        # Neovim loads the actual original Lua config headlessly.
        if shutil.which('nvim'):
            result = subprocess.run(['nvim', '--headless', '-u', str(self.config / 'nvim/init.lua'), '+qa'],
                                    env=self.env, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn('Error', result.stderr)
        subprocess.run(['git', 'config', '--file', str(self.config / 'git/config'), '--list'], check=True, capture_output=True)
        import tomllib
        for file in self.config.rglob('*.toml'): tomllib.loads(file.read_text())

    def test_webapp_launcher_is_safe_and_removal_owns_only_its_file(self):
        name = 'Notes " $(touch OWNED) % `date`'
        appid = self.cli('webapp', 'install', name, 'https://example.org/path?q=%22$thing').stdout.strip()
        file = self.data / 'applications' / ('titan-webapp-' + appid + '.desktop')
        self.assertIn(name.replace('\\', '\\\\'), file.read_text())
        self.assertFalse((ROOT / 'OWNED').exists())
        if shutil.which('desktop-file-validate'):
            subprocess.run(['desktop-file-validate', str(file)], check=True, capture_output=True)
        listed = json.loads(self.cli('webapp', 'list').stdout)
        self.assertEqual(listed[0]['name'], name)
        self.cli('webapp', 'install', name, 'https://example.org', success=False)
        self.cli('webapp', 'remove', appid)
        self.assertFalse(file.exists())
        self.assertEqual(json.loads(self.cli('webapp', 'list').stdout), [])

    def test_webapp_rejects_url_and_file_injection(self):
        for url in ('javascript:alert(1)', 'file:///etc/passwd', 'https://example.org/\nExec=evil', 'https://user:password@example.org'):
            self.cli('webapp', 'install', 'test', url, success=False)
        self.cli('webapp', 'install', '../escape', 'https://example.org', success=False)
        self.assertFalse(self.data.exists())

    def test_defaults_reject_invalid_or_missing_choices_without_writing(self):
        self.cli('defaults', 'set', 'editor', '$(touch OWNED)', success=False)
        self.assertFalse((self.config / 'titan/defaults.json').exists())
        self.cli('defaults', 'set', 'editor', 'nvim')
        self.assertEqual(self.cli('defaults', 'get', 'editor').stdout.strip(), 'nvim')
        self.cli('defaults', 'reset', 'editor')
        self.assertEqual(json.loads((self.config / 'titan/defaults.json').read_text()), {})

    def test_package_and_runtime_plans_have_no_side_effects(self):
        plan = json.loads(self.cli('pkg', 'add', '--plan', 'fzf').stdout)
        self.assertEqual(plan['commands'][0][:3], ['sudo', 'pacman', '-Syu'])
        self.cli('pkg', 'add', '--plan', '../bad', success=False)
        for name in json.loads(self.cli('dev', 'list').stdout)['environments']:
            commands = json.loads(self.cli('dev', 'plan', name).stdout)['commands']
            self.assertTrue(commands)
            self.assertTrue(all(isinstance(command, list) for command in commands))
        self.cli('dev', 'plan', 'unknown', success=False)
        self.assertFalse(self.config.exists())

    def test_database_config_is_loopback_only_and_preserves_volumes(self):
        self.cli('dev', 'db', 'create', 'postgres', '--port', '15432')
        file = self.config / 'titan/development/databases/postgres.json'
        data = json.loads(file.read_text())
        self.assertEqual(data['services']['postgres']['ports'], ['127.0.0.1:15432:5432'])
        self.assertTrue(data['volumes'])
        self.assertEqual(data['services']['postgres']['volumes'], ['data:/var/lib/postgresql'])
        self.cli('dev', 'db', 'create', 'postgres', success=False)
        self.cli('dev', 'db', 'create', 'redis', '--port', '80', success=False)
        self.cli('dev', 'db', 'create', 'redis', '--port', '0', success=False)
        self.assertEqual(json.loads(file.read_text()), data)

    def test_archive_roundtrip_and_traversal_refusal(self):
        folder = self.home / 'source'
        folder.mkdir(); (folder / 'hello.txt').write_text('hello')
        archive = self.home / 'source.tar.gz'
        self.cli('archive', 'compress', str(folder), str(archive))
        destination = self.home / 'restored'
        self.cli('archive', 'extract', str(archive), str(destination))
        self.assertEqual((destination / 'source/hello.txt').read_text(), 'hello')
        self.cli('archive', 'extract', str(archive), str(destination), success=False)
        malicious = self.home / 'malicious.tar'
        with tarfile.open(malicious, 'w') as tar:
            info = tarfile.TarInfo('../outside'); info.size = 4
            tar.addfile(info, io.BytesIO(b'evil'))
        self.cli('archive', 'extract', str(malicious), str(self.home / 'rejected'), success=False)
        self.assertFalse((self.home / 'outside').exists())
        self.assertFalse((self.home / 'rejected').exists())

    def test_hooks_keep_argument_boundaries_and_run_after_failure(self):
        folder = self.config / 'titan/hooks/test.d'; folder.mkdir(parents=True)
        (folder / '10-fail').write_text('exit 1\n')
        (folder / '20-record').write_text('printf "%s" "$1" > "$HOME/hook-result"\n')
        value = 'spaces $(touch OWNED) `date`'
        self.cli('hook', 'test', value, success=False)
        self.assertEqual((self.home / 'hook-result').read_text(), value)
        self.cli('hook', '../bad', success=False)

    def test_plugin_install_enable_disable_remove_and_validate(self):
        folder = self.home / 'plugin'; folder.mkdir()
        (folder / 'manifest.json').write_text(json.dumps({'schema': 1, 'id': 'local.demo', 'name': 'Demo', 'version': '1', 'entry': 'Main.qml', 'kinds': ['service']}))
        (folder / 'Main.qml').write_text('import QtQuick\nQtObject { property string example: "ok" }\n')
        self.cli('plugin', 'install', str(folder))
        self.assertFalse(json.loads(self.cli('plugin', 'list').stdout)['plugins'][0]['enabled'])
        self.cli('plugin', 'enable', 'local.demo')
        generated = self.state / 'titan/generated/plugins.json'
        self.assertEqual(json.loads(generated.read_text())[0]['id'], 'local.demo')
        self.cli('plugin', 'disable', 'local.demo')
        self.assertEqual(json.loads(generated.read_text()), [])
        self.cli('plugin', 'remove', 'local.demo')
        self.assertTrue(list((self.state / 'titan/plugin-backups').glob('*')))
        (folder / 'linked.qml').symlink_to(folder / 'Main.qml')
        self.cli('plugin', 'validate', str(folder), success=False)

    def test_bash_modules_preserve_user_environment_and_functions(self):
        self.cli('config', 'install', 'inputrc')
        script = ('EDITOR=vim; PS1="custom prompt"; compress() { printf "custom function"; }; '
                  '. "$1/default/bash/rc"; . "$1/default/bash/rc"; '
                  '[[ $EDITOR == vim && $PS1 == "custom prompt" ]]; [[ $(compress) == "custom function" ]]')
        result = subprocess.run(['bash', '--noprofile', '--norc', '-c', script, 'bash', str(ROOT)],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_generated_themes_share_the_palette_and_preserve_user_helix_theme(self):
        folder = self.config / 'helix/themes'; folder.mkdir(parents=True)
        file = folder / 'titan.toml'; file.write_text('# custom theme\n')
        script = ('import sys,json;sys.path.insert(0,sys.argv[1]+"/lib/titan");'
                  'from app_theme import render_apps;from paths import THEME_DIR;'
                  '[render_apps(p) for p in json.loads((THEME_DIR/"palettes.json").read_text())]')
        subprocess.run(['python', '-c', script, str(ROOT)], env=self.env, check=True)
        self.assertEqual(file.read_text(), '# custom theme\n')
        import tomllib
        generated = self.state / 'titan/generated'
        for file in generated.glob('*.toml'): tomllib.loads(file.read_text())
        palette = json.loads((generated / 'palette.json').read_text())
        self.assertIn(palette['accent'], (generated / 'tmux.conf').read_text())
        self.assertIn(palette['background'], (generated / 'titan.theme').read_text())

    @unittest.skipUnless(shutil.which('tmux'), 'tmux is required')
    def test_tmux_layout_creates_real_panes_on_an_owned_socket(self):
        # TMUX_TMPDIR ensures this test cannot connect to the owner's server.
        self.env['TMUX_TMPDIR'] = self.temp.name
        self.cli('config', 'install', 'tmux')
        socket = Path(self.temp.name) / f'tmux-{os.getuid()}/default'
        try:
            self.cli('tmux', 'swarm', '--session', 'test', '--count', '4', 'bash')
            result = subprocess.run(['tmux', '-S', str(socket), 'list-panes', '-t', '=test:', '-F', '#{pane_id}'],
                                    env=self.env, check=True, capture_output=True, text=True)
            self.assertEqual(len(result.stdout.splitlines()), 4)
            self.cli('tmux', 'swarm', '--session', 'test', '--count', '4', 'bash', success=False)
        finally:
            if socket.exists(): subprocess.run(['tmux', '-S', str(socket), 'kill-server'], env=self.env, capture_output=True)

    @unittest.skipUnless(shutil.which('ffmpeg'), 'ffmpeg is required')
    def test_real_media_conversion_and_output_preservation(self):
        file = self.home / 'sample.mp4'
        subprocess.run(['ffmpeg', '-nostdin', '-y', '-f', 'lavfi', '-i', 'color=c=black:s=64x64:d=0.2',
                        '-pix_fmt', 'yuv420p', str(file)], check=True, capture_output=True)
        for format, size in [('mp4', '720p'), ('gif', '720p'), ('png', 'low')]:
            self.cli('transcode', str(file), '--format', format, '--size', size)
            destination = self.home / ('sample-' + size + '.' + format)
            original = destination.read_bytes()
            self.cli('transcode', str(file), '--format', format, '--size', size, success=False)
            self.assertEqual(destination.read_bytes(), original)
        self.assertTrue(file.exists())


if __name__ == '__main__': unittest.main()
