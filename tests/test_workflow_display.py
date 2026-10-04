"""Monitor scale chips and game mode in lib/titan/workflow.py, against a fake Hyprland."""
import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "lib/titan"))
import workflow  # noqa: E402


class Scales(unittest.TestCase):
    def test_every_offered_scale_divides_the_panel_cleanly(self):
        for width, height in ((1366, 768), (1920, 1080), (2560, 1440), (2880, 1800)):
            monitor = {"width": width, "height": height}
            for values in (workflow.STEP_SCALES, workflow.CHIP_SCALES):
                for scale in workflow.scale_candidates(monitor, values):
                    units = round(scale * 120)
                    self.assertEqual((width * 120) % units, 0, (width, scale))
                    self.assertEqual((height * 120) % units, 0, (height, scale))

    def test_chips_stay_within_the_reference_range(self):
        chips = workflow.scale_candidates({"width": 1920, "height": 1080}, workflow.CHIP_SCALES)
        self.assertEqual(chips[0], 1.0)
        self.assertEqual(chips[-1], 2.0)

    def test_set_refuses_unclean_scales_and_unknown_monitors(self):
        monitor = {"name": "eDP-1", "width": 1366, "height": 768, "scale": 1.0, "focused": True, "x": 0, "y": 0}
        applied = []
        saved_hypr, saved_set = workflow.hypr, workflow.set_scale
        workflow.hypr = lambda _: [monitor]
        workflow.set_scale = lambda m, value: applied.append((m["name"], value))
        try:
            with self.assertRaises(ValueError):
                workflow.scale("set", ["eDP-1", "1.5"])
            with self.assertRaises(ValueError):
                workflow.scale("set", ["HDMI-A-9", "1"])
            workflow.scale("set", ["eDP-1", "2"])
        finally:
            workflow.hypr, workflow.set_scale = saved_hypr, saved_set
        self.assertEqual(applied, [("eDP-1", 2.0)])


PATTERNS = {"animations:enabled": r"animations=\{enabled=(\w+)", "decoration:blur:enabled": r"blur=\{enabled=(\w+)",
            "decoration:shadow:enabled": r"shadow=\{enabled=(\w+)", "decoration:rounding": r"rounding=(\d+)",
            "general:border_size": r"border_size=(\d+)"}


class GameMode(unittest.TestCase):
    CONFIGURED = {"animations:enabled": True, "decoration:blur:enabled": True, "decoration:shadow:enabled": True,
                  "decoration:rounding": 16, "general:border_size": 1}

    def setUp(self):
        self.options = dict(self.CONFIGURED)
        self.tmp = tempfile.TemporaryDirectory()
        self.saved = (workflow.RUNTIME, workflow.option, workflow.evaluate, workflow.shell_running)
        workflow.RUNTIME = Path(self.tmp.name)
        workflow.option = lambda name: self.options[name]
        workflow.shell_running = lambda: True

        def evaluate(expression):
            # Apply the values an hl.config expression assigns, as Hyprland would.
            for name, pattern in PATTERNS.items():
                match = re.search(pattern, expression)
                if match:
                    value = match.group(1)
                    self.options[name] = value == "true" if value in ("true", "false") else int(value)
        workflow.evaluate = evaluate

    def tearDown(self):
        workflow.RUNTIME, workflow.option, workflow.evaluate, workflow.shell_running = self.saved
        self.tmp.cleanup()

    def test_toggle_drops_every_effect_and_restores_the_configured_values(self):
        workflow.game_mode()
        self.assertEqual(self.options, {"animations:enabled": False, "decoration:blur:enabled": False,
                                        "decoration:shadow:enabled": False, "decoration:rounding": 0,
                                        "general:border_size": 0})
        self.assertTrue(workflow.game_mode_active())
        workflow.game_mode()
        self.assertEqual(self.options, self.CONFIGURED)
        self.assertFalse((workflow.RUNTIME / "game-mode.json").exists())

    def test_state_saved_before_rounding_was_included_keeps_current_corners(self):
        # Game mode turned on by the previous version saved only three options
        # and never changed rounding or borders.
        self.options.update({"animations:enabled": False, "decoration:blur:enabled": False,
                             "decoration:shadow:enabled": False})
        (workflow.RUNTIME / "game-mode.json").write_text(json.dumps(
            {"animations:enabled": True, "decoration:blur:enabled": True, "decoration:shadow:enabled": True}))
        workflow.game_mode()
        self.assertEqual(self.options, self.CONFIGURED)


if __name__ == "__main__":
    unittest.main()
