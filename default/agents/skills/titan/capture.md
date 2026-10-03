# Screenshots, OCR, colour picker and recording

All capture goes through one implementation: `scripts/workflow capture KIND`
(Python in `lib/titan/workflow.py`, function `capture`). Keys, the Capture menu
(Super+Ctrl+C) and `scripts/screenshot` all call it, so change behaviour there
once rather than in each caller.

## Commands and keys

| Action | Key | Command | Result |
| --- | --- | --- | --- |
| Region / window screenshot | Print | `scripts/workflow capture screenshot` (`scripts/screenshot region`) | `~/Pictures/Screenshots/YYYY-MM-DD_HH-MM-SS-*.png`, also copied to the clipboard as `image/png`, and a notification |
| Whole focused monitor | Ctrl+Return while selecting, or the Capture menu | `scripts/workflow capture full` (`scripts/screenshot full`) | Same folder |
| Text (OCR) | Super+Ctrl+Print | `scripts/workflow capture text` | Text recognized by `tesseract -l eng` is copied to the clipboard; the temporary PNG in `$XDG_RUNTIME_DIR/titan` is deleted |
| Colour picker | Super+Print | `scripts/workflow capture color` | `hyprpicker -a` (copies the hex); runs as user unit `titan-colorpicker`; pressing again cancels |
| Start / stop recording | Alt+Print | `scripts/workflow capture record` | `wf-recorder` region recording to `~/Videos/Recordings/*.mp4` as user unit `titan-screenrecord`; pressing again sends SIGINT so the file is finalized |
| Select geometry only | — | `scripts/workflow pick` | Prints `X,Y WxH` (exit 1 if cancelled) |

Super+Print is the colour picker, **not** a full screenshot. This matches the
Omarchy chord set; see `docs/keybindings.md`.

## Region selection

`pick()` runs `slurp` with every visible window rectangle plus the focused
monitor as candidates. While the selection layer is open, temporary bindings
are added: Enter takes the highlighted window, Ctrl+Enter the monitor,
Tab/Ctrl+Tab cycle windows, and arrows move to a neighbouring window. Eight
extra binds exist only during selection, and the helper removes them through
their own handles. Do not count them as permanent binds.

## Common customizations

- **Save folder or file name:** edit the paths in `capture()`. Keep the
  timestamped `mkstemp` naming, which avoids overwriting files. Create the
  folder with `mkdir(parents=True, exist_ok=True)`.
- **Don't copy to the clipboard, or don't save:** adjust the `run('wl-copy', …)`
  and `grim` calls in the `else` branch. Ask which the user wants; both happen
  by default.
- **Recording audio or quality:** add `wf-recorder` arguments in the `record`
  branch (for example `--audio`). Arguments are always argv lists; never build
  shell strings from user text.
- **A different OCR language:** change `-l eng`. The language data must be
  installed (`pacman -Ss tesseract-data`). Show the install command for the
  user to run.
- **New keybinding:** use `b.task("KEY", "Description", "capture KIND")` in
  `config/hypr/bindings/utilities.lua`, update `keybindings.json` and
  `docs/keybindings.md`, then check for conflicts (see
  [hyprland.md](hyprland.md)).
- **Annotation or editing after capture:** no editor (satty, swappy) is
  installed. Suggest installing one and then calling it on the saved path. That
  is a new dependency, so ask first, and add it to `packages/` if it becomes
  part of Titan.

## Verify

- **After editing workflow.py:** `python3 -m py_compile
  ~/dotfiles/lib/titan/workflow.py`, then `titan doctor`.
- **`full` takes a real screenshot** of the focused monitor. Run it only after
  telling the user, because it captures whatever is on screen (possibly
  private). Check the file exists, then delete test captures you created.
- **Do not start a recording** or the colour picker without the user present;
  both are interactive or ongoing. If a recording was left running, stop it
  with `systemctl --user kill --signal=SIGINT titan-screenrecord.service`.
- **Required tools:** `grim`, `slurp`, `wl-copy`, `tesseract`, `hyprpicker`,
  `wf-recorder`. If one is missing, the workflow shows a notice pointing to
  `scripts/install-workflow`.
