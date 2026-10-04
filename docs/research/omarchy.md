# Omarchy implementation coverage — 2026-10-04

The owner's request is to preserve Titan's implemented features and build the
missing Omarchy workflows as original modular scripts and dotfiles. This is an
ongoing parity task, not a declaration of complete equivalence.

Source revision: `5c4da021469517449770579793b37ce26d0a0d48` from
[omacom/omarchy](https://github.com/omacom/omarchy). The stable local checkout
and the supplied Quickshell archive are linked in
[agent-references.md](agent-references.md). The current Omarchy tree includes
a plugin-based Quickshell desktop and agent account features that weren't in
Titan's older shortcut reference. Preserve Titan's researched appearance and
231 active chord registrations rather than adopting upstream configuration.

## Inventory and repeatability

- [omarchy-inventory.json](omarchy-inventory.json): every one of the 479
  commands, source hash, summary and coverage, plus hashes for 878 reference
  files under config/default/install/shell/manual/themes.
- [omarchy-equivalents.json](omarchy-equivalents.json): maintained explicit
  mappings for 180 commands. **299 remain unmapped/pending review.** That isn't
  a count of 299 distinct missing user features; many are internal helpers.
- 66 commands have adapted Titan operations, 108 have partial equivalents and
  6 relate to the laptop's differing idle/power policy. Adapted means a Titan
  implementation exists, not that every hardware path was acceptance-tested.
- Refresh the inventory against the pinned clone:

  ```sh
  tools/audit-omarchy ~/.cache/titan/references/omarchy
  tools/audit-omarchy ~/.cache/titan/references/omarchy --write
  ```

  The tool refuses a revision differing from the mapping. For a new upstream
  revision, review its changes and mapping first; do not silently carry parity
  claims to changed source. It inventories files without copying source into
  Titan. This source inventory is complete; the behavioral review is not.

## Implemented in this batch

See [operations](../operations.md) for commands, state, recovery and module
ownership. The original implementation adds:

- Copied-once tmux, Git, Neovim, btop, Starship, readline and optional terminal/
  Helix dotfiles, with protected installation and backed-up reset/restore.
- Modular Bash env, aliases, functions, initializers and user extension files.
- Default terminal/browser/editor/agent choices used by existing shortcuts,
  working-directory-aware launch, exact-class focus and managed web-app launchers.
- Declarative optional package/AUR bundles and mise runtime/framework recipes;
  inspectable plans use full Arch upgrades and no implicit app installation.
- Five local Docker databases with editable Compose files, loopback ports,
  persistent named volumes and separate create/start/stop/remove lifecycles.
- Reviewed Docker, printing and Tailscale setup/status/enable/disable operations;
  explicit Tailscale login and file receipt.
- Git worktrees, safe archive operations, developer/square/swarm tmux layouts,
  owned SSH-forward sockets and event-driven rsync watcher units.
- Font selection and generated palette consumers for tmux, btop, Neovim,
  optional terminals and Helix, without replacing custom application files.
- QR encode/decode/screen capture, image/video conversion, clipboard file URIs,
  and bounded command-line audio/network/Bluetooth/battery/power operations.
- Bounded user hooks and an original optional QML panel/service plugin registry
  and loader. Plugin installation leaves code disabled; removal keeps a backup.
- Install, Setup, Services and Remove menus over the same operations, with
  package/sudo workflows in a maintained maintenance-terminal helper.

Existing bar/island, themes, capture picker, notifications, bindings, lock
recovery, distribution defaults, update/migration tooling and installer were
retained. The large reference tree remains a scratchpad, never a shipped rice.

## Remaining work and boundaries

Prioritize these against the inventory rather than repeating this foundation:

1. Runtime/service acceptance in a fresh VM: framework installs, Docker
   databases, optional terminals/editors, AUR workflows and service setup. The
   laptop lacked the required 3 GiB free-memory headroom during this batch;
   no host applications were stopped to create it.
2. Agent account lifecycle and usage dashboards, authentication integration,
   background crash/battery watchers and persistent reminders. Existing agent
   launch/skills and transient reminders are partial equivalents.
3. Richer user-theme lifecycle (install/import/remove), editor/GTK theming,
   theme hooks beyond the implemented events, external DDC brightness and
   monitor hotplug/clamshell state handling.
4. Broader plugin kinds, built-in cloning, update validation/rollback and a
   capability architecture; upstream plugins cannot simply be imported.
5. Dictation provisioning/model management, frozen screenshot selection,
   recording/webcam synchronization, generic file/timezone pickers and richer
   weather/share flows.
6. Remaining application/service integrations: proprietary services, browser
   extensions/native messaging, Windows VM, additional gaming helpers and
   retro core provisioning. Package recipes aren't complete feature setup.
7. Physical hardware/security/installation work: portable power policy,
   fingerprint/FIDO/PAM, hibernation, encrypted/dual-boot installation, GPU and
   vendor-specific fixes, bootloader integration and factory recovery. Preserve
   existing QEMU-only installer guards; use disposable hardware/VM fixtures.
   The owner's always-awake policy must stay intact.

No source material, third-party dotfiles, logos or application icons were
copied in this batch. The new code/defaults are Titan's Apache-2.0 work. Existing
MIT attribution for the earlier development-guide ports remains unchanged.
