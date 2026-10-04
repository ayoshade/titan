# Modular desktop and developer workflows

These additions follow the [pinned Omarchy reference](research/agent-references.md)
with original Titan code. Existing shortcuts, Quickshell surfaces and distribution
layers remain the integration points. [Coverage](research/omarchy.md) records
what is implemented, what is adapted and what is still missing.

## Applications and defaults

```sh
titan defaults list
titan defaults set terminal kitty
titan defaults set editor helix
titan defaults set browser firefox
titan defaults set agent codex
titan defaults reset editor
titan launch --cwd ~/Work editor README.md
titan launch --focus org.example.App app example-app
titan launch tui btop
titan webapp install 'Project notes' https://example.org --icon web-browser
titan webapp list
titan webapp launch project-notes
titan webapp remove project-notes
```

Selections live in `~/.config/titan/defaults.json`. Selecting an absent executable
fails without changing state. Browser selection also updates the XDG default;
terminal selection writes `xdg-terminals.list`. The existing workflow shortcuts
use these choices and preserve their default Kitty/Firefox/Neovim behavior.
Terminal, editor and file launches can use the focused terminal's working
directory. `--focus` matches an exact window class.

Web apps have private metadata under `~/.config/titan/webapps/` and a named
launcher under `$XDG_DATA_HOME/applications/titan-webapp-ID.desktop`. Install
preserves existing ids. URLs must be HTTP(S), with no embedded credentials or
raw whitespace. Icon names use installed icons; no automatic external icon
download occurs. Chromium-compatible browsers support an app window; Firefox
opens a regular browser window. Removing a web app removes only its managed
launcher and metadata, preserving browser profiles.

## Packages and development

```sh
titan pkg list
titan pkg search xournalpp
titan pkg bundle shell-tools             # inspect a plan
titan pkg bundle shell-tools --apply     # full upgrade + installation
titan pkg add --plan fzf zoxide
titan pkg add fzf zoxide
titan pkg remove PACKAGE                 # pacman reviews the transaction
titan pkg aur --plan PACKAGE             # existing paru/yay helper
titan dev list
titan dev plan rails
titan dev install node
titan dev tools
titan dev upgrade
```

`default/catalog/packages.json` and `development.json` are the maintained
recipes. Desktop packages use full pacman upgrades. Developer tools and
runtimes use mise's global config, including explicitly named HTTP/GitHub
backends for Composer and Symfony CLI. The
[mise HTTP backend](https://mise.jdx.dev/dev-tools/backends/http.html) manages
the [official Composer artifact](https://getcomposer.org/download/), rather
than depositing unmanaged executables in `~/.local/bin`. Composer versions come
from the publisher's stable-version feed, ordered by semantic version, with a
versioned download URL. PHP recipes first install the Arch build dependencies
required by mise's source-building PHP plugin; compilation can take several
minutes. These optional dependencies aren't added to the desktop package set.

Optional bundles are outside `packages/*.txt`: setup never installs them all.
Gaming requires multilib already enabled; the operation refuses to silently
change pacman repositories or select GPU drivers. AUR bundles need an existing
reviewed helper. Plans list follow-up service setup; package installation alone
does not enable services or log into accounts. No install recipe runs downloaded
shell source using `curl | sh`.

Optional service workflows are maintained operations too:

```sh
titan service list
titan service plan docker
titan service setup docker               # package upgrade, then enable service
titan service setup printing
titan service setup tailscale
titan service login tailscale
titan service receive tailscale ~/Downloads
titan service status docker
titan service disable docker
```

These recipes manage only Docker, CUPS and Tailscale, with explicit sudo in the
maintenance terminal. They don't modify the existing NetworkManager, firewall,
login or power services. Service status retains systemctl's status exit codes.
Enable/disable also manages Docker's socket and CUPS's socket/path activation
units, so disabled services can't immediately restart through an active listener.

```sh
titan dev db list
titan dev db create postgres --port 15432
titan dev db start postgres
titan dev db status postgres
titan dev db logs postgres
titan dev db stop postgres
titan dev db remove postgres
```

Database recipes create editable Docker Compose JSON in the user layer.
PostgreSQL, MySQL, MariaDB, Redis and MongoDB bind only to `127.0.0.1`; they are
local development services with permissive local authentication. Named volumes
retain data through `stop` and `remove` (Compose `down`, without `-v`). Docker
commands use sudo; this never adds a user to the docker group. PostgreSQL 18's
volume uses `/var/lib/postgresql`, following the
[official image](https://hub.docker.com/_/postgres). MSSQL is not implemented.

## Dotfiles, themes and Bash

```sh
titan config list
titan config install                     # missing files only
titan config diff tmux
titan config backup tmux
titan config reset tmux                  # backup before replacing
titan config backups
titan config restore BACKUP_ID           # backs up the current file too
titan font list
titan font current
titan font set 'JetBrains Mono'
```

`default/config/manifest.json` describes copied-once defaults for tmux, Git,
Neovim, btop, Starship, readline, Foot, Ghostty, Alacritty and Helix. User files
and linked directories are preserved by setup and the existing-install
migration. Explicit reset/restore refuses to write through symlinks. Backups
are private, timestamped and integrity checked under state `config-backups/`.
`config diff` prints file content: run it only when that output is appropriate.

Titan's existing palette catalog now also generates tmux, btop, Neovim palette
data and optional terminal/Helix colors in state `generated/`. Only consumers
that load these defaults use them. Neovim uses original built-in configuration,
with no plugin downloader; it refreshes its palette on focus. Running tmux
clients can reload with prefix+r. Optional terminal configurations load the
generated palette on launch/reload; no application is terminated to apply it.
Fonts are an explicit choice stored in `font.json`, with a monospace Fontconfig
override. User Kitty overrides are still loaded last.

`default/bash/{env,aliases,functions,init}` are sourced by the existing marked
`.bashrc` line. Existing exported editor values, aliases, functions and prompt
choices take priority. Mise, fzf and zoxide activate when installed, in an
interactive shell. Set `TITAN_PROMPT=starship` before sourcing to opt into
Starship. User Bash plugins go in `~/.config/titan/bash/rc.d/*.sh`, loaded last.
Open a new shell to use changed defaults; running applications are left alone.

## Developer utilities

```sh
titan archive compress PATH [OUTPUT.tar.gz]
titan archive extract ARCHIVE [NEW_DIRECTORY]
titan worktree list
titan worktree add feature/name
titan worktree remove PATH [--delete-branch]
titan tmux dev --session project --attach
titan tmux square --session review
titan tmux swarm --session workers --count 4 bash
titan forward start preview my-server 3000 3000
titan forward list
titan forward stop preview
titan watch start sync ./src my-server:Work/src
titan watch list
titan watch stop sync
```

Archives preserve input and refuse existing outputs. Extraction uses Python's
data filter to refuse traversal and escaping links. Worktree removal refuses
local changes; optional branch deletion uses Git's merged-branch check.
`ga` creates a worktree and changes directory, without automatically trusting
its mise config. SSH forwarding uses owned control sockets and localhost
bindings. Rsync watchers use inotify and owned transient user units; they never
delete destination files. Both are explicit session jobs, with no automatic
recreation after reboot. Shell helpers include `compress`, `decompress`, `tdl`,
`tds`, `tsl`, `fip`, `lip`, `dip`, `rsw`, `lsw`, `dsw`, `ga`, `ff` and `mkcd`.

## Media and system commands

```sh
titan transcode ./demo.mov --format mp4 --size 1080p
titan transcode ./photo.webp --format jpg --size medium --copy
titan qr encode 'https://example.org'
titan qr decode ./code.png
titan qr capture                        # selected QR goes only to clipboard
titan clipboard file ./report.pdf
titan clipboard text-file ./notes.txt
titan battery
titan audio status
titan audio default NODE_ID
titan audio volume 40
titan audio mute toggle --input
titan network status
titan network wifi status
titan network edit
titan network qr                        # explicit local Wi-Fi credentials display
titan bluetooth devices
titan bluetooth pair                    # interactive PIN confirmation
titan power current
```

Conversion preserves source and refuses existing output. QR capture doesn't
log decoded contents. Network status omits SSIDs and passwords; `network qr`
is explicitly for viewing credentials locally, never a routine agent check.
Bluetooth pairing stays interactive. Power changes respect the laptop's
always-awake/Performance policy. None of these commands adds an idle daemon.

## Hooks and extensions

User Bash hooks live at `~/.config/titan/hooks/NAME` or `NAME.d/`, run in lexical
order with a 30-second bound per file. `.sample` files are ignored. Named events
are `theme-set ID`, `font-set FAMILY`, `post-setup` and `post-update`; custom
events can be run using `titan hook NAME ARGS…`. Failed hooks report to stderr
and don't undo the primary operation; an explicit `titan hook` exits nonzero
after running the remaining files.

Optional QML plugins use Titan's own schema, with `panel` or `service` kinds:

```json
{"schema":1,"id":"local.demo","name":"Demo","version":"1.0.0",
 "kinds":["service"],"entry":"Main.qml"}
```

```sh
titan plugin validate ./demo
titan plugin install ./demo
titan plugin add https://github.com/OWNER/REPO
titan plugin list
titan plugin enable local.demo
titan plugin disable local.demo
titan plugin remove local.demo
```

Install/add validate files without running plugin code and leave it disabled.
Enabling loads QML in the existing shell; plugins are user-authorized arbitrary
code, not sandboxed. A plugin can declare `property var titanContext` to receive
reactive theme colors, font size and reduced-motion state. Panels create their
own windows; services are nonvisual roots. Removal first disables and moves the
plugin to a state backup. `titan.*` is reserved; entry traversal, symlinks and
special files are refused. This doesn't replace the existing bar or accept
Omarchy's plugin manifests. Updates/cloning built-ins and bar widgets remain
future work recorded in the coverage ledger.

## Menus, modules and exit codes

Super+Space adds Install, Setup and Remove. Searchable lists use the same
catalogs and defaults as the CLI. Package/development actions open a maintenance
terminal for transaction review and local sudo; the panel never holds secrets.
The existing visual design and keyboard chords are preserved.

`bin/titan` routes to distinct scripts and Python modules: `apps`,
`configuration`, `packages`, `development`, `utilities`, `media_tools`,
`system_status`, `services`, `plugins`, with shared primitives in `ops`. New functionality
does not accumulate in the legacy `workflow.py`; it only adapts shortcuts and
menus to shared operations. Help is available at every level. Exit 0 means
success, 1 means an operation failed/refused, 2 means invalid CLI syntax, and
130 means interruption. Read-only plans don't create user state. New structured
status objects include `schema: 1`; UI/catalog arrays are documented arrays.
