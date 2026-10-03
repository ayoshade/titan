"""Observable registration and preservation behavior in disposable homes."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1]


class AgentSkills(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name) / "relocated Titan"
        self.home = Path(self.scratch.name) / "user home"
        (self.root / "scripts").mkdir(parents=True)
        self.home.mkdir()
        shutil.copy(SOURCE / "scripts/install-agent-skills", self.root / "scripts")
        shutil.copytree(SOURCE / "default/agents/skills", self.root / "default/agents/skills")
        self.env = dict(os.environ, HOME=str(self.home), CODEX_HOME=str(self.home / "custom codex"))
        self.codex = self.home / "custom codex/skills"
        self.claude = self.home / ".claude/skills"

    def register(self, *args):
        return subprocess.run([str(self.root / "scripts/install-agent-skills"), *args],
                              env=self.env, capture_output=True, text=True)

    def test_dry_run_never_creates_agent_directories(self):
        result = self.register("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("titan-shell-dev", result.stdout)
        self.assertFalse(self.codex.parent.exists())
        self.assertFalse(self.claude.parent.exists())

    def test_all_bundled_references_are_accessible_and_repeat_is_a_noop(self):
        result = self.register()
        self.assertEqual(result.returncode, 0, result.stderr)
        names = {p.parent.name for p in (self.root / "default/agents/skills").glob("*/SKILL.md")}
        for directory in [self.codex, self.claude]:
            self.assertEqual({p.name for p in directory.iterdir()}, names)
            for name in names:
                self.assertEqual((directory / name).resolve(), self.root / "default/agents/skills" / name)
            self.assertTrue((directory / "titan/theming.md").is_file())
        self.assertFalse((self.home / ".codex").exists())
        before = {p: p.lstat().st_ino for folder in [self.codex, self.claude] for p in folder.iterdir()}
        self.assertEqual(self.register().returncode, 0)
        self.assertEqual({p: p.lstat().st_ino for p in before}, before)

    def test_custom_skill_is_preserved_and_preflight_prevents_partial_install(self):
        custom = self.claude / "titan-shell-dev"
        custom.mkdir(parents=True)
        (custom / "SKILL.md").write_text("My own skill\n")
        result = self.register()
        self.assertEqual(result.returncode, 1)
        self.assertIn("Refusing existing skill", result.stderr)
        self.assertEqual((custom / "SKILL.md").read_text(), "My own skill\n")
        self.assertFalse(self.codex.exists())
        self.assertEqual(list(self.claude.iterdir()), [custom])

    def test_broken_foreign_symlink_is_preserved(self):
        self.claude.mkdir(parents=True)
        custom = self.claude / "titan"
        custom.symlink_to("/missing/personal-skill")
        self.assertEqual(self.register().returncode, 1)
        self.assertEqual(os.readlink(custom), "/missing/personal-skill")
        self.assertFalse(self.codex.exists())

    def test_non_directory_parent_is_rejected_before_any_links(self):
        (self.home / ".claude").write_text("personal file\n")
        self.assertEqual(self.register().returncode, 1)
        self.assertFalse(self.codex.exists())
        self.assertEqual((self.home / ".claude").read_text(), "personal file\n")

    def test_unknown_and_extra_arguments_do_not_write(self):
        for args in [("--replace",), ("--dry-run", "extra")]:
            with self.subTest(args=args):
                self.assertEqual(self.register(*args).returncode, 2)
                self.assertFalse(self.codex.exists())
                self.assertFalse(self.claude.exists())


if __name__ == "__main__":
    unittest.main()
