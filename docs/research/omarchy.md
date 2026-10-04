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
  mappings for 188 commands. **291 remain pending implementation or detailed
  behavioral review.** That isn't a count of 291 distinct missing user features;
  many are internal helpers.
- 75 commands have adapted Titan operations, 107 have partial equivalents and
  6 relate to the laptop's differing idle/power policy. Adapted means a Titan
  implementation exists, not that every hardware path was acceptance-tested.
- [omarchy-port-plan.md](omarchy-port-plan.md): all originally pending commands,
  partial equivalents and policy differences grouped into 13 implementation
  batches with language boundaries, prerequisites and acceptance criteria.
  This is source triage, not complete line-by-line behavioral review. Regenerate
  it from [omarchy-port-batches.json](omarchy-port-batches.json) with `--plan --write`.
- Refresh the inventory against the pinned clone:

  ```sh
  tools/audit-omarchy ~/.cache/titan/references/omarchy
  tools/audit-omarchy ~/.cache/titan/references/omarchy --write
  tools/audit-omarchy ~/.cache/titan/references/omarchy --plan --write
  ```

  The tool refuses a revision differing from the mapping. For a new upstream
  revision, review its changes and mapping first; do not silently carry parity
  claims to changed source. It inventories files without copying source into
  Titan. This source inventory is complete; the behavioral review is not.

## Limine and language direction follow-up

Fresh QEMU installs now have an opt-in Limine path with original Bash
`lib/titan/boot.sh` and `titan boot status|refresh`. Kernel entries, user
appearance preservation, output backups and a pacman refresh hook are the
initial foundation. `omarchy-refresh-limine` is partial because snapshot
synchronization/boot/restore and live migration are still missing. See
[installation](../installation.md) and [verification](../verification.md).

Shell and QML are the owner's primary-language direction. The
[language plan](../implementation-languages.md) records where runtime Python
is concentrated and how to migrate command families without dropping their
safety or CLI contracts. Existing implementations remain supported; source
triage does not count as a completed port.

## Small portable command batch — 2026-10-04

Eight reference commands now have individually verified adaptations:
`cmd-present`, `cmd-missing`, `pkg-present`, `pkg-missing`, `pkg-drop`,
`version-pkgs`, `update-pkg-prune` and `update-mise`. Their Titan interfaces are
`titan cmd present|missing`, `titan pkg present|missing|drop|last-upgrade|cache-prune`
and `titan dev upgrade`. Mise listing/upgrade and the new package helpers use
original Bash; existing package installation/catalogs and developer recipes
remain supported through Python. JSON plans/status use the existing jq package
dependency, now also declared in the checkout workflow manifest.

These are command-level adaptations, not full updater parity. Cache cleanup and
mise upgrades are explicit operations rather than new automatic update steps.
Titan preserves pacman's confirmation/configuration backups/dependencies and
the caller's mise release-age preferences. Failed package database queries are
reported separately from absent dependencies. Cache cleanup requires the
optional pacman-contrib package and retains at least two versions.
See [operations](../operations.md) and the dated [verification](../verification.md)
entry for exact acceptance scope and host dependency limitations.

## Update readiness and stage diagnostics — 2026-10-04

`titan update check [--json] [--no-system]` provides original Bash local
readiness without privileges, package-database refreshes, remote fetches or
Titan state creation. `titan update status [--json]` reads the most recent
atomic private stage/result record and the update lock. Failures preserve the
failed stage and exit code; a failed doctor stops success reporting. A killed
updater becomes `interrupted` after inherited ordinary workers release the
lock. Read-only status does not rewrite that saved record.

The free-space helper now has a verified adaptation: Titan retains its
existing 2 GiB minimum on `/`, rather than Omarchy's 10 GiB, and rejects failed
measurements without a force bypass. The integrated update-lock equivalent
remains partial: no generic held/run API or detached privileged transaction
exists. Update-stage status is not an adaptation of Omarchy's update-availability
shell refresh command. Coverage is 75 adapted, 107 partial, 6 policy and 291
pending; no availability/channel/keyring or automatic repair parity is claimed.
See [workflow](../workflow.md) and the dated [verification](../verification.md).

Next portable work should migrate existing package transactions with their
full-upgrade, recipe and confirmation contracts. Detached update transactions,
keyring/channel validation and restart advice remain separate update work.
Keep hardware/security/authentication tasks in their own batches.

## Implemented in the initial foundation batch

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

1. Extend the now-passing `tools/vm-test --workflows` acceptance baseline:
   Node/PHP/Laravel, all five database persistence paths, optional terminals,
   Helix selection and service lifecycles are tested in QEMU (see
   [verification](../verification.md)). Other frameworks, actual AUR builds,
   external account/device integrations and SSH/rsync still need acceptance.
   The first foundation batch lacked memory headroom; the later pass ran one
   2 GiB guest at a time without stopping host applications.
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
