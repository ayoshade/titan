"""Generate application palettes from Titan's existing palette catalog."""
import json
import os
from pathlib import Path

from ops import atomic
from paths import CONFIG, GENERATED, HOME


def render_apps(palette):
    p = palette
    atomic(GENERATED / 'palette.json', json.dumps(p, indent=2) + '\n')
    atomic(GENERATED / 'tmux.conf',
           f'set -g status-style "bg={p["surface"]},fg={p["text"]}"\n'
           f'set -g pane-border-style "fg={p["raised"]}"\n'
           f'set -g pane-active-border-style "fg={p["accent"]}"\n'
           f'set -g window-status-current-style "fg={p["accent"]},bold"\n'
           f'set -g message-style "bg={p["surface"]},fg={p["text"]}"\n')
    atomic(GENERATED / 'foot.ini', '[colors-dark]\n' + ''.join(f'{k}={p[v][1:]}\n' for k, v in
           [('background', 'background'), ('foreground', 'text'), ('selection-background', 'raised'), ('selection-foreground', 'text')]))
    atomic(GENERATED / 'ghostty.conf', ''.join(f'{k} = {p[v]}\n' for k, v in
           [('background', 'background'), ('foreground', 'text'), ('cursor-color', 'accent'), ('selection-background', 'raised')]))
    atomic(GENERATED / 'alacritty.toml', '[colors.primary]\n' + f'background = "{p["background"]}"\nforeground = "{p["text"]}"\n'
           + f'[colors.cursor]\ntext = "{p["background"]}"\ncursor = "{p["accent"]}"\n')
    colors = {'main_bg': p['background'], 'main_fg': p['text'], 'title': p['text'], 'hi_fg': p['accent'],
              'selected_bg': p['raised'], 'selected_fg': p['text'], 'inactive_fg': p['muted'],
              'graph_text': p['text'], 'meter_bg': p['raised'], 'proc_misc': p['accent'], 'div_line': p['raised']}
    for box in ('cpu', 'mem', 'net', 'proc'): colors[box + '_box'] = p['accent']
    for metric in ('temp', 'cpu', 'free', 'cached', 'available', 'used', 'download', 'upload', 'process'):
        for suffix, color in zip(('start', 'mid', 'end'), (p['muted'], p['accent'], p['danger'])):
            colors[metric + '_' + suffix] = color
    atomic(GENERATED / 'titan.theme', ''.join(f'theme[{key}]="{color}"\n' for key, color in colors.items()))
    # Helix discovers named themes in XDG config. A symlink created only when
    # absent keeps generated state separate from user-edited editor files.
    atomic(GENERATED / 'helix.toml',
           f'"ui.background" = {{ bg = "{p["background"]}" }}\n'
           f'"ui.text" = "{p["text"]}"\n"ui.selection" = {{ bg = "{p["raised"]}" }}\n'
           f'"ui.cursor" = {{ fg = "{p["background"]}", bg = "{p["accent"]}" }}\n'
           f'"ui.statusline" = {{ fg = "{p["text"]}", bg = "{p["surface"]}" }}\n'
           f'"comment" = "{p["muted"]}"\n"keyword" = "{p["accent"]}"\n')
    config = Path(os.environ.get('XDG_CONFIG_HOME', HOME / '.config'))
    target = config / 'helix/themes/titan.toml'
    if not target.exists() and not target.is_symlink() and not any(parent.is_symlink() for parent in target.parents):
        target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        target.symlink_to(GENERATED / 'helix.toml')
