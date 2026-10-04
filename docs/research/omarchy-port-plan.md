# Omarchy command port plan

Source revision: `5c4da021469517449770579793b37ce26d0a0d48`.

Source triage of summaries, function/option names and lexical command references; not a line-by-line behavioral or acceptance review.

All 299 originally pending commands were triaged; partial equivalents and power-policy differences are included too. The report reads the full source files to extract lexical references and line counts. References can occur in comments, embedded programs or data; they are leads for behavioral review, not a verified call graph. A batch assignment never upgrades implementation or acceptance status.

Regenerate with `tools/audit-omarchy ~/.cache/titan/references/omarchy --plan --write`. Do not edit this generated report; edit the batch specification and coverage mapping.

Shell and QML are the primary implementation languages. Existing Python APIs remain supported during focused migrations. Developer analysis and tests may use Python. No language-statistics exclusions are introduced.

| Batch | Pending | Partial | Policy |
| --- | ---: | ---: | ---: |
| [Boot, snapshots and installed-system recovery](#boot) | 13 | 8 | 0 |
| [Packages, channels, upgrades and migrations](#updates) | 22 | 7 | 0 |
| [Agent launch, accounts, usage and optional runtimes](#agents) | 33 | 1 | 0 |
| [Theme lifecycle, palettes, applications and branding](#themes) | 36 | 9 | 0 |
| [Authentication, privilege and SSH service lifecycle](#security) | 14 | 0 | 0 |
| [Detection, monitors, input, audio tuning and power](#hardware) | 42 | 17 | 2 |
| [Optional service lifecycle and file sharing](#services) | 19 | 2 | 0 |
| [Developer environments, config recovery and workspace jobs](#developer) | 15 | 3 | 0 |
| [Application bundles, browser integration, gaming and launchers](#apps) | 45 | 28 | 0 |
| [Plugin manifest, catalog, cloning and updates](#plugins) | 4 | 6 | 0 |
| [Capture, media, dictation and picker workflows](#capture) | 8 | 12 | 0 |
| [Shell surfaces, notifications, toggles, state and watchers](#desktop) | 36 | 12 | 4 |
| [Shared command primitives and distribution diagnostics](#core) | 4 | 2 | 0 |

<a id="boot"></a>

## Boot, snapshots and installed-system recovery

Owner/language: Shell; isolate privileged target operations from per-user UI.

Prerequisites: existing Titan foundation.

Fresh opt-in Limine installation/refresh, matched-kernel read-only overlay previews and confirmed offline restore with retained roots/boot files and durable interruption recovery exist in QEMU. Next: automatic Snapper menu synchronization and bounded capacity. Encryption, hibernation, direct UKI boot and factory reset need separate fixtures.

Acceptance: Fresh UEFI disk boot with ISO detached; real kernel and bootloader upgrades; preserved custom settings; snapshot boot with matching kernel/modules; explicit restore and failed-boot recovery. No host disk or bootloader changes.

| Reference command | Status | Source lines | Behavior to review | Lexical references |
| --- | --- | ---: | --- | --- |
| `omarchy-apply-lock` | partial | 60 | Configure Quickshell lock screen authentication | `shell` |
| `omarchy-apply-system` | partial | 102 | Apply Omarchy system setup in the installed target | `apply-hardware` |
| `omarchy-drive-password` | pending | 32 | Set a new encryption password for a drive selected. | `drive-select` |
| `omarchy-hibernation-available` | pending | 19 | Check if hibernation is supported | — |
| `omarchy-hibernation-remove` | pending | 54 | Remove hibernation setup including swap and boot resume settings | — |
| `omarchy-hibernation-setup` | pending | 166 | Set up hibernation with swap and boot resume configuration | `cmd-missing`, `system-reboot` |
| `omarchy-plymouth-current` | partial | 20 | Show which theme is styling the Plymouth boot screen | `plymouth-list`, `plymouth-set`, `theme-dir` |
| `omarchy-plymouth-list` | partial | 13 | List themes that can style the Plymouth boot screen | `theme-dir` |
| `omarchy-plymouth-preview` | pending | 76 | Preview a Plymouth boot screen with custom colors and logo | — |
| `omarchy-plymouth-reset` | partial | 9 | Restore the default Omarchy Plymouth boot theme and SDDM login screen | `refresh-plymouth`, `refresh-sddm` |
| `omarchy-plymouth-set` | partial | 381 | Set the Plymouth boot theme colors and logo | `cmd-present` |
| `omarchy-plymouth-set-by-theme` | pending | 53 | Set the Plymouth boot theme from an Omarchy theme | `plymouth-set`, `theme-dir` |
| `omarchy-plymouth-switcher` | pending | 20 | Open the Plymouth unlock screen switcher | `menu-images`, `plymouth-current`, `plymouth-list`, `theme-dir` |
| `omarchy-provision-owner` | pending | 1139 | First-boot provisioning: create the user on a machine installed in deferred provisioning | `apply-system`, `provision-user`, `system-factory-reset` |
| `omarchy-refresh-limine` | partial | 19 | Overwrite the user config for the Limine bootloader and rebuild it. | — |
| `omarchy-refresh-plymouth` | pending | 8 | Overwrite the user config for the Plymouth drive decryption and boot sequence with the Omarchy default and rebuild it. | `plymouth-set` |
| `omarchy-refresh-sddm` | pending | 8 | Refresh the SDDM theme from default | `plymouth-set` |
| `omarchy-setup-direct-boot` | pending | 61 | Add or remove an EFI boot entry for the Omarchy UKI, allowing the system to boot directly | — |
| `omarchy-snapshot` | partial | 49 | Create or restore system snapshots with snapper | `cmd-missing`, `update`, `version` |
| `omarchy-system-factory-reset` | pending | 452 | Factory-reset this machine back to its freshly-installed state | `cmd-present`, `hibernation-setup`, `provision-owner`, `system-factory-reset-finish` |
| `omarchy-system-factory-reset-finish` | pending | 168 | First-boot worker that finishes an omarchy-system-factory-reset reset | `system-factory-reset` |

<a id="updates"></a>

## Packages, channels, upgrades and migrations

Owner/language: Shell. Keep versioned migrations and compatible public command paths.

Prerequisites: boot.

Local read-only readiness/status and private atomic update-stage records exist; failures stop later required stages and worker-held locks/interruption/retry are VM-tested. Next: detached transactions, keyring/channel validation, restart advice and failure recovery. Review cache/orphan/AUR/mise handling independently; the Omarchy quattro migration is source-specific and needs Titan lifecycle design rather than literal reproduction.

Acceptance: VM full upgrades, lock contention, low space, interrupted transactions, preserved user choices and recoverable errors; no implicit reboot, forced conflict overwrite or unrequested removal.

| Reference command | Status | Source lines | Behavior to review | Lexical references |
| --- | --- | ---: | --- | --- |
| `omarchy-channel-current` | pending | 30 | Print the active Omarchy package channel | `version-channel` |
| `omarchy-channel-set` | pending | 150 | Set the Omarchy package channel. | `dev-link`, `dev-unlink`, `refresh-pacman`, `security-functions`, `state`, `update`, `update-pacman` |
| `omarchy-migrate` | partial | 102 | Run pending Omarchy migrations. | `notification-dismiss` |
| `omarchy-migrate-notify` | partial | 60 | Notify the user when Omarchy has pending migrations | `launch-floating-terminal-with-presentation`, `migrate`, `notification-send`, `notification-wait`, `update` |
| `omarchy-refresh-pacman` | pending | 50 | Overwrite the package configuration for /etc/pacman with the Omarchy default of using its dedicated mirrors and repositories, then update all packages. | `hook`, `security-functions`, `update-pacman` |
| `omarchy-reinstall-pkgs` | pending | 18 | Reinstall all default Omarchy packages from the stable channel | `refresh-pacman`, `update-pacman` |
| `omarchy-update` | partial | 160 | Update Omarchy and system packages | `hook`, `migrate`, `security-functions`, `snapshot`, `update-analyze-logs`, `update-aur-pkgs`, `update-confirm`, `update-dev`, `update-keyring`, `update-lock`, `update-mise`, `update-orphan-pkgs`, `update-pkg-prune`, `update-requires-free-space`, `update-restart`, `update-status`, `update-stay-awake`, `update-system-pkgs` |
| `omarchy-update-analyze-logs` | pending | 13 | Check the update log for known failure conditions | `update` |
| `omarchy-update-aur-pkgs` | pending | 21 | Update AUR packages if any are installed | `pkg-aur-accessible` |
| `omarchy-update-available` | pending | 44 | Check whether Omarchy updates are available. | — |
| `omarchy-update-confirm` | pending | 18 | Prompt for confirmation before starting an update | — |
| `omarchy-update-dev` | pending | 21 | Update the active Omarchy dev checkout | — |
| `omarchy-update-firmware` | pending | 18 | Update system firmware using fwupd. Ensures the fwupd EFI binary is installed | `cmd-missing`, `pkg-add` |
| `omarchy-update-keyring` | pending | 31 | Ensure the Omarchy and Arch keyring packages are installed and populated | `pkg-add`, `pkg-missing`, `update`, `update-system-pkgs` |
| `omarchy-update-lock` | partial | 47 | Run a command while holding the Omarchy update lock | `update` |
| `omarchy-update-orphan-pkgs` | pending | 29 | Review and optionally remove orphaned system packages after updates | — |
| `omarchy-update-pacman` | pending | 25 | Run a pacman transaction for the Omarchy update flow, shielded from desktop session teardown. | — |
| `omarchy-update-pacman-guard` | pending | 64 | Prevent direct pacman system upgrades from bypassing omarchy update. | — |
| `omarchy-update-restart` | pending | 66 | Prompt for required reboot or service restarts after updates | `restart-shell`, `state`, `system-reboot` |
| `omarchy-update-status` | pending | 12 | Refresh the shell update status | `shell`, `update-available` |
| `omarchy-update-stay-awake` | pending | 596 | Manage sleep and idle inhibition during an update | `security-functions`, `toggle-idle`, `update` |
| `omarchy-update-system-pkgs` | partial | 39 | Update system packages with pacman | `update-pacman`, `update-system-pkgs-when-conflicted` |
| `omarchy-update-system-pkgs-when-conflicted` | pending | 115 | Retry a system package update that hit a conflict | `update-system-pkgs` |
| `omarchy-update-time` | pending | 7 | Restart system time synchronization | — |
| `omarchy-update-user-notify` | pending | 6 | Compatibility wrapper for omarchy-migrate-notify. | `migrate-notify` |
| `omarchy-upgrade-to-quattro` | pending | 2462 | Upgrade a legacy Omarchy install to the package-backed Omarchy quattro layout. | `apply-lock`, `bar`, `cmd-present`, `dev-link`, `done`, `menu`, `migrate`, `refresh-applications`, `restart-terminal`, `restart-xcompose`, `shell`, `snapshot`, `system-sleep-monitor`, `theme-set`, `theme-set-browser`, `update`, `update-aur-pkgs`, `update-available`, `update-mise`, `version-channel` |
| `omarchy-version` | partial | 28 | Print the installed Omarchy version | — |
| `omarchy-version-branch` | partial | 18 | Print the active Omarchy dev-link git branch | — |
| `omarchy-version-channel` | pending | 29 | Print the active Omarchy mirror and package channel | — |

<a id="agents"></a>

## Agent launch, accounts, usage and optional runtimes

Owner/language: Shell orchestration and QML views; provider protocols require a documented implementation decision.

Prerequisites: apps, core.

Current agent selection/launch/skills are a base. Separate account registry, authenticated provider usage, process environments, provider installers and gateways. Never inherit upstream permission-bypass switches or copy credentials into logs.

Acceptance: Isolated fake profiles plus explicit real-login checks where authorized; launch arguments stay exact; concurrent account state and stale/offline usage handling; removal preserves user data unless separately requested.

| Reference command | Status | Source lines | Behavior to review | Lexical references |
| --- | --- | ---: | --- | --- |
| `omarchy-agent` | pending | 160 | Launch the default coding agent in a terminal | `agent-account-home`, `agent-prompt`, `cmd-missing`, `default-agent`, `launch-openclaw`, `launch-tui`, `menu` |
| `omarchy-agent-account-add` | pending | 223 | Sign in to a Claude, Codex, or Grok subscription | `agent-account-state`, `agent-usage-update`, `cmd-missing`, `default-agent`, `launch-browser`, `notification-send` |
| `omarchy-agent-account-home` | pending | 18 | Print the config home of the active Claude, Codex, or Grok account | `agent-account-state` |
| `omarchy-agent-account-list` | pending | 58 | List Claude, Codex, and Grok subscription accounts and their limits | `agent-account-state` |
| `omarchy-agent-account-mode` | pending | 30 | Switch Claude, Codex, or Grok accounts automatically near a limit, or only notify | `agent-account-state`, `default-agent` |
| `omarchy-agent-account-remove` | pending | 30 | Forget an added Claude, Codex, or Grok account | `agent-account-state`, `agent-usage-update`, `default-agent` |
| `omarchy-agent-account-rename` | pending | 24 | Rename a Claude, Codex, or Grok subscription account | `agent-account-state`, `agent-usage-update`, `default-agent` |
| `omarchy-agent-account-state` | pending | 787 | Read and change the registry of Claude, Codex, and Grok subscription accounts | `agent-account-use`, `notification-send` |
| `omarchy-agent-account-use` | pending | 39 | Choose which Claude, Codex, or Grok account new sessions use | `agent-account-state`, `agent-usage-update`, `default-agent`, `notification-send` |
| `omarchy-agent-crash` | partial | 52 | Diagnose a crashed process with the default coding agent | `agent` |
| `omarchy-agent-prompt` | pending | 23 | Launch the default coding agent with a prompt | `agent` |
| `omarchy-agent-usage-claude` | pending | 1306 | Print the Claude Code usage record as JSON | — |
| `omarchy-agent-usage-codex` | pending | 1077 | Print the Codex usage record as JSON | `mise-install` |
| `omarchy-agent-usage-fireworks` | pending | 558 | Print the Fireworks usage record as JSON | — |
| `omarchy-agent-usage-grok` | pending | 361 | Print the Grok usage record as JSON | — |
| `omarchy-agent-usage-update` | pending | 89 | Regenerate the AI agent usage data files | `agent-account-state` |
| `omarchy-install-ai-chatgpt` | pending | 15 | Install the ChatGPT desktop app | `pkg-add` |
| `omarchy-install-ai-claude` | pending | 15 | Install the Claude desktop app | `pkg-add` |
| `omarchy-install-ai-hermes` | pending | 20 | Install the Hermes desktop app | `install-hermes-cli` |
| `omarchy-install-ai-openclaw` | pending | 35 | Install the OpenClaw agent platform and its Control UI web app | `install-openclaw-cli`, `launch-openclaw`, `openclaw-onboard`, `webapp-install` |
| `omarchy-install-ai-t3-code` | pending | 31 | Install T3 Code and point it at the Omarchy palette | `pkg-add`, `theme-refresh`, `theme-set-t3code` |
| `omarchy-install-hermes-cli` | pending | 544 | Install Hermes Desktop for the default agent; its runtime provides the hermes command | `agent`, `cmd-missing`, `install-ai-hermes`, `pkg-add`, `pkg-present`, `theme-set-hermes` |
| `omarchy-install-openclaw-cli` | pending | 271 | Install OpenClaw for the default agent as the self-updating copy under ~/.openclaw | `agent`, `install-hermes-cli`, `pkg-add`, `pkg-present` |
| `omarchy-launch-openclaw` | pending | 91 | Open the OpenClaw Control UI (or its terminal UI with --tui), onboarding or starting the gateway first when needed. | `launch-floating-terminal-with-presentation`, `launch-webapp`, `openclaw-onboard` |
| `omarchy-openclaw-onboard` | pending | 134 | Run OpenClaw's setup wizard the way Omarchy needs it: in the terminal, installing the gateway as a user service, and returning when it is done. | — |
| `omarchy-remove-ai-chatgpt` | pending | 17 | Remove the ChatGPT desktop app along with its configuration and caches. | `pkg-drop` |
| `omarchy-remove-ai-claude` | pending | 23 | Remove the Claude desktop app along with its configuration and caches. | `pkg-drop` |
| `omarchy-remove-ai-grok-bot` | pending | 16 | Remove Grok Bot along with its settings and data. | `pkg-drop` |
| `omarchy-remove-ai-hermes` | pending | 241 | Remove the Hermes desktop app along with the Hermes runtime it installed. | `pkg-drop` |
| `omarchy-remove-ai-lm-studio` | pending | 29 | Remove LM Studio along with its configuration and every model it downloaded. | `pkg-drop` |
| `omarchy-remove-ai-ollama` | pending | 18 | Remove Ollama along with every model it pulled. | `pkg-drop` |
| `omarchy-remove-ai-openclaw` | pending | 88 | Remove the OpenClaw agent platform along with its gateway service and web app. | `install-ai-openclaw`, `pkg-drop` |
| `omarchy-remove-ai-perplexity` | pending | 49 | Remove the Perplexity desktop app along with its runtime caches. | `pkg-drop` |
| `omarchy-remove-ai-t3-code` | pending | 18 | Remove T3 Code along with its configuration and workspaces. | `pkg-drop` |

<a id="themes"></a>

## Theme lifecycle, palettes, applications and branding

Owner/language: Shell for lifecycle/rendering orchestration; QML for chooser, previews and reactive consumers.

Prerequisites: core, apps.

Finish import/install/update/remove, validated palette/template schema and application reloads; preserve the graphite baseline. Separate cross-machine sync and hardware RGB adapters. Omarchy templates and fonts cannot be used as Titan runtime dependencies.

Acceptance: Import a new theme, reject invalid or linked files, update and remove safely, restore original preferences, and inspect real app rendering/reload. Font switching and screenshots at matched scale.

| Reference command | Status | Source lines | Behavior to review | Lexical references |
| --- | --- | ---: | --- | --- |
| `omarchy-ascii` | pending | 1217 | Render text as ASCII art in the font the Omarchy logo is drawn in | — |
| `omarchy-branding-about` | pending | 28 | Edit, set, or reset About branding | `file-select`, `launch-about`, `launch-editor`, `transcode-ascii` |
| `omarchy-branding-about-animation` | pending | 104 | Shared helpers for animating the About branding (source this, don't run it). | — |
| `omarchy-branding-screensaver` | pending | 28 | Edit, set, or reset screensaver branding | `file-select`, `launch-editor`, `launch-screensaver`, `transcode-ascii` |
| `omarchy-dev-benchmark-theme-switcher` | pending | 160 | Measure theme switcher cache and selector prep times | `menu-images`, `theme-switcher` |
| `omarchy-dev-font` | pending | 652 | Add branded glyphs to the Omarchy icon font | — |
| `omarchy-dev-theme-preview` | pending | 439 | Preview an Omarchy theme palette in the terminal | `theme-color`, `theme-osc` |
| `omarchy-install-font` | pending | 21 | Install a Nerd Font package and switch the system to it | `font-set`, `launch-floating-terminal-with-presentation`, `pkg-add` |
| `omarchy-theme-bg-cache` | pending | 10 | Cache background switcher thumbnails for the current theme | `menu-images` |
| `omarchy-theme-bg-current` | partial | 12 | Show current background | — |
| `omarchy-theme-bg-install` | pending | 9 | Open the current theme's user background folder | — |
| `omarchy-theme-bg-next` | partial | 49 | Cycle to the next background for the current theme | `notification-send`, `theme-bg-set` |
| `omarchy-theme-bg-set` | partial | 25 | Set the current background image or video | `shell` |
| `omarchy-theme-bg-switcher` | pending | 14 | Open the Omarchy background switcher | `menu-images` |
| `omarchy-theme-color` | pending | 304 | Resolve semantic colors from an Omarchy theme colors.toml | `theme-set-templates` |
| `omarchy-theme-colors-from-alacritty` | pending | 151 | Generate a theme's colors.toml from its alacritty.toml palette | — |
| `omarchy-theme-current` | partial | 12 | Show current theme | — |
| `omarchy-theme-dir` | pending | 18 | Print the directory holding a theme, preferring a user-installed copy | — |
| `omarchy-theme-extras` | pending | 17 | List the user-installed themes that came from a git clone | — |
| `omarchy-theme-install` | pending | 63 | Install a theme from a git repository | `git-url-check`, `plugin-add`, `theme-set` |
| `omarchy-theme-list` | partial | 9 | List available themes | — |
| `omarchy-theme-osc` | pending | 33 | Print OSC sequences for an Omarchy color theme | `theme-color` |
| `omarchy-theme-refresh` | pending | 9 | Refresh the current theme from its templates. | `theme-set` |
| `omarchy-theme-remove` | pending | 39 | Remove a user-installed theme | `menu-select`, `notification-send` |
| `omarchy-theme-set` | partial | 451 | Apply an Omarchy theme | `hook`, `notification-send`, `restart-btop`, `restart-helix`, `restart-hyprctl`, `restart-opencode`, `restart-terminal`, `shell`, `theme-bg-cache`, `theme-colors-from-alacritty`, `theme-extras`, `theme-set-browser`, `theme-set-claude`, `theme-set-foot`, `theme-set-gnome`, `theme-set-herdr-machines`, `theme-set-hermes`, `theme-set-hunk`, `theme-set-keyboard`, `theme-set-obsidian`, `theme-set-pi`, `theme-set-t3code`, `theme-set-templates`, `theme-set-tmux`, `theme-set-vscode` |
| `omarchy-theme-set-browser` | pending | 94 | Apply the current theme color to Chromium, Chrome, Edge, and Brave | `cmd-present`, `theme-set-browser-policy` |
| `omarchy-theme-set-browser-policy` | pending | 123 | Write the current theme color into the browser policy directories | — |
| `omarchy-theme-set-claude` | pending | 74 | Sync the generated Omarchy theme to Claude Code | `theme-refresh` |
| `omarchy-theme-set-foot` | partial | 20 | Apply current Omarchy theme colors to running Foot terminals | `theme-osc` |
| `omarchy-theme-set-gnome` | partial | 34 | Apply the current theme to GNOME color mode and icon settings | `theme-color` |
| `omarchy-theme-set-herdr-machines` | pending | 75 | Mirror the current theme to your herdr machines that run Omarchy | `theme-set`, `toggle-enabled` |
| `omarchy-theme-set-hermes` | pending | 234 | Sync the generated Omarchy theme to Hermes as a skin | `install-hermes-cli`, `pkg-present`, `theme-refresh` |
| `omarchy-theme-set-hunk` | pending | 14 | Tell running Hunk sessions to pick up the new terminal colors | — |
| `omarchy-theme-set-keyboard` | pending | 7 | Apply the current theme keyboard color to supported keyboards | `theme-set-keyboard-asus-rog`, `theme-set-keyboard-f16` |
| `omarchy-theme-set-keyboard-asus-rog` | pending | 12 | Apply the current theme keyboard color to ASUS ROG keyboards | `cmd-present` |
| `omarchy-theme-set-keyboard-f16` | pending | 28 | Apply the current theme keyboard color to Framework Laptop 16 keyboards | `cmd-present` |
| `omarchy-theme-set-obsidian` | pending | 28 | Sync Omarchy theme to all Obsidian vaults | — |
| `omarchy-theme-set-pi` | pending | 76 | Sync the generated Omarchy Pi theme | `theme-refresh` |
| `omarchy-theme-set-t3code` | pending | 34 | Sync the generated Omarchy theme to T3 Code | — |
| `omarchy-theme-set-templates` | pending | 453 | Generate themed config files from Omarchy templates | `theme-color` |
| `omarchy-theme-set-tmux` | partial | 120 | Sync current Omarchy theme environment into tmux | `theme-color`, `theme-osc` |
| `omarchy-theme-set-vscode` | pending | 163 | Sync Omarchy theme to VS Code, VSCodium, and Cursor | `cmd-present`, `theme-set`, `toggle-enabled` |
| `omarchy-theme-switcher` | pending | 130 | Open the Omarchy theme switcher | `menu-images` |
| `omarchy-theme-update` | pending | 10 | Update user-installed git themes | `theme-extras` |
| `omarchy-toggle-theme-sync` | pending | 11 | Toggle mirroring theme changes to and from your herdr machines | `notification-send`, `toggle`, `toggle-enabled` |

<a id="security"></a>

## Authentication, privilege and SSH service lifecycle

Owner/language: Shell with reviewed privileged templates and root validation.

Prerequisites: core, services.

Add SSH agent/server lifecycle, FIDO2/fingerprint PAM setup/removal and command-scoped privilege contracts. Passwordless sudo and Docker-group access change security boundaries; expose explicit choices rather than enabling them through a broad port.

Acceptance: Disposable VM PAM/sudo validation and refusal paths before hardware tests; preserve a recovery login; track owned firewall rules and authorized keys; no secret or key output.

| Reference command | Status | Source lines | Behavior to review | Lexical references |
| --- | --- | ---: | --- | --- |
| `omarchy-remove-security-fido2` | pending | 40 | Remove FIDO2 authentication from sudo and polkit | `pkg-drop` |
| `omarchy-remove-security-fingerprint` | pending | 57 | Remove fingerprint authentication from sudo, polkit, and lock screen | `hw-laptop-closed`, `pkg-drop` |
| `omarchy-remove-security-sshd` | pending | 38 | Disable the OpenSSH server, remove standard firewall rules, and optionally remove authorized keys | `cmd-present` |
| `omarchy-remove-security-sudoless-docker` | pending | 34 | Disable sudoless Docker by removing your user from the docker group | `state`, `sudo-docker`, `system-reboot`, `update-restart` |
| `omarchy-remove-service-ssh-agent` | pending | 16 | Disable the gcr-ssh-agent SSH agent and its environment override. | — |
| `omarchy-security-functions` | pending | 137 | Provide internal helpers for command-scoped sudo authentication | — |
| `omarchy-setup-security-fido2` | pending | 148 | Set up FIDO2 authentication for sudo and polkit | `pkg-add`, `remove-security-fido2` |
| `omarchy-setup-security-fingerprint` | pending | 111 | Set up fingerprint authentication for sudo, polkit, and lock screen | `hw-fingerprint`, `hw-laptop-closed`, `pkg-missing` |
| `omarchy-setup-security-ssh-agent` | pending | 17 | Enable an SSH agent (gcr-ssh-agent) that prompts for key passphrases graphically. | — |
| `omarchy-setup-security-sshd` | pending | 212 | Set up the OpenSSH server, open the firewall, and authorize an SSH key | `cmd-missing`, `pkg-add` |
| `omarchy-setup-security-sudoless-docker` | pending | 49 | Enable sudoless Docker by adding your user to the docker group (root-equivalent!) | `remove-security-sudoless-docker`, `state`, `sudo-docker`, `system-reboot`, `update-restart` |
| `omarchy-sudo-docker` | pending | 44 | Succeed when Docker needs sudo, fail when it can be used directly | — |
| `omarchy-sudo-keepalive` | pending | 9 | Prompt for sudo once and keep the credential alive in the background. | — |
| `omarchy-sudo-passwordless` | pending | 449 | Toggle passwordless sudo for the current user. | `security-functions` |

<a id="hardware"></a>

## Detection, monitors, input, audio tuning and power

Owner/language: Shell for detected system operations; QML/native services for reactive state; Lua compositor rules.

Prerequisites: core.

Extend conservative hardware profiles and safe display recovery, DDC/Apple brightness, input and audio adapters. Distinguish read-only predicates from driver/sysfs mutations. Portable power policy must not alter the owner's always-awake policy.

Acceptance: VM monitor fixtures plus explicitly documented physical-device tests; unplug recovery, no available internal-output lockout, profile matching, audio/output checks and reduced-motion paths.

| Reference command | Status | Source lines | Behavior to review | Lexical references |
| --- | --- | ---: | --- | --- |
| `omarchy-apply-hardware` | partial | 75 | Apply Omarchy hardware-specific packages and system configuration | `apply-system` |
| `omarchy-audio-sink-availability` | pending | 54 | Print PulseAudio sink availability for the shell | `audio-tuning` |
| `omarchy-audio-tuning` | pending | 357 | Manage the speaker tuning for this laptop | `audio-output-sink`, `hw-match`, `restart-audio` |
| `omarchy-brightness-display` | partial | 122 | Show or adjust brightness on the focused display. | `brightness-display-apple`, `brightness-display-ddc`, `hw-display`, `hyprland-monitor-focused`, `hyprland-monitor-focused-apple`, `osd` |
| `omarchy-brightness-display-apple` | pending | 107 | Show or adjust Apple Studio Display and Apple XDR Display brightness using asdcontrol. | `osd` |
| `omarchy-brightness-display-ddc` | pending | 168 | Show or adjust DDC/CI display brightness for a Hyprland monitor. | — |
| `omarchy-brightness-keyboard` | partial | 58 | Adjust keyboard backlight brightness using available steps. | `osd` |
| `omarchy-brightness-keyboard-mute` | partial | 14 | Set the mic-mute indicator LED on laptops that expose a platform::micmute LED node. | — |
| `omarchy-display-text-size` | partial | 236 | Scale text everywhere — omarchy shell, GTK apps, and terminals | `cmd-present`, `font-set`, `notification-send` |
| `omarchy-hw-asus-expertbook-b9406` | pending | 5 | Detect ASUS ExpertBook B9406 series laptops on Intel Panther Lake. | `hw-intel-ptl`, `hw-match` |
| `omarchy-hw-asus-rog` | pending | 6 | Detect whether the computer is an Asus ROG machine. | — |
| `omarchy-hw-asus-zenbook-ux5406aa` | pending | 5 | Detect ASUS Zenbook UX5406AA series laptops on Intel Panther Lake. | `hw-intel-ptl`, `hw-match` |
| `omarchy-hw-clamshell` | pending | 7 | Returns true when clamshell mode is active | `hw-external-monitors`, `hw-laptop-closed` |
| `omarchy-hw-dell-xps-haptic-touchpad` | pending | 5 | Match Dell XPS systems with the Synaptics haptic touchpad. | `hw-match` |
| `omarchy-hw-dell-xps-oled` | pending | 7 | Match Dell XPS systems with LG OLED panel on Intel Panther Lake (Xe3) GPU. | `hw-intel-ptl`, `hw-match` |
| `omarchy-hw-dell-xps13-sidecar-amps` | pending | 8 | Match the Dell XPS 13 DX13260 that requires the sidecar amplifier workaround. | `hw-match` |
| `omarchy-hw-display` | pending | 25 | Print the most likely display backlight device. | — |
| `omarchy-hw-elgato-camlink-4k` | pending | 5 | Detect whether an Elgato Cam Link 4K is plugged in. | — |
| `omarchy-hw-external-monitors` | pending | 12 | Returns true when an external monitor is physically connected. | — |
| `omarchy-hw-fingerprint` | pending | 56 | Returns true when a fingerprint reader is present | — |
| `omarchy-hw-framework16` | pending | 6 | Detect whether the computer is a Framework Laptop 16. | `hw-match` |
| `omarchy-hw-hybrid-gpu` | partial | 24 | Detect whether the system has an active hybrid GPU configuration | `cmd-present` |
| `omarchy-hw-intel` | partial | 5 | Detect whether the computer has an Intel CPU. | — |
| `omarchy-hw-intel-ptl` | pending | 5 | Detect whether the computer has an Intel Panther Lake GPU. | — |
| `omarchy-hw-intel-sof` | pending | 5 | Detect an Intel SOF-capable audio DSP | — |
| `omarchy-hw-laptop` | partial | 17 | Returns true when running on a laptop (has a lid or laptop chassis). | — |
| `omarchy-hw-laptop-closed` | pending | 11 | Returns true when the laptop lid is closed | — |
| `omarchy-hw-match` | partial | 7 | Match against the computer's DMI product name or product family (case-insensitive). | — |
| `omarchy-hw-nvidia` | partial | 16 | Detect whether the computer has an NVIDIA GPU. | — |
| `omarchy-hw-nvidia-display` | pending | 45 | Detect whether NVIDIA drives the display (rather than a hybrid iGPU). | — |
| `omarchy-hw-nvidia-gsp` | pending | 20 | Detect whether the computer has an NVIDIA GPU with GSP firmware (Turing or newer). | — |
| `omarchy-hw-nvidia-without-gsp` | pending | 23 | Detect whether the computer has an NVIDIA GPU without GSP firmware (Maxwell/Pascal/Volta). | — |
| `omarchy-hw-recover-internal-monitor` | pending | 9 | Clear the internal-monitor-disable toggle if no external display is connected. | `hw-external-monitors` |
| `omarchy-hw-surface` | pending | 6 | Detect whether the computer is a Microsoft Surface device. | `hw-match` |
| `omarchy-hw-touchpad` | pending | 6 | Print the detected Hyprland touchpad or trackpad device name | — |
| `omarchy-hw-touchscreen` | pending | 6 | Print the detected Hyprland touchscreen or tablet device name | — |
| `omarchy-hw-vm` | partial | 5 | Returns true when running in a virtual machine. | — |
| `omarchy-hw-vulkan` | partial | 6 | Detect whether Vulkan is available. | — |
| `omarchy-hw-webcam` | pending | 5 | Check whether a webcam is available | `capture-webcam-list` |
| `omarchy-hyprland-monitor-clamshell` | pending | 252 | Apply clamshell display state to Hyprland monitors | `hw-clamshell`, `hyprland-monitor-external-active`, `hyprland-monitor-internal`, `hyprland-monitor-internal-mirror`, `hyprland-monitor-laptop` |
| `omarchy-hyprland-monitor-external-active` | pending | 6 | Returns true when Hyprland has an active external monitor | — |
| `omarchy-hyprland-monitor-focused` | pending | 5 | Print the name of the currently focused Hyprland monitor. | — |
| `omarchy-hyprland-monitor-focused-apple` | pending | 12 | Return success if the focused or named Hyprland monitor is an Apple display. | — |
| `omarchy-hyprland-monitor-internal` | pending | 78 | Enable, disable, toggle, or recover the internal laptop display | `hyprland-monitor-external-active`, `hyprland-monitor-laptop`, `hyprland-toggle`, `hyprland-toggle-disabled`, `hyprland-toggle-enabled`, `notification-send` |
| `omarchy-hyprland-monitor-laptop` | pending | 5 | Print the name of the built-in laptop display, including disabled outputs. | — |
| `omarchy-hyprland-monitor-modeless` | pending | 21 | Returns true when Hyprland has an enabled monitor with no mode | — |
| `omarchy-hyprland-monitor-scaling` | partial | 203 | Show, set, or adjust focused Hyprland monitor scaling | — |
| `omarchy-hyprland-monitor-watch` | pending | 114 | Watch Hyprland monitor events and recover monitor toggles when a monitor is removed | `hw-laptop`, `hyprland-monitor-clamshell`, `hyprland-monitor-external-active`, `hyprland-monitor-modeless`, `hyprland-reload-guard` |
| `omarchy-hyprland-reload-guard` | pending | 115 | Pause or resume Hyprland config auto-reload around package transactions. | — |
| `omarchy-hyprland-session-locked` | partial | 29 | Returns true when the compositor holds a session lock | — |
| `omarchy-monitor-state` | pending | 23 | Print monitor panel state for the shell | `brightness-display`, `hyprland-monitor-scaling` |
| `omarchy-powerprofiles-init` | partial | 5 | Set the correct power profile on boot based on current AC/battery state. | `powerprofiles-set` |
| `omarchy-powerprofiles-list` | partial | 17 | Returns a list of all the available power profiles on the system. | — |
| `omarchy-powerprofiles-set` | partial | 63 | Set and remember the power profile for AC or battery use | `powerprofiles-list` |
| `omarchy-restart-trackpad` | pending | 20 | Reset the trackpad by unbinding and rebinding its driver. | — |
| `omarchy-system-sleep-lock` | titan-policy | 124 | Lock before suspend and wait for the session lock to become secure | `hyprland-monitor-clamshell`, `notification-send`, `shell` |
| `omarchy-system-sleep-monitor` | titan-policy | 61 | Monitor sleep preparation and lock before suspend | `system-sleep-lock` |
| `omarchy-toggle-hybrid-gpu` | pending | 119 | Toggle dedicated vs integrated GPU mode via supergfxd (for hybrid gpu laptops, like Asus G14). | `cmd-missing`, `pkg-add`, `system-reboot` |
| `omarchy-toggle-input-device` | pending | 76 | Enable, disable, or toggle a Hyprland input device | `osd` |
| `omarchy-toggle-suspend` | pending | 11 | Toggle suspend availability in the system menu | `notification-send`, `toggle`, `toggle-enabled` |
| `omarchy-toggle-touchscreen` | pending | 6 | Enable, disable, or toggle the touch functionality of the screen | `toggle-input-device` |

<a id="services"></a>

## Optional service lifecycle and file sharing

Owner/language: Shell operations; QML status and controls using native events when available.

Prerequisites: core, apps.

Extend existing Docker/CUPS/Tailscale lifecycle, receipt/send and owned activation units. Third-party services need separate setup/auth/remove recipes; DNS changes must preserve working connections and pre-existing configuration.

Acceptance: Real package setup/start/disable/re-enable and restore; no socket reactivation after disable; explicit external authentication/device tests; owned firewall and data preservation.

| Reference command | Status | Source lines | Behavior to review | Lexical references |
| --- | --- | ---: | --- | --- |
| `omarchy-dns` | pending | 319 | Show or configure the system DNS provider | — |
| `omarchy-install-service-1password` | pending | 34 | Install 1Password and its Chromium extension. | `cmd-missing`, `pkg-add` |
| `omarchy-install-service-dropbox` | pending | 14 | Install and start the Dropbox service. Must then be authenticated via the web. | `pkg-add`, `plugin-enable` |
| `omarchy-install-service-nordvpn` | pending | 18 | Install the NordVPN service with optional GUI. | `pkg-add`, `system-reboot` |
| `omarchy-install-service-once` | pending | 13 | Install the ONCE service, enable its background service, and launch the TUI. | `pkg-add` |
| `omarchy-install-service-signal` | partial | 15 | Install Signal and launch it. | `pkg-add` |
| `omarchy-install-service-spotify` | pending | 15 | Install Spotify. | `pkg-add` |
| `omarchy-install-service-sunshine` | pending | 87 | Install Sunshine and open Moonlight streaming ports for LAN and Tailscale. | `cmd-missing`, `launch-webapp`, `pkg-add`, `webapp-install` |
| `omarchy-install-service-tailscale` | partial | 22 | Install the Tailscale mesh VPN service and a web app for the Tailscale Admin Console. | `pkg-add`, `plugin-enable`, `tailscale-receive`, `webapp-install` |
| `omarchy-installed-service-dropbox` | pending | 12 | Check whether Dropbox is installed and running | `cmd-present` |
| `omarchy-installed-service-tailscale` | pending | 12 | Check whether Tailscale is installed and running | `cmd-present` |
| `omarchy-network-band` | pending | 192 | Show or pin the Wi-Fi band for the active connection | — |
| `omarchy-remove-service-1password` | pending | 13 | Remove 1Password and its Chromium extension. | `pkg-drop` |
| `omarchy-remove-service-dropbox` | pending | 11 | Remove Dropbox and its bar plugin. | `pkg-drop`, `plugin-disable` |
| `omarchy-remove-service-sunshine` | pending | 69 | Remove Sunshine and close Omarchy-managed Moonlight streaming ports. | `cmd-missing`, `pkg-drop`, `webapp-remove` |
| `omarchy-remove-service-tailscale` | pending | 14 | Remove Tailscale and its bar plugin. | `pkg-drop`, `plugin-disable`, `tailscale-receive`, `webapp-remove` |
| `omarchy-restart-audio` | pending | 225 | Restart audio services and recover stuck USB audio devices. | `cmd-present` |
| `omarchy-restart-bluetooth` | pending | 7 | Unblock and restart the bluetooth service. | — |
| `omarchy-restart-wifi` | pending | 11 | Unblock and restart the Wi-Fi service. | — |
| `omarchy-tailscale-receive` | pending | 99 | Save incoming Taildrop files and announce them | `notification-send` |
| `omarchy-tailscale-send` | pending | 50 | Send files to a machine on your tailnet with Taildrop | `file-select`, `notification-send` |

<a id="developer"></a>

## Developer environments, config recovery and workspace jobs

Owner/language: Shell for system tools, mise, jobs and per-user config operations.

Prerequisites: core, apps.

Verify existing framework/runtime and SSH/rsync operations, then migrate Python command families in focused batches with the same CLI contracts. Keep copied-once defaults, backups and owned jobs; dev-link needs explicit source/package switching and recovery design.

Acceptance: Real provisioning, executable tools and Bash activation; worktree and backup data preservation; authenticated localhost SSH forward and rsync event delivery; unit/process cleanup; no implicit mise project trust.

| Reference command | Status | Source lines | Behavior to review | Lexical references |
| --- | --- | ---: | --- | --- |
| `omarchy-dev-add-migration` | partial | 41 | Create a new Omarchy migration in the current source tree. | — |
| `omarchy-dev-benchmark-cli` | pending | 111 | Measure Omarchy CLI response times | — |
| `omarchy-dev-install-ydoo` | pending | 50 | Install and enable ydotool mouse automation for Omarchy development | `cmd-missing`, `pkg-add`, `pkg-missing` |
| `omarchy-dev-link` | pending | 123 | Point Omarchy at a local checkout after reboot | `dev-pkg-test`, `system-reboot` |
| `omarchy-dev-status` | pending | 64 | Show the current Omarchy dev-link state | — |
| `omarchy-dev-ui-preview` | pending | 20 | Open the omarchy-shell dev gallery (qs.Ui kit preview) | `shell` |
| `omarchy-dev-unlink` | pending | 64 | Restore Omarchy to the package install after reboot | `dev-link`, `system-reboot` |
| `omarchy-git-url-check` | partial | 50 | Check that a git URL names a repository, not a transport helper | — |
| `omarchy-install-docker-dbs` | partial | 28 | Install one of the supported databases in a Docker container with the suitable development options. | — |
| `omarchy-provision-first-run` | pending | 99 | Finish first-login setup for Omarchy. | `done`, `hook-install`, `notification-wait`, `provision-user` |
| `omarchy-provision-user` | pending | 131 | Finalize Omarchy user setup (runtime tweaks /etc/skel can't do) | `done`, `provision-owner`, `refresh-applications`, `reinstall-configs` |
| `omarchy-refresh-chromium` | pending | 25 | Refresh the ~/.config/chromium-flags.conf file from the Omarchy defaults. | `install-chromium-copy-url`, `install-chromium-google-account`, `install-chromium-ytdlp`, `refresh-config` |
| `omarchy-refresh-herdr` | pending | 6 | Overwrite the user herdr config with the Omarchy default and reload herdr. | `refresh-config`, `restart-herdr` |
| `omarchy-refresh-hyprland` | pending | 14 | Overwrite all the user Hyprland Lua configs in ~/.config/hypr with the Omarchy defaults. | `refresh-config` |
| `omarchy-refresh-hyprsunset` | pending | 6 | Overwrite the user config for hyprsunset with the Omarchy default and restart the service. | `refresh-config`, `restart-hyprsunset` |
| `omarchy-refresh-tmux` | pending | 6 | Overwrite the user tmux config with the Omarchy default and reload tmux. | `refresh-config`, `restart-tmux` |
| `omarchy-reinstall` | pending | 15 | Reinstall Omarchy packages and reset default configs | `reinstall-configs`, `reinstall-pkgs`, `system-reboot` |
| `omarchy-reinstall-configs` | pending | 28 | Reset Omarchy user configs and shipped defaults in $HOME (destructive) | `cmd-present`, `refresh-limine`, `refresh-plymouth` |

<a id="apps"></a>

## Application bundles, browser integration, gaming and launchers

Owner/language: Shell, declarative catalogs and desktop files; QML selectors.

Prerequisites: core.

Separate package availability from complete provisioning. Add paired install/remove behavior, native messaging/protocol handlers, TUI and retro launchers, GPU-aware gaming and a dedicated Windows VM milestone. Removal defaults preserve profiles, models, saves and game libraries.

Acceptance: Actual official/AUR package builds in guests; quoted filenames/URLs; default launch/cwd behavior; native messaging framing and protocol ownership; install/remove restores previous user choices.

| Reference command | Status | Source lines | Behavior to review | Lexical references |
| --- | --- | ---: | --- | --- |
| `omarchy-chromium-copy-url-host` | pending | 50 | Native messaging host: copy a Chromium tab URL to the clipboard | `notification-send` |
| `omarchy-chromium-ytdlp-host` | pending | 196 | Native messaging host: download the URL sent by the yt-dlp Chromium extension | `notification-send`, `osd`, `shell` |
| `omarchy-cmd-browser-handoff` | pending | 48 | Hand a command line to the running Chromium-based browser | — |
| `omarchy-games-retro-cores` | pending | 39 | List installed RetroArch core names | — |
| `omarchy-games-retro-install` | pending | 72 | Create a desktop launcher for a RetroArch game | `games-retro-cores`, `menu-file`, `menu-select`, `notification-send` |
| `omarchy-install-and-launch` | partial | 27 | Install a packaged app and launch it once it finishes | `launch-floating-terminal-with-presentation`, `pkg-add` |
| `omarchy-install-app` | partial | 24 | Install a packaged app, surfacing the install in a floating terminal | `launch-floating-terminal-with-presentation`, `pkg-add` |
| `omarchy-install-browser` | partial | 98 | Install a supported browser | `install-chromium-copy-url`, `install-chromium-ytdlp`, `pkg-add`, `pkg-aur-add`, `theme-set-browser` |
| `omarchy-install-chromium-claude` | pending | 43 | Install the Claude extension for Chromium-based browsers | — |
| `omarchy-install-chromium-copy-url` | pending | 31 | Install the native messaging host for the Copy URL Chromium extension | `chromium-copy-url-host` |
| `omarchy-install-chromium-google-account` | pending | 16 | Allow Chromium to sign in to Google accounts by adding the required OAuth credentials | — |
| `omarchy-install-chromium-ytdlp` | pending | 32 | Install the native messaging host for the yt-dlp Chromium extension | `chromium-ytdlp-host` |
| `omarchy-install-editor-emacs` | partial | 9 | Install Emacs with Omarchy theme and font integration via the omarchy-emacs AUR package | `pkg-aur-add` |
| `omarchy-install-editor-helix` | partial | 28 | Install Helix and configure it to use the current Omarchy theme | `pkg-add`, `theme-refresh` |
| `omarchy-install-editor-vscode` | partial | 29 | Install VS Code and configure Omarchy defaults for secrets, updates, and theme | `pkg-add`, `theme-set-vscode` |
| `omarchy-install-editor-zed` | partial | 11 | Install Zed Editor and configure it with the current Omarchy theme | `pkg-add` |
| `omarchy-install-gaming-battlenet` | pending | 88 | Install Battle.net standalone via umu-launcher + GE-Proton (no Steam, no Lutris, no Heroic). | `install-gaming-gpu-lib32`, `launch-battlenet`, `pkg-add` |
| `omarchy-install-gaming-geforce-now` | pending | 20 | Install and launch Geforce Now. | `launch-browser`, `pkg-add` |
| `omarchy-install-gaming-gpu-lib32` | pending | 30 | Install lib32 graphics drivers (Vulkan + NVIDIA) for any detected GPUs. | `hw-nvidia-gsp`, `hw-nvidia-without-gsp`, `pkg-add` |
| `omarchy-install-gaming-heroic` | pending | 12 | Install Heroic Games Launcher (Epic, GOG, Amazon Prime Gaming) with graphics drivers. | `install-gaming-gpu-lib32`, `pkg-add` |
| `omarchy-install-gaming-lutris` | pending | 23 | Install Lutris with Wine + DXVK for running Windows games (Battle.net, EA, Ubisoft Connect, etc.) | `install-gaming-gpu-lib32`, `pkg-add` |
| `omarchy-install-gaming-retroarch` | partial | 85 | Install RetroArch with the full libretro core set plus FBNeo and a ~/Games ROM directory. | `pkg-add` |
| `omarchy-install-gaming-steam` | pending | 15 | Install Steam and graphics drivers selected for this system | `install-gaming-gpu-lib32`, `pkg-add` |
| `omarchy-install-gaming-xbox-cloud` | pending | 12 | Install Xbox Cloud Gaming as a web app and launch it. | `launch-webapp`, `webapp-install` |
| `omarchy-install-gaming-xbox-controllers` | pending | 39 | Install support for using Xbox controllers with Steam/RetroArch/etc. | `pkg-add` |
| `omarchy-install-preinstalls` | pending | 38 | Restore the preinstalled Omarchy applications (web apps, TUIs, and selected packages). | `pkg-add`, `refresh-applications`, `remove-preinstalls` |
| `omarchy-install-terminal` | partial | 52 | Install one of the approved terminals and set it as the default for Omarchy (Super + Return etc). | `pkg-add` |
| `omarchy-launch-1password` | partial | 14 | Launch 1Password or start its installer when missing. | `cmd-present`, `install-service-1password`, `launch-floating-terminal-with-presentation` |
| `omarchy-launch-about` | pending | 364 | Launch the fastfetch TUI that gives information about the current system. | `branding-about-animation`, `launch-or-focus-tui` |
| `omarchy-launch-battlenet` | pending | 48 | Launch the installed Battle.net client via umu-launcher + GE-Proton. | `install-gaming-battlenet` |
| `omarchy-launch-discord-community` | pending | 11 | Open the Omarchy Discord community in the Discord app or a browser. | `cmd-present`, `launch-webapp` |
| `omarchy-launch-docker-tui` | partial | 20 | Open the Docker TUI (lazydocker) with access to the Docker daemon | `setup-security-sudoless-docker`, `sudo-docker` |
| `omarchy-launch-floating-terminal-with-presentation` | pending | 14 | Launch a floating terminal with the Omarchy presentation wrapper | `restart-gum`, `show-done`, `show-logo` |
| `omarchy-launch-or-focus` | partial | 19 | Launch an app or focus an existing window matching a pattern | — |
| `omarchy-launch-or-focus-tui` | partial | 14 | Launch a TUI or focus an existing terminal window for it | `launch-or-focus`, `launch-tui` |
| `omarchy-launch-or-focus-webapp` | partial | 15 | Launch or focus on a given web app identified by the window-pattern. | `launch-or-focus`, `launch-webapp` |
| `omarchy-launch-screensaver` | pending | 86 | Launch the Omarchy screensaver in the default terminal on the system with the correct font configuration. | `hyprland-monitor-focused`, `notification-send`, `screensaver`, `toggle-enabled` |
| `omarchy-launch-shell` | pending | 91 | Launch the Omarchy shell with its log kept in the journal | `restart-shell`, `shell` |
| `omarchy-launch-signal` | partial | 15 | Launch Signal or start its installer when missing. | `install-service-signal`, `launch-floating-terminal-with-presentation` |
| `omarchy-launch-spotify` | partial | 15 | Launch Spotify or start its installer when missing. | `install-service-spotify`, `launch-floating-terminal-with-presentation` |
| `omarchy-launch-terminal-herdr` | partial | 5 | Launch or attach to the persistent herdr session in a terminal | `launch-terminal` |
| `omarchy-launch-terminal-tmux` | partial | 5 | Launch or attach to the Work tmux session in a terminal | `launch-terminal` |
| `omarchy-launch-webapp` | partial | 17 | Launch a URL as a web app in the default supported browser | `cmd-browser-handoff`, `cmd-default-browser` |
| `omarchy-pkg-add` | partial | 24 | Install Arch packages if they are missing | `pkg-missing` |
| `omarchy-pkg-aur-accessible` | partial | 6 | Returns true if the AUR is up and available. | `update` |
| `omarchy-pkg-aur-add` | partial | 18 | Add the named packages to the system from the AUR if they're missing. Returns false if it couldn't be done. | `pkg-missing` |
| `omarchy-pkg-aur-install` | partial | 30 | Show a fuzzy-finder TUI for picking new AUR packages to install. | `show-done`, `sudo-keepalive` |
| `omarchy-pkg-install` | partial | 26 | Show a fuzzy-finder TUI for picking new Arch and OPR packages to install. | `show-done`, `sudo-keepalive` |
| `omarchy-pkg-remove` | partial | 24 | Show a fuzzy-finder TUI for picking packages installed on the system to be removed. | `show-done` |
| `omarchy-refresh-applications` | partial | 17 | Ensure default application launchers and mise wrappers are installed. | `cmd-present` |
| `omarchy-remove-browser` | pending | 70 | Remove a supported browser and clean up Omarchy browser defaults | `cmd-present`, `pkg-drop`, `pkg-missing` |
| `omarchy-remove-dev-env` | pending | 154 | Remove a development environment that was previously installed via omarchy-install-dev-env. | `install-dev-env`, `pkg-drop` |
| `omarchy-remove-gaming-battlenet` | pending | 35 | Remove Battle.net, its Proton prefix, installed games, and desktop entry. | `pkg-drop`, `pkg-present` |
| `omarchy-remove-gaming-geforce-now` | pending | 14 | Remove the GeForce NOW Flatpak app and its data. | `cmd-present` |
| `omarchy-remove-gaming-heroic` | pending | 17 | Remove Heroic Games Launcher and its game libraries, configs, and caches. | `pkg-drop` |
| `omarchy-remove-gaming-lutris` | pending | 21 | Remove Lutris, Wine, umu-launcher, and all their configs and caches. | `pkg-drop` |
| `omarchy-remove-gaming-minecraft` | pending | 17 | Remove the Minecraft launcher along with its worlds, mods, and caches. | `pkg-drop` |
| `omarchy-remove-gaming-retroarch` | pending | 39 | Remove RetroArch, all libretro cores, and its config/saves. Leaves ~/Games/roms and ~/Games/bios alone. | `pkg-drop` |
| `omarchy-remove-gaming-steam` | pending | 17 | Remove Steam and all of its game libraries, configs, and caches. | `pkg-drop` |
| `omarchy-remove-gaming-xbox-cloud` | pending | 7 | Remove the Xbox Cloud Gaming web app. | `webapp-remove` |
| `omarchy-remove-gaming-xbox-controllers` | pending | 15 | Remove the xpadneo Xbox controller driver and undo its module/blacklist config. | `pkg-drop` |
| `omarchy-remove-launcher-entry` | pending | 101 | Remove or uninstall the selected launcher entry | `cmd-present`, `launch-floating-terminal-with-presentation`, `launch-webapp`, `tui-remove`, `webapp-remove` |
| `omarchy-remove-preinstalls` | pending | 49 | Remove preinstalled Omarchy applications (web apps, TUIs, and selected packages). | `mise-install`, `pkg-drop`, `tui-remove-all`, `webapp-remove-all` |
| `omarchy-tui-install` | pending | 98 | Create a desktop launcher for a terminal UI app | — |
| `omarchy-tui-remove` | pending | 41 | Remove a terminal UI desktop launcher | `menu-select`, `notification-send` |
| `omarchy-tui-remove-all` | pending | 37 | Remove all TUIs installed via omarchy-tui-install. | `cmd-present`, `tui-install` |
| `omarchy-webapp-handler-hey` | pending | 15 | Open HEY webmail and translate mailto links | `launch-webapp` |
| `omarchy-webapp-handler-zoom` | pending | 23 | Open Zoom web meetings from browser protocol links | `launch-webapp` |
| `omarchy-webapp-install` | partial | 241 | Create a desktop launcher for a web app | `launch-webapp`, `webapp-remove` |
| `omarchy-webapp-remove` | partial | 61 | Remove a web app desktop launcher | `launch-webapp`, `menu-select`, `notification-send` |
| `omarchy-webapp-remove-all` | pending | 37 | Remove all web apps installed via omarchy-webapp-install. | `cmd-present`, `launch-webapp`, `webapp-install` |
| `omarchy-windows-key` | pending | 41 | Print the OEM Windows product key stored in firmware | `cmd-present` |
| `omarchy-windows-vm` | pending | 1614 | Install, launch, stop, inspect, or remove the Windows VM | `notification-send`, `pkg-add`, `setup-security-sudoless-docker`, `sudo-docker` |

<a id="plugins"></a>

## Plugin manifest, catalog, cloning and updates

Owner/language: QML extensions and Shell lifecycle management; maintain Titan's own manifest/API.

Prerequisites: core, themes.

Extend existing install/validate/enable/disable/remove with built-in clone, catalog, capability reporting and validated update rollback. A renamed Omarchy plugin is not compatible with Titan automatically.

Acceptance: Real QML load/unload; broken update restores a working plugin; enabled registry and user edits remain intact; permissions and compatibility are reviewable.

| Reference command | Status | Source lines | Behavior to review | Lexical references |
| --- | --- | ---: | --- | --- |
| `omarchy-menu-plugin` | pending | 46 | Pick a shell plugin to enable, disable, clone, or remove | `launch-floating-terminal-with-presentation`, `menu-select`, `notification-send`, `plugin-clone`, `plugin-list`, `plugin-remove` |
| `omarchy-plugin-add` | partial | 175 | Add a shell plugin from git | `git-url-check`, `plugin-catalog`, `plugin-enable`, `plugin-list`, `plugin-validate`, `shell`, `theme-install` |
| `omarchy-plugin-catalog` | pending | 62 | Emit every first-party and user plugin manifest as JSON | — |
| `omarchy-plugin-clone` | pending | 168 | Clone a built-in Omarchy shell plugin into your own config | `notification-send`, `plugin-catalog`, `plugin-enable`, `plugin-list`, `shell` |
| `omarchy-plugin-disable` | partial | 26 | Disable a shell plugin | `shell` |
| `omarchy-plugin-enable` | partial | 100 | Enable a shell plugin | `plugin-catalog`, `shell` |
| `omarchy-plugin-list` | partial | 46 | List discovered shell plugins | `shell` |
| `omarchy-plugin-remove` | partial | 123 | Remove an installed shell plugin | `shell` |
| `omarchy-plugin-update` | pending | 133 | Update installed git-managed plugins | `cmd-present`, `plugin-validate`, `shell` |
| `omarchy-plugin-validate` | partial | 118 | Validate a plugin folder against the Omarchy plugin manifest schema | — |

<a id="capture"></a>

## Capture, media, dictation and picker workflows

Owner/language: Shell tool orchestration and QML interactive controls.

Prerequisites: core, apps.

Finish frozen screenshot selection, webcam synchronization, safe file/timezone picking, ASCII conversion and explicit Voxtype model provisioning/status. Preserve clipboard and QR secrecy.

Acceptance: Real files and frames, output preservation, cancellation/keyboard navigation, recording teardown and dictated input on explicitly tested hardware; no private-content logs.

| Reference command | Status | Source lines | Behavior to review | Lexical references |
| --- | --- | ---: | --- | --- |
| `omarchy-capture-region` | partial | 370 | Pick a screen region over frozen screen content | — |
| `omarchy-capture-screenrecording` | partial | 303 | Start or stop screen recording | `capture-region`, `capture-webcam-list`, `capture-webcam-resize`, `hyprland-monitor-focused`, `notification-send`, `shell` |
| `omarchy-capture-screenrecording-with-webcam` | partial | 21 | Pick a webcam and start a screen recording with it | `capture-screenrecording`, `capture-webcam-list`, `menu-select`, `notification-send` |
| `omarchy-capture-screenshot` | partial | 23 | Take a screenshot | — |
| `omarchy-capture-text` | partial | 26 | Extract text from a screenshot region with OCR | `notification-send` |
| `omarchy-capture-webcam-list` | partial | 33 | List webcam devices that support video capture | — |
| `omarchy-capture-webcam-resize` | partial | 152 | Resize the active webcam recording overlay | `capture-screenrecording` |
| `omarchy-clipboard-open` | partial | 70 | Open a clipboard history entry | `launch-browser`, `launch-editor` |
| `omarchy-clipboard-paste-file` | partial | 33 | Copy a file to the clipboard and paste it | — |
| `omarchy-clipboard-paste-text` | partial | 63 | Copy text to the clipboard and type or paste it | — |
| `omarchy-file-select` | pending | 124 | Pick files with the desktop file chooser | — |
| `omarchy-menu-emoji-insert` | pending | 20 | Insert an emoji into the focused application | — |
| `omarchy-menu-file` | partial | 48 | Pick a file from a menu | `menu-select` |
| `omarchy-menu-timezone` | partial | 12 | Select and set the system timezone | `menu-select`, `notification-send`, `shell` |
| `omarchy-transcode-ascii` | pending | 238 | Transcode an image into ASCII/Unicode art text | — |
| `omarchy-voxtype-config` | pending | 8 | Open Voxtype configuration | `launch-floating-terminal-with-presentation`, `restart-shell` |
| `omarchy-voxtype-install` | pending | 26 | Install and configure Voxtype dictation | `hw-vulkan`, `notification-send`, `pkg-add`, `restart-shell` |
| `omarchy-voxtype-model` | pending | 8 | Open Voxtype AI model setup | `launch-floating-terminal-with-presentation`, `restart-shell` |
| `omarchy-voxtype-remove` | pending | 24 | Remove Voxtype dictation and its configuration | `cmd-present`, `pkg-drop` |
| `omarchy-voxtype-status` | pending | 13 | Stream voxtype --follow status as bar-friendly JSON | `cmd-missing` |

<a id="desktop"></a>

## Shell surfaces, notifications, toggles, state and watchers

Owner/language: QML/native Quickshell APIs for UI/reactive services; Shell CLI adapters.

Prerequisites: core, themes.

Replace generic state/file-flag helpers with documented Titan preferences and operations. Add persistent reminders, battery/crash watchers, weather state and shell restart/reload contracts. Preserve researched appearance and exact key chords.

Acceptance: Actual Wayland/QML interactions, event lifetimes and CPU cost, persistence/restart and reduced motion; restore panel/theme baseline; no broad application killing.

| Reference command | Status | Source lines | Behavior to review | Lexical references |
| --- | --- | ---: | --- | --- |
| `omarchy-bar-text-color` | pending | 128 | Choose a legible transparent bar text color | `cmd-present` |
| `omarchy-battery-low` | pending | 17 | Send the low battery warning notification and run battery-low hooks. | `hook`, `notification-send` |
| `omarchy-crash-mute` | pending | 73 | Silence crash notifications for one program, or list what is silenced | `crash-watch`, `toggle`, `toggle-enabled` |
| `omarchy-crash-watch` | partial | 109 | Watch for process crashes and offer an AI diagnosis | `agent`, `agent-crash`, `crash-mute`, `default-agent`, `notification-send`, `notification-wait`, `toggle-enabled` |
| `omarchy-done` | pending | 40 | Check or mark completed Omarchy setup tasks | — |
| `omarchy-hyprland-toggle` | pending | 54 | Toggle permanent Hyprland flags by copying them into a directory that's sourced entirely. | — |
| `omarchy-hyprland-toggle-disabled` | pending | 6 | Check if a Hyprland toggle is currently disabled (missing). | — |
| `omarchy-hyprland-toggle-enabled` | pending | 6 | Check if a Hyprland toggle is currently enabled. | — |
| `omarchy-menu-images` | partial | 420 | Open a generic image selector menu | `shell` |
| `omarchy-menu-input` | partial | 58 | Prompt for text input from a menu | `shell` |
| `omarchy-menu-select` | partial | 99 | Pick one option from a menu | `shell` |
| `omarchy-network-password` | partial | 34 | Print the active Wi-Fi connection's password | — |
| `omarchy-network-qr` | partial | 97 | Generate a Wi-Fi QR matrix for the shell | — |
| `omarchy-network-speedtest` | pending | 130 | Measure live internet speed for one direction | `cmd-present` |
| `omarchy-network-status` | partial | 137 | Print active network status for the shell | `cmd-present` |
| `omarchy-notification-battery` | pending | 5 | Show the current battery status notification | `battery-status`, `notification-send` |
| `omarchy-notification-dismiss` | partial | 11 | Dismiss a notification by summary substring. Used by the first-run notifications to dismiss them after clicking for action. | `shell` |
| `omarchy-notification-send` | partial | 211 | Send an Omarchy desktop notification | — |
| `omarchy-notification-time` | partial | 5 | Show the current time and date notification | `notification-send` |
| `omarchy-notification-wait` | pending | 30 | Wait for the desktop notification server to accept notifications | `shell` |
| `omarchy-notification-weather` | partial | 5 | Toggle the current weather panel | `shell` |
| `omarchy-refresh-shell` | pending | 11 | Reset shell.json to Omarchy defaults | `bar`, `refresh-config`, `restart-shell` |
| `omarchy-reminder` | partial | 201 | Set and show lightweight desktop notification reminders | `notification-send`, `shell` |
| `omarchy-restart-app` | pending | 7 | Restart an application by killing it and relaunching via uwsm. | — |
| `omarchy-restart-btop` | pending | 5 | Reload btop configuration (used by the Omarchy theme switching). | — |
| `omarchy-restart-gum` | pending | 18 | Export the current theme's gum styling into the environment | — |
| `omarchy-restart-helix` | pending | 7 | Reload Helix configuration | — |
| `omarchy-restart-herdr` | pending | 13 | Reload herdr if running with the latest configuration | — |
| `omarchy-restart-hyprctl` | pending | 5 | Reload hyprland configuration (used by the Omarchy theme switching). | — |
| `omarchy-restart-hyprsunset` | pending | 5 | Restart the hyprsunset service (used for blue light filtering/night light). | `restart-app` |
| `omarchy-restart-opencode` | pending | 7 | Reload opencode configuration (used by the Omarchy theme switching). | — |
| `omarchy-restart-terminal` | pending | 15 | Reload supported terminal emulators after config changes | — |
| `omarchy-restart-tmux` | pending | 7 | Restart tmux if running with the latest configuration | — |
| `omarchy-restart-xcompose` | pending | 10 | Restart the XCompose input method service (fcitx5) to apply new compose key settings. | — |
| `omarchy-screensaver` | pending | 48 | Run the Omarchy screensaver using random effects from TTE. | — |
| `omarchy-shell-config` | pending | 62 | Shared helpers for editing ~/.config/omarchy/shell.json (source this, don't run it). | `shell` |
| `omarchy-show-done` | pending | 25 | Display a "Done!" or "Failed!" message and wait for user to press any key. | — |
| `omarchy-show-logo` | pending | 9 | Display the Omarchy logo in the terminal using green color. | — |
| `omarchy-state` | pending | 39 | Manage persistent state files for Omarchy toggles and settings. | — |
| `omarchy-system-lid-close` | titan-policy | 20 | Lock and reconcile displays when the laptop lid closes | `hw-external-monitors`, `hw-laptop-closed`, `hyprland-monitor-clamshell`, `system-lock`, `system-sleep-lock` |
| `omarchy-system-stats` | pending | 59 | Print CPU and memory stats for the shell | — |
| `omarchy-system-wake` | titan-policy | 10 | Wake displays and restore brightness after idle | `brightness-display`, `brightness-keyboard`, `hyprland-monitor-clamshell` |
| `omarchy-toggle` | pending | 42 | Toggle Omarchy features between enabled and disabled | — |
| `omarchy-toggle-animations` | pending | 22 | Toggle animations, transparency and other effects that are slow without a GPU | `hyprland-toggle`, `hyprland-toggle-enabled`, `notification-send` |
| `omarchy-toggle-crash-capture` | pending | 18 | Toggle crash capture notifications | `crash-watch`, `notification-send`, `toggle`, `toggle-enabled` |
| `omarchy-toggle-enabled` | pending | 6 | Check if a toggle is enabled (flag file exists) | — |
| `omarchy-toggle-fullscreen-desktop` | pending | 27 | Toggle a full screen desktop: hide the top bar and remove the window gaps together | `hyprland-toggle`, `hyprland-toggle-enabled`, `toggle-bar`, `toggle-enabled` |
| `omarchy-toggle-idle` | titan-policy | 67 | Toggle idle behavior so the system either idles normally or stays awake | — |
| `omarchy-toggle-screensaver` | titan-policy | 11 | Toggle screensaver availability | `notification-send`, `toggle`, `toggle-enabled` |
| `omarchy-weather-icon` | pending | 45 | Returns a weather condition icon, adjusted for live sunrise and sunset. | `weather-location` |
| `omarchy-weather-location` | pending | 46 | Show or set the location used for weather reports | — |
| `omarchy-weather-status` | pending | 24 | Returns a formatted weather status string with temperature and wind speed. | `weather-location` |

<a id="core"></a>

## Shared command primitives and distribution diagnostics

Owner/language: Shell shared helpers; development analysis/tests may use Python.

Prerequisites: existing Titan foundation.

Implement stable command-presence, diagnostics and selection contracts where needed. Drive selection/password and log upload require narrowly scoped UI/privileged workflows; never expose firmware keys or auto-upload logs.

Acceptance: Argument boundaries, missing-command exit codes and side-effect-free status; cancel leaves state unchanged; explicit redacted-log upload destination before network writes.

| Reference command | Status | Source lines | Behavior to review | Lexical references |
| --- | --- | ---: | --- | --- |
| `omarchy-debug` | partial | 96 | Print debugging information | — |
| `omarchy-debug-idle` | partial | 61 | Show idle, screensaver, and lock diagnostics | `screensaver`, `shell`, `system-sleep-monitor`, `toggle-enabled` |
| `omarchy-disk-speedtest` | pending | 232 | Measure live disk read and write speed | — |
| `omarchy-drive-info` | pending | 50 | Print drive information such as size, model, and mount details | — |
| `omarchy-drive-select` | pending | 18 | Select a drive from a list with info that includes space and brand. Used by omarchy-drive-password. | `drive-info`, `drive-password` |
| `omarchy-upload-log` | pending | 165 | Upload logs to logs.omarchy.org | `cmd-present` |
