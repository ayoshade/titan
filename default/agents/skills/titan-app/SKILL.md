---
name: titan-app
description: 'Build a new desktop app for **Titan** the way Titan''s own apps are built (Hype, Monologue, Omacut or another alternative): C++ and Qt Quick, compiled with qmake6 and make into a single binary, following the **Titan theme live**, and installed as an Arch package so it shows up in the app launcher. Use when asked to make, build, or scaffold an app, tool, utility, or GUI program for the desktop. Triggers: new app, make me an app, desktop app, GUI, Qt, QML, Qt Quick, C++ app, qmake, app launcher entry, PKGBUILD for my app.'
---

# Building a Titan desktop app

Titan apps are native Qt 6 programs. They use C++ for logic and system access,
and Qt Quick (QML) for the UI. They are built with `qmake6` and `make` into
**one binary** (QML and icon compiled into the resources). They read the
**Titan theme live**, so they recolour when the user switches theme, and ship as
an **Arch package** so the launcher (Super+Alt+Space) lists them.

Names like Hype, Monologue and Omacut describe the *kind* of app (small,
focused, polished). None exist on Titan yet: the reference implementation is
[templates.md](templates.md). It was compiled, run, live-themed and packaged on
this machine (Qt 6.11.2, GCC 16) before this skill was written.

## Workflow

1. **Clarify the app in one or two sentences:** what it does, what data it
   touches, and whether it needs network, files, audio and so on. Ask only if
   the purpose is genuinely unclear; otherwise propose a name and build.
2. **Pick names:**
   - Binary/package: lowercase, for example `monologue`.
   - Display name: `Monologue`.
   - App id: `io.titan.monologue`.
   - Check the name is free with `pacman -Ss '^NAME$'` and `which NAME`.
3. **Create the project** in `~/Projects/<name>/` (its own Git repo; not inside
   `~/dotfiles` unless the user wants it to ship with Titan). Copy every file
   from [templates.md](templates.md) and replace the placeholders `myapp`,
   `My App`, `io.titan.myapp` and `One-line description`, file names included.
4. **Build the feature:**
   - **C++** for anything stateful or system-facing: file I/O, processes,
     D-Bus, models. Expose it to QML with `Q_PROPERTY`, `Q_INVOKABLE` and
     signals, through `qmlRegisterSingletonInstance` or `QML_ELEMENT` types.
   - **QML** for the UI only.
   - **New QML files** must be added to `resources.qrc`, or they won't be in
     the binary.
   - **New Qt modules** go in `QT +=` in the `.pro` file *and* `depends=()` in
     the PKGBUILD (for example `multimedia` → `qt6-multimedia`).
5. **Build and run from the project:**
   ```sh
   mkdir -p build && cd build && qmake6 ../NAME.pro && make -j"$(nproc)" && ./NAME
   ```
   The app opens as a tiled Hyprland window with class `io.titan.NAME`
   (`hyprctl clients -j`). Screenshot it with
   `grim -g "X,Y WxH" /tmp/…png` and look at it. Fix every compiler and QML
   warning that comes from your code. The GCC 16 `-Wsfinae-incomplete` warning
   from `qbitarray.h` comes from Qt's headers; ignore it.
6. **Prove the live theme:**
   - Note the current theme (`titan theme current`).
   - With the app open, run `titan theme nord` and
     `titan settings set panelRadius 12`, then screenshot.
   - Restore the original theme (`titan theme ORIGINAL`) and
     `titan settings reset panelRadius`.
   - Colours, accent, font and radius must change without a restart.
7. **Package:**
   - `cd packaging && makepkg -f` builds the package, with no sudo.
   - Inspect it: `tar -tvf NAME-*.pkg.tar.zst` should list only
     `usr/bin/NAME`, `usr/share/applications/io.titan.NAME.desktop` and
     `usr/share/icons/hicolor/scalable/apps/io.titan.NAME.svg` (plus whatever
     you added).
   - Validate the launcher entry with
     `desktop-file-validate io.titan.NAME.desktop` (no output means valid).
8. **Install, which the user does:** installing needs root. Never ask for a
   password; give the command for them to run:
   `! sudo pacman -U ~/Projects/NAME/packaging/NAME-VERSION-1-x86_64.pkg.tar.zst`
   (or `makepkg -si`).
   - Arch builds a `NAME-debug-…` package too (`OPTIONS` includes `debug` in
     `/etc/makepkg.conf`). Installing it lets the `diagnose-crash` skill
     symbolize this app's crashes; it is optional.
9. **Verify in the launcher:** after installing, `titan-shell open launcher`
   and type the display name. The entry appears with its icon; Enter launches
   it.
10. **Report:** where the project lives, how to build, run and install it,
    what you verified (screenshots, the live-theme test, package contents),
    and what you didn't (for example real clicks).

## Live theme contract (keep apps consistent)

The `Titan` QML singleton (`src/TitanTheme.*`) reads the same files the Titan
shell does:

| Source | Provides |
| --- | --- |
| `~/.config/quickshell/umbra/theme/palettes.json` | Palette colours by id: `background`, `shell`, `surface`, `raised`, `border`, `text`, `muted`, `accent`, `danger`, `notch`, `swatches` |
| `~/.config/titan/preferences.json` over `…/umbra/theme/preferences-default.json` | Current `theme`, `accent` (`theme`, `silver`, `ice`, `sage`, `custom`) and `motion` |
| `~/.config/titan/settings.json` | `bodyFont`, `displayFont`, `fontSize`, `cornerRadius`, `panelRadius`, `reduceMotion`, `fadeMs`, `movementMs`, `accentCustom` |

- **Live updates:** Titan replaces these files atomically. The singleton
  watches both the files and their directories, re-adds the watches after
  every change, and debounces bursts.
- **Fallbacks:** if the files are missing, it uses Graphite defaults, so the
  app still runs on a non-Titan machine.
- **Use only the tokens:** `Titan.shell` for the window, `Titan.surface` for
  cards, `Titan.raised` for hover, `Titan.text`/`Titan.muted` for text,
  `Titan.accent` for primary actions and focus, `Titan.danger` for
  destructive actions, `Titan.notch` for text on accent.
  - Never hard-code colours.
  - Use `Titan.fontFamily`/`Titan.displayFont` and `Titan.fontSize`
    (with offsets such as `+8` for titles).
  - Use `Titan.radius`/`Titan.panelRadius` for corners and
    `Titan.duration`/`Titan.movement` for animations (0 under reduced
    motion).
- **Look:** dark black and graphite, rounded surfaces, pill buttons,
  restrained motion, generous spacing (12–16 px), and one accent used
  sparingly. The shell's control center and Settings window are the visual
  reference (`~/dotfiles/config/quickshell/umbra/components/`).
- **App id:** `QGuiApplication::setDesktopFileName("io.titan.NAME")`. It must
  equal the `.desktop` basename and `StartupWMClass`, so the window, the
  launcher entry and Hyprland window rules (`match = { class = "^io\\.titan\\.NAME$" }`)
  all agree.
- **Style:** `QQuickStyle::setStyle("Basic")` plus the app's own components.
  Don't depend on a platform style plugin.

## Quality bar

- **Keyboard:** everything is reachable with Tab/Enter/Escape, with visible
  focus (accent border).
- **Accessibility:** set `Accessible.name` on icon-only controls.
- **Window size:** a sensible `minimumWidth`/`minimumHeight`. The window must
  work tiled at half of a 1366×768 screen and on HiDPI. Use no fixed pixel
  layouts that break when the font size setting changes.
- **Work off the UI thread:** files, network and processes use Qt's async
  APIs (`QProcess`, `QNetworkAccessManager`, worker `QThread`). No busy loops,
  and timers only while visible.
- **User data:** store it under
  `QStandardPaths::writableLocation(AppDataLocation)`
  (`~/.local/share/NAME`) and config under `~/.config/NAME`. Never write into
  `~/dotfiles`.
- **Security:** no shell string building with user input (`QProcess` with an
  argument list). No secrets in source or logs.
- **License:** put one in the repo, and make it match the PKGBUILD's
  `license=()`. Don't copy code or assets from other apps without a compatible
  license and attribution.

## Don'ts

- Don't use CMake, Electron, GTK, Python GUIs or other toolkits unless the user
  asks. Titan apps are qmake6 + make + Qt Quick.
- Don't load QML from disk at runtime in the packaged app. Everything ships in
  `resources.qrc`, as one binary.
- Don't put the PKGBUILD next to `src/`. `makepkg` owns `src/` and `pkg/`
  beside the PKGBUILD (`makepkg -C` deletes `src/`), so it lives in
  `packaging/`.
- Don't run `sudo`, `pacman -U` or `makepkg -i` yourself, and don't ask for
  passwords.
- Don't edit the Titan shell to "integrate" an app unless asked. A desktop
  entry is all the launcher needs.
