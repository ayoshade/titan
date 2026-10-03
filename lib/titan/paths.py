"""Titan file locations: defaults ship in the checkout/package, user choices in
~/.config/titan, machine-managed state in ~/.local/state/titan."""
import json, os, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
HOME = pathlib.Path.home()
CONFIG = pathlib.Path(os.environ.get('XDG_CONFIG_HOME', str(HOME/'.config')))/'titan'
STATE = pathlib.Path(os.environ.get('XDG_STATE_HOME', str(HOME/'.local/state')))/'titan'
RUNTIME = pathlib.Path(os.environ.get('XDG_RUNTIME_DIR', '/run/user/'+str(os.getuid())))/'titan'
GENERATED = STATE/'generated'
PREFERENCES = CONFIG/'preferences.json'
SETTINGS = CONFIG/'settings.json'
THEME_DIR = ROOT/'config/quickshell/umbra/theme'
DEFAULT_PREFERENCES = THEME_DIR/'preferences-default.json'

def read_json(path, fallback):
    try: return json.loads(pathlib.Path(path).read_text())
    except (FileNotFoundError, json.JSONDecodeError): return fallback

def preferences():
    """Defaults overlaid with the user's choices."""
    merged = read_json(DEFAULT_PREFERENCES, {'theme': 'graphite', 'accent': 'theme', 'motion': True, 'wallpaper': True})
    merged.update(read_json(PREFERENCES, {}))
    return merged
