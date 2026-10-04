"""bin/ holds Titan's public commands; scripts/NAME links exist only for old callers."""
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ["titan", "titan-shell", "titan-session", "titan-install", "workflow"]
LEGACY = re.compile(r"scripts/(titan|titan-shell|titan-session|titan-install|workflow)(?![-\w])")
MIGRATION = next(ROOT.glob("migrations/*-public-commands-bin.sh"))


class Layout(unittest.TestCase):
    def test_public_commands_and_compatibility_links(self):
        for name in PUBLIC:
            self.assertTrue(os.access(ROOT / "bin" / name, os.X_OK), name)
            link = ROOT / "scripts" / name
            self.assertTrue(link.is_symlink(), name)
            self.assertEqual(os.readlink(link), f"../bin/{name}")

    def test_no_code_calls_the_compatibility_paths(self):
        files = subprocess.run(["git", "-C", ROOT, "ls-files"], capture_output=True, text=True, check=True).stdout.split()
        allowed = ("docs/", "migrations/", "scripts/legacy-paths", "tests/test_layout.py")
        offenders = []
        for name in files:
            path = ROOT / name
            if name.startswith(allowed) or name.endswith(".md") or path.is_symlink() or not path.is_file():
                continue
            try:
                text = path.read_text()
            except UnicodeDecodeError:
                continue
            offenders += [f"{name}:{n}" for n, line in enumerate(text.splitlines(), 1) if LEGACY.search(line)]
        self.assertEqual(offenders, [])


class Migration(unittest.TestCase):
    def run_migration(self, home):
        env = {**os.environ, "HOME": str(home), "TITAN_ROOT": str(ROOT), "XDG_CONFIG_HOME": str(home / ".config")}
        return subprocess.run(["bash", MIGRATION], env=env, capture_output=True, text=True, check=True).stdout

    def test_relinks_checkout_commands_and_reports_user_files(self):
        with tempfile.TemporaryDirectory() as folder:
            home = Path(folder)
            local = home / ".local/bin"
            local.mkdir(parents=True)
            (local / "titan").symlink_to(ROOT / "scripts/titan")
            (local / "other").symlink_to("/usr/bin/true")
            user = home / ".config/titan"
            user.mkdir(parents=True)
            (user / "hypr.lua").write_text('hl.exec_cmd("/usr/share/titan/scripts/workflow nightlight")\n')
            (user / "kitty.conf").write_text("# scripts/workflow-like text without a slash prefix\n")

            out = self.run_migration(home)
            self.assertEqual(os.readlink(local / "titan"), str(ROOT / "bin/titan"))
            self.assertEqual(os.readlink(local / "other"), "/usr/bin/true")
            self.assertIn("hypr.lua:1:", out)
            self.assertNotIn("kitty.conf", out)
            self.assertIn("workflow nightlight", (user / "hypr.lua").read_text())  # reported, never rewritten

            again = self.run_migration(home)
            self.assertNotIn("→", again)

    def test_clean_home_reports_nothing(self):
        with tempfile.TemporaryDirectory() as folder:
            self.assertEqual(self.run_migration(Path(folder)), "")


if __name__ == "__main__":
    unittest.main()
