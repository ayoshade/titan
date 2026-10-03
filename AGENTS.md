# Titan — agent development guide

## Mission

Build **Titan**, an original, Arch-based, agent-focused Linux distribution. Its
desktop should closely match saneAspect's Quickshell design and interaction
style, with a dark, polished default and deep customization through AI agents.
Use Omarchy as a reference for a cohesive, reproducible, developer-oriented
distribution and agent workflows. Titan has its own identity and implementation.

Codex and Claude share this guide. The user's current instructions take
precedence. `CLAUDE.md` must contain only `@AGENTS.md`; keep project guidance here
instead of maintaining two competing instruction sets.

## Current state and continuity

- The project lives at `~/dotfiles`, a Git repository. This checkout is the
  working prototype, not yet a released distribution or bootable installer.
- **Titan** is the product name. **Umbra** is the existing shell/configuration
  name; `umbra` is also the laptop hostname, and `shade` is the local user.
  Plan a compatible branding migration rather than blindly renaming paths,
  IPC targets, services, namespaces, commands, or the machine's identity.
- Keyboard combinations now match all six Omarchy binding files at commit
  `a85e29abb556816f4644cf975e98da694b486aa8`: 231 active registrations when
  voxtype is absent. Read `docs/keybindings.md` and `docs/workflow.md` before
  changing shortcuts. Super+A/C/V/X are universal editing, Super+L changes
  workspace layout, and Super+Ctrl+L locks. Keep chords exact unless the user
  requests a change. Titan owns the implementation and Quickshell UI.
- `titan` (`scripts/titan`: version, migrate, update, theme, settings) is the
  user-facing command; `titan-shell` (`scripts/titan-shell`) controls the shell;
  `scripts/workflow` is the shared desktop-operation interface; implementations
  live under `lib/titan/`. Workflow packages have their own manifest and installer.
  User state lives outside Git. Clipboard labels contain private content; never
  dump clipboard-list into logs. Optional Omarchy apps are not bundled. Do not
  mistake an assigned shortcut for an installed app or complete feature parity.
- The development laptop runs Arch, systemd-boot, Btrfs, NetworkManager,
  PipeWire/WirePlumber, Bluetooth, power-profiles-daemon and UFW. It has Intel
  graphics and a 1366×768 internal display. Inspect actual hardware before
  assuming that another Titan machine has this configuration.
- Hyprland, Quickshell, Hyprlock, Hypridle, Kitty, Thunar and Firefox are in use.
  Graphical login uses greetd/ReGreet/Cage. The development laptop now uses an
  always-awake, Performance policy: Hypridle is not started, idle display-off is
  disabled, logind ignores lid/sleep events, and all sleep targets are masked.
  See `docs/always-awake.md`; do not re-enable sleep or idle timers without the
  user requesting a policy change. Read `docs/hardware.md` and
  `docs/verification.md` for details and outstanding reliability checks.
- saneAspect findings and feature checklists live in
  `docs/research/island-notch.md` (island, dashboard, calendar) and
  `docs/research/shell-panels.md` (control center, Settings, menus, themes,
  wallpapers); `docs/research/saneaspect-videos.md` tracks which of his videos
  were reviewed and how deeply. Update them with each visual change.
- Hyprlock has had black-screen rendering failures. Authentication has
  succeeded, but reliable lock rendering still needs testing. Suspend/resume testing is
  deferred while the user's always-awake policy is active.
  Do not confuse a successful password check with a verified visible lock screen.

## Start each task

1. Read this guide, `README.md`, `docs/design-reference.md`, and the relevant
   verification notes and source files. Inspect `git status`, diffs and recent
   commits before editing. Read applicable nested agent instructions if present.
2. Identify the user's intended result and continue previously authorized work.
   Inspect installed versions, running services and the current Hyprland session
   when those affect the task. Use `rg` for code/file searches.
3. Explain the next concrete action briefly. Ask for missing requirements only
   when necessary; proceed with routine, reversible work within the user's scope.
4. Work in small, reviewable steps, validate the result, and leave a usable
   desktop. Report what changed, what was verified and what remains unresolved.
5. Update relevant documentation and handoff notes. Record task-owned changes
   in focused commits when appropriate; never stage unrelated user changes.

When Codex and Claude work on the same checkout, preserve each other's work.
Coordinate file ownership if both are active; use separate branches/worktrees
for overlapping changes. Keep durable decisions and unfinished work in repository
documents rather than relying on either agent's conversation history.

## Study saneAspect and reproduce the style

Primary reference: https://www.youtube.com/@saneAspect/videos

The user explicitly wants Codex and Claude to study **all saneAspect videos**
and match his style as faithfully as practical. Treat this as an ongoing research
program, including new uploads, not a claim that the current prototype already
matches everything. Existing research covers only a few videos; consult
`docs/design-reference.md` before repeating it.

- Maintain a durable video inventory under `docs/research/` as research expands:
  URL/ID, title, publication date, topic, review status and notes. Include public
  videos across the channel, not only the latest uploads. Record inaccessible
  entries and review newer relevant desktop videos first while completing the
  remaining catalog over time. Research batches should fit the active task.
- Retrieve available captions/transcripts and inspect actual video frames or
  playback. Captions explain intent; visuals and sequences establish layout,
  animation and interaction. Do not infer an entire desktop from a thumbnail.
- Record timestamps and observations for geometry, typography, palette, spacing,
  radii, shadows, blur, workspace states, island expansion, launcher behavior,
  theme selection, notification grouping, controls and application consistency.
- Compare implemented features with the references at matched scale. Use
  screenshots and interaction checks; keep a feature/deviation checklist.
  Distinguish faithful behavior, adaptations, known gaps and unverified details.
- Never claim to have watched, transcribed or tested material that was not
  actually reviewed. Distinguish full viewing, sampled frames and caption-only
  review. Document access limits and continue useful work with available evidence.
- Keep source links and concise original research notes. Do not redistribute
  entire transcripts, videos, paid course material or proprietary dotfiles.
- Build Titan's own QML, components, assets and integration code. Do not install
  a prebuilt rice or copy another person's dotfiles wholesale. Any reused
  third-party material needs an appropriate license and attribution.

The current visual baseline is black/graphite, muted gray, minimal and futuristic:
centered dynamic island, compact workspace marks, restrained motion, coherent
rounded panels, palette carousel and intentional spacing. Maintain this polished
default while allowing other palettes and user-requested designs. Avoid arbitrary
styling that moves away from the researched reference without documenting why.

Omarchy reference: https://github.com/omacom/omarchy
Study its current public documentation and relevant workflows when designing
Titan's installation, upgrades, customization and agent experience. Record the
specific lessons adopted; verify current behavior instead of guessing.

## Desktop architecture

**Do not use Waybar. Quickshell is Titan's primary desktop shell and UI layer.**

Quickshell should own the bar/island, workspace status, clock/calendar, battery,
network/Bluetooth status and controls, volume, brightness, media, notifications,
tray, launcher, quick settings, theme selection and session/power UI as practical.
Use Hyprlock/Hypridle for locking and idle policy, native Wayland applications,
wl-clipboard, grim/slurp and suitable XDG portals.

- Build the shell as maintainable software: reusable QML components, reactive
  service state, presentation modules, typed IPC and centralized theme tokens.
- Prefer native Quickshell Hyprland, NetworkManager, BlueZ, PipeWire, UPower,
  MPRIS and notification APIs. Use polling only where events are unavailable;
  document why, bound the interval and stop it when the consumer is hidden.
- Keep theme colors, typography, spacing, radii and motion in one source of
  truth. Generate application/compositor colors from the shared palette catalog.
  Never hand-edit generated palette files as the long-term implementation.
- Keep dependency and CPU/memory cost reasonable. Measure when a change affects
  repainting, scanning, artwork, timers or process lifetime. Support reduced
  motion, keyboard navigation, clear focus and accessible control names.
- Treat multi-monitor behavior and different resolutions as product requirements.
  Keep machine-specific backlights, monitor names, users and paths in hardware
  profiles or detected state as the prototype becomes portable.
- Verify APIs against installed versions and official documentation. This
  prototype uses Hyprland Lua configuration; do not introduce legacy syntax
  without checking compatibility. QML runtime checks matter alongside linting.

## Repository map and ownership

| Location | Responsibility |
| --- | --- |
| `config/hypr/` | Compositor, bindings, appearance, locking and idle policy |
| `config/quickshell/umbra/shell.qml` | Shell root, screen lifecycle and IPC |
| `config/quickshell/umbra/services/` | Reactive state and system integrations |
| `config/quickshell/umbra/components/` | Shared UI building blocks |
| `config/quickshell/umbra/modules/` | Feature presentation and panels |
| `config/quickshell/umbra/theme/` | Tokens, palette catalog, preferences and the settings schema |
| `config/kitty/`, `config/gtk-*/` | Application configuration |
| `assets/` | Original wallpapers and other shared assets |
| `packages/` | Explicit package manifests |
| `scripts/` | Installation, bootstrap, checks, session and user operations |
| `system/` | Reviewed templates for privileged system configuration |
| `default/agents/skills/` | Agent skills shipped as Titan defaults (one `SKILL.md` per skill), symlinked into `~/.claude/skills/` and `~/.codex/skills/`; `titan` covers end-user customization, `titan-app` new Qt Quick desktop apps, `diagnose-crash` core dumps |
| `docs/` | Research, hardware, decisions, validation and recovery |

Shell settings are declared once in `theme/settings-schema.json`. The Settings
window, `Settings.qml` and `scripts/workflow settings` all use it; user values
live in `~/.config/titan/settings.json`. Add a setting to the schema
rather than hard-coding a new preference. Theme wallpapers live outside Git in
`~/Pictures/Wallpapers/<theme>/` (downloaded third-party images; never commit
them).

Titan separates three layers (see `docs/distribution.md`): **defaults** in the
checkout (later the package); the **user layer** `~/.config/titan/`
(`preferences.json` theme/accent, `settings.json`, `hypr.lua`, `kitty.conf`
overrides), which updates never overwrite; and **machine state**
`~/.local/state/titan/` (generated theme files, runtime overrides, applied
migration markers). `scripts/apply-theme` writes generated Kitty/Hyprland files
into state and the choice into the user layer, so theme changes no longer
dirty Git. Layout changes to existing installs ship as numbered, idempotent
scripts in `migrations/`, run by `titan migrate` (and `titan update`).
Packaging lives in `packaging/` (`titan`, `titan-desktop`); `titan setup` is
shared first-run setup; `titan-session` is the login session; build a repository
with `scripts/build-repo` and test packages only in a VM (`scripts/vm-test`).
Titan is Apache-2.0 (`LICENSE`, `NOTICE`: record any third-party material
there). `scripts/publish-repo` publishes GitHub releases. Publishing is public:
run it with `--yes` only when the owner asks, and never handle the signing key
or its passphrase.
Never hard-code `~/dotfiles`: Lua uses the `TITAN_ROOT` global, shell QML uses
`Paths.root`/`Paths.script()`, and scripts resolve their own location.
Snapshots: `scripts/install-snapshots` (user runs it with sudo; `--dry-run` is
safe for agents) enables Snapper and snap-pac on the Btrfs root; recovery is in
`docs/snapshots.md`. Never roll back or delete snapshots without the user.

As Titan grows, separate distribution defaults, machine profiles, persistent
user overrides, runtime state and build outputs. Updates must preserve user
customizations. Do not reorganize the live symlinked configuration without a
migration and recovery path. Keep `~/dotfiles` as the personal source checkout;
remove hardcoded checkout assumptions from future packaged installations.

## Make Titan customizable through agents

Agent support is a product feature. A user should be able to describe a change
in natural language and have an agent inspect, implement, validate, explain and
reverse it using documented Titan interfaces.

- Design stable commands for status/diagnostics, theme operations, shell reload,
  configuration inspection, validation, backup and recovery. Add structured
  output and meaningful exit codes where agents need to consume results.
- Use schemas, declarative preferences and documented extension points for
  themes, widgets, shortcuts, applications and profiles. Agents should not need
  to patch unrelated internals for ordinary customization.
- Have UI controls and agent commands call the same underlying operations.
  Keep preview, apply and restore behavior explicit and reproducible.
- Provide project context, task recipes and concise customization examples for
  Codex, Claude and other agents. Avoid tying core desktop behavior to a single
  provider, subscription, model, network connection or running AI daemon.
- Preserve user ownership: reviewable diffs, atomic writes where possible,
  backups before replacement, validation before activation and recovery without
  an agent. Existing user overrides take priority over distro defaults.
- Keep credentials and private data out of source control, prompts and logs.
  Authenticate locally; agents should not request passwords in chat or require
  unrestricted root access for routine customization.
- Optional agent integrations must have documented installation, configuration
  and removal. Core desktop and recovery tools must remain usable without them.

## Build and maintain a distribution

Progress from this working prototype to a reproducible Arch-based installation,
then tested upgrades and hardware profiles, then VM-tested release artifacts.
Document what exists today versus what is planned; do not label unbuilt features
as complete. Prioritize a dependable daily desktop and agent customization APIs
before adding broad application bundles or installation media.

- Keep package manifests, scripts and configuration under version control.
  Bootstrap should be idempotent and refuse silent replacement of user files.
  Avoid Arch partial upgrades; review package availability and transactions.
- Separate privileged system operations from ordinary user configuration.
  Provide concrete, inspectable scripts when local sudo authentication is needed.
- Design versioned, repeatable migrations, upgrade checks and rollback paths.
  Preserve compatibility for renamed commands/configuration and existing users.
- Use explicit dependencies and trusted sources. Record licenses and provenance
  before distributing code, artwork, fonts or bundled agent tools.
- Build and test installation/ISO work in a VM or isolated environment first.
  Document build inputs, supported hardware, installation steps, release notes
  and recovery. Never experiment with disk installers on this daily-use laptop.

## Safety on the development machine

Inspect before changing system state. Do not repartition, change filesystem
layout, modify the bootloader, reinstall the OS or remove working networking.
Ask before destructive actions. Preserve working display login, firewall, audio
and recovery access. Never reboot, log out, suspend or terminate the user's
applications merely to finish a test without the user's authorization.

Use the user's existing authorization for routine reversible work; do not ask
again for each small edit. Present concrete changes before requesting any new
approval. Do not bypass privilege requirements or pass secrets through logs.

## Validate and hand off

- Run `scripts/doctor` when changing managed configuration/packages/scripts.
  Validate Hyprland configuration and check live `hyprctl configerrors` when
  compositor changes are made. Check Bash syntax for scripts.
- Check QML syntax with `qmllint` before saving. Quickshell hot-reloads saved
  files, so a syntax error immediately shows an error banner in the live shell.
  New IPC functions need `scripts/shell-restart`.
- Check QML syntax and load the affected UI in the actual Wayland session.
  Inspect runtime logs and affected panels. Static QML type warnings are not
  the same as runtime failures; report the distinction honestly.
- Test meaningful behavior: filtering/navigation, applying and restoring a
  theme, restart persistence, notification actions, profile boundaries or
  migration repeatability as relevant. Avoid tests that only mirror code.
- Use `scripts/shell-restart` to replace the desktop shell through Hyprland.
  Quickshell 0.3.1 can deadlock while exiting; the script escalates to TERM and
  KILL so the lock is released. Do not restart immediately after saving QML
  (the hot reload and the restart can race); wrap `qs ipc` calls in `timeout`.
  Preserve the current session and restore temporary test changes. Check
  existing user choices before taking or restoring a test baseline.
- Capture UI-only reference screenshots when useful; avoid committing screenshots
  of terminals, private applications or credentials. State exactly what was
  visually inspected and what requires hands-on hardware testing.
- Run `git diff --check` and review the final diff. Update verification notes,
  interface documentation and operating instructions for changed behavior.
- Finish with a concise result, usage instructions, validation evidence and
  material limitations. Leave durable next steps so either agent can resume.

Keep this guide accurate as Titan evolves. New names, commands, architecture and
release workflows must be reflected here rather than becoming unwritten lore.
