# Verification

## Package transaction-family Bash migration — 2026-10-04

Original Bash `lib/titan/packages.sh` now owns the whole `titan pkg` CLI:
catalog/list, bundle plans/apply, search/installed/info, add/remove and AUR
orchestration, alongside the existing predicates/drop/history/cache operations.
`scripts/titan-packages` no longer invokes Python. Direct `desktop_cli.py pkg …`
callers delegate to it, including help; the shared parser still lists pkg.
`packages.py` retains only read-only catalog/argv helpers for the remaining
Python developer provisioning and maintenance-menu consumers.

- **Contracts:** add/bundles use full Arch upgrades with `--needed`; AUR work
  follows a successful Arch upgrade and uses existing paru/yay (paru first).
  All retain native transaction/review prompts. Strict remove passes every
  requested name to pacman; drop remains idempotent. Recipe executable fields,
  repository availability and tools are checked before bundle transactions.
  Plans require jq but run no package tools/create no user state; add/remove/
  bundle plans work without pacman/sudo/Python. AUR plans still require a helper;
  bundle plans keep their descriptive paru fallback. Invalid syntax/names return
  2, migrated transaction failures/refusals 1. Empty `titan pkg` still returns 2.
- **Local:** 107 tests pass, including seven new portable-contract checks for
  the whole family without Python, restricted-PATH plans, literal arguments,
  malformed catalog/repository fields (including trailing newlines), helper
  preference/failure ordering, repository-query errors and direct Python-call
  compatibility. Bash/Python syntax checks and `git diff --check` pass.
  Local transaction tests use recorded stubs, never host package operations.
- **Host:** pacman-managed jq 1.8.2-1 is now present and `scripts/doctor` passes.
  The previous jq blocker is resolved. No package transaction, shell restart,
  theme change or power-policy change was performed on the laptop in this task.
- **Packages:** `tools/vm-test --full --stay --reuse run.OWNZaL` rebuilt the
  checkout and passed all 19 standard package/config checks. A final CLI help/
  no-argument refinement was rebuilt and installed into that same owned 2 GiB
  VM; the focused acceptance verifies the final runtime hashes without overlays.
- **Focused real acceptance:** `tools/vm-package-checks run.OWNZaL` passes six
  checks: installed runtime/catalog/menu-helper hashes; native no-state plans
  with no Python/pacman/sudo on PATH and unchanged menu command generation;
  invalid argument, missing multilib and missing-helper refusals without package
  changes; real full-upgrade install cancellation/confirmation and repeat
  `--needed` preservation; real removal cancellation/confirmation with `.pacsave`
  and Bash dependency preservation; and a real menu-generated terminal-foot
  bundle/full upgrade with byte-identical user choice JSON. Install/remove
  dialogs run through the actual `scripts/titan-task` in a pseudo-terminal.
  The guest-only fixture package/repository is removed and pacman configuration
  restored. This tests menu command adapters, not a new graphical click-through.
- **Fixture correction:** the first run piped multiple lines into the Python
  dialog; its input buffering consumed the later pacman confirmation. The menu
  check also created legacy workflow startup state in the plan-test directory.
  The corrected fixture sends PTY responses after each prompt and keeps menu
  startup state in separate test directories. Initial failure logs are retained.

Artifacts: `run.OWNZaL/{package-source.json,package-results.json,
package-commands.log,package-initial-results.json,package-initial-commands.log,
package-refresh.log}` and host `~/.cache/titan/package-migration-{build,rebuild,
local-tests,host-doctor,acceptance}.log`. The task-owned VM is stopped after
final inspection. No ISO build, signing or publication occurs.

Coverage remains 75 adapted, 107 partial, 6 policy and 291 pending of 479;
this is a verified language migration, not new chooser/provider/postcondition
parity. Actual AUR builds remain untested; local stubs verify helper selection,
full-upgrade ordering and failures, and QEMU verifies missing-helper refusal.
Next: focused `system_status.py` wrapper migration, then developer provisioning/
jobs with existing real workflow acceptance. UI motion/notification research,
detached update transactions and release preparation remain separate work.

## Update readiness, private stages and interruption diagnostics — 2026-10-04

Original Bash `lib/titan/update.sh` now owns update execution and the new
read-only `titan update check|status [--json]` interfaces. Readiness checks
commands, pacman's installed-package database/required jq/lock, root space,
the update lock, writable state and tracked checkout changes. Linked worktrees
are recognized; Git status disables optional index writes and changed filenames
are omitted. Missing snapshots/upstream are warnings. No remote or package
database is refreshed by inspection. Execution rechecks mutable prerequisites
under its exclusive lock, preserves `sudo pacman -Syu` and its confirmation,
and saves atomic 0600 machine-state records without command output.

- **Failure behavior:** required-stage errors stop later work and retain their
  exit code. Doctor failure now exits 1 instead of reporting success. INT/TERM
  save 130/143; after SIGKILL, inspection reports `interrupted` when the lock is
  no longer held, without rewriting the saved record. Ordinary workers inherit
  the update lock. Privileged pacman has its separate database lock; this is
  not detached transaction or cross-boot automatic-resume support.
- **Local checks:** 100 tests pass, including 17 update checks for side-effect-
  free inspection, absent jq, failed package queries, missing managed jq,
  low/unknown/failed free-space measurements, literal spaced paths, lock
  contention, linked record refusal, dirty linked worktrees, full-upgrade argv,
  snapshot/package/migration/doctor failures, retry and INT/TERM/KILL. Local
  transactions use recorded stubs, never host package writes. Syntax and
  `git diff --check` pass. The suite used the previously extracted official
  Arch jq/oniguruma binaries; a first run through the mise jq shim caused mise
  itself to create a parent state directory and failed the stronger no-state
  assertion. Repeating with the actual binary removes that external shim effect.
- **Host:** `scripts/doctor` still stops at missing pacman-managed jq.
  `titan update check --json` with the existing mise shims also reports that
  dependency, plus the expected in-progress checkout changes; no update was
  started on the laptop. `sudo -n true` confirms local authentication is needed.
  The terminal remedy remains `sudo pacman -Syu --needed jq`, followed by
  `titan doctor`; no host upgrade was attempted. The ordinary text readiness
  command works even without jq on PATH.
- **Packages:** `tools/vm-test --full --stay --reuse run.OWNZaL` rebuilt and
  passed all 19 standard package/config checks, including packaged doctor.
  A later read-only Git-status refinement was rebuilt and installed into that
  same owned VM before the focused suite verified the final runtime hashes.
- **Focused real acceptance:** `tools/vm-update-checks run.OWNZaL` passes all
  six checks: installed bin/library/doctor hashes; real package readiness and
  no-state inspection; held update-lock refusal; a test-owned actual pacman
  lock refusal before transactions; a real full Arch update ending at complete
  with a 0600 record and preserved theme/settings JSON; and failed/killed
  migration handling. The latter kills updater shells while their ordinary
  migration/sleep worker survives and verifies the lock stays held. After
  ending only that test process group, status reports interruption without
  rewriting the record; fixing the guest-only migration permits a normal
  successful retry. The migration is removed afterwards. No runtime source
  overlay, new ISO, signing, publishing, host shell restart or UI change occurs.

Artifacts: `run.OWNZaL/{update-package-checks.log,update-rebuild.log,
update-package-refresh.log,update-source.json,update-results.json,
update-commands.log,update-acceptance.log}` and host
`~/.cache/titan/{update-host-doctor.log,update-local-tests.log}`. The task-owned
VM is stopped after final inspection. Runtime stage status is not upstream
update availability. Coverage is 75 adapted, 107 partial, 6 policy and 291
pending of 479; only free-space gating becomes an adapted helper and integrated
update locking becomes partial.

Next: reconcile host jq through a normal reviewed full Arch transaction, then
the focused package transaction-family Bash migration. Detached privileged
updates, channel/keyring validation, automatic conflict repair, space sizing
beyond the existing root minimum and richer restart advice remain open.

## Small portable dependency/package/mise ports — 2026-10-04

Added original Bash `commands.sh`, `packages.sh` and `development.sh` with
stable routes for `titan cmd present|missing`, `titan pkg
present|missing|drop|last-upgrade|cache-prune` and existing `titan dev
tools|upgrade`. Plans were added for drop, cache cleanup and mise upgrades.
Existing package installation/catalogs and developer recipes remain Python;
compatibility dispatch also covers direct `desktop_cli.py` callers. There are
no QML, compositor, keybinding or power-policy changes in this batch.

- **Contracts:** command predicates never execute their inputs. Package
  predicates use a successful full installed-name query and distinguish an
  unavailable/failed database (exit 3) from absence. Drop deduplicates and ignores
  absent names, retains dependencies and pacman's modified configuration backups,
  and preserves confirmation. All-absent removal needs no sudo. Plans print
  requested removal names; execution filters against installed packages.
  History reads only ALPM upgrade records and returns null for an empty readable
  log, failing for missing/unreadable logs. Cache cleanup retains at least two
  versions and requires optional pacman-contrib. These helpers aren't added
  automatically to `titan update`; mise keeps the caller's release-age policy.
- **Local checks:** all 83 tests passed, including 14 new meaningful command
  checks for literal executable paths/search text, malformed package names,
  predicate/database errors, idempotent removal, plans without process/state
  side effects, catalog compatibility, failed-upgrade ordering, required
  repositories, cache retention limits, history parsing and direct callers.
  The transaction clients are recorded stubs in these local tests, never host
  package operations. Bash/Python syntax and `git diff --check` pass.
- **Host dependency:** `scripts/doctor` stops at missing pacman-managed jq.
  jq already exists as a mise-managed tool, but isn't on this agent process's
  default PATH and doesn't satisfy the package manifest. The checkout workflow
  manifest now declares the dependency already present in the Titan PKGBUILD;
  cache cleanup lists pacman-contrib as optional. Local tests used extracted
  official Arch jq/oniguruma packages under `.cache/titan/portable-tools`,
  without installing or upgrading any host packages. Existing Python package
  catalog/install routes were retained to keep current menus usable.
  Native host dependency predicates, upgrade-history text and mise listing
  passed; JSON plans also work with the existing mise shims on PATH.
- **Packaged acceptance:** `tools/vm-test --full --stay --reuse run.OWNZaL`
  rebuilt/installed the current packages through a full guest upgrade and passed
  all 19 package/configuration checks, including packaged doctor. No new ISO,
  signing or publishing operation was performed.
- **Real portable acceptance:** `tools/vm-portable-commands run.OWNZaL`
  passed all five checks. Installed hashes match the checkout. Real pacman
  predicates and JSON plans work. A valid disposable package was built in three
  versions; paccache rejected retention of one, then removed the oldest and
  kept two. Installing version three, modifying its backup-marked config and
  dropping an absent/duplicate/mixed selection removed only the owned package,
  retained custom content as `.pacsave` and kept its Bash dependency. A repeat
  drop succeeded. Real mise listing/upgrade used a separately verified isolated
  global config pinned to the installed Node 24.21.0, kept that pin and left the
  guest's normal config byte-identical. This checks pin preservation, not a new
  floating runtime download.
- **Fixture correction:** the first mise assertion checked only installed
  version presence and overlooked an inherited guest config. A stricter retry
  caught that. The final fixture sets the documented
  [mise config directory/file overrides](https://mise.jdx.dev/configuration.html)
  and runs from `/` to avoid inherited project files; it verifies the exact
  active config source and requested version before and after upgrade. Initial
  and failed-isolation logs remain alongside the successful final artifacts.

Artifacts: `run.OWNZaL/{portable-package-checks.log,portable-source.json,
portable-results.json,portable-commands.log,portable-initial-commands.log,
portable-config-isolation-failed.log}`. The task-owned VM is stopped; host
packages, applications, services, bootloader and desktop choices were unchanged.
Coverage now reports 74 adapted, 106 partial, 6 policy and 293 pending of 479:
five pending helpers and three partial helpers gained command-level adaptations.
This does not imply complete updater, hardware or distribution parity.

Next: package/update preflight and diagnostics, then a focused transaction-family
Bash migration with preserved recipe, full-upgrade and confirmation behavior.
Host dependency reconciliation still needs a normal reviewed Arch transaction;
the agent did not run a system upgrade merely to satisfy its health check.

## Confirmed offline snapshot restore and cross-boot resume — 2026-10-04

Added original Bash recovery in `lib/titan/snapshot_restore.sh`, reached through
`titan snapshot restore ID --disk DEVICE`, `restore-status`, `restore-resume`
and live `list --disk DEVICE`. Restore is confined to root in the live UEFI
QEMU ISO, an unused two-partition dedicated disk and a matching unencrypted
Titan Limine snapshot. Inspection uses read-only mounts with log replay
disabled. Both apply and resume require exact typed confirmation.

- **Recovery state:** the Btrfs top-level `titan-restore/journal.json` survives
  live reboots and the replacement of `@`. The displaced root remains at
  `@titan-before-ID-TRANSACTION`; displaced ordinary boot outputs remain under
  `/boot/titan/restores/ID-TRANSACTION/before/`. The restored root gets the saved
  kernel/initramfs and captured EFI binary/appearance. Only the captured pair
  becomes an ordinary boot entry; other snapshot previews remain available.
  Separate home/log/cache volumes retain their current contents. No snapshot,
  displaced root or backup is automatically deleted or rebooted into.
- **Local checks:** 69 tests pass through `mise exec -- python3 -m unittest
  discover -s tests -p 'test_*.py'`. New cases cover malformed/changed journal
  identity, stale numeric fstab bindings and diverted home mounts, symlinked
  journals/staging (including preparing), altered staged assets/backups/live
  destinations, and each interrupted root/boot transition. Source/argument
  refusal runs without privileged host disk writes. Bash syntax, host doctor
  and `git diff --check` pass. Doctor initially inherited a stale compositor
  instance; rerunning with the actual live instance passes. No host compositor
  reload or shell restart was necessary.
- **Packages:** `tools/vm-test --full --stay --reuse run.OWNZaL` rebuilt the
  current packages and passed all 19 package/configuration checks. The final
  ISO was then built in that VM; its checksum passes. No signing/publishing
  operation was performed.
- **Final fresh ISO acceptance:** `install.Yl6544` ran
  `tools/vm-install-test run.OWNZaL --bootloader limine --snapshot-restore`.
  The installer and all five embedded recovery entrypoint/library hashes match
  the checkout; no recovery runtime overlay was used. Fresh installation,
  ISO-detached login/Welcome, an actual LTS upgrade and boot, saved historical
  kernel preview after package removal, temporary writes/excluded mounts and
  independent normal boot all pass. Each ordinary boot passed all eight
  graphical checks, including shell/keybinding, rendered lock, VT redraw,
  rescue, lockout explanation and unlock.
- **Broken-system rehearsal:** the fixture captured Linux 7.2.8, removed its
  ordinary kernel and masked greetd. The next disk boot visibly failed to open
  `vmlinuz-linux` in Limine (capture inspected). The live fixture also corrupted
  the ordinary menu. Cancellation, an installer lock, mounted target, a mount
  appearing during confirmation and a corrupt saved kernel all refused before
  creating a journal. Live inventory and status passed with the disk unmounted.
- **Real interruptions:** SIGKILL after retaining the old root left no `@` and
  a durable `staged` journal. Another cold live boot resumed and was killed
  after installing the new root but before its checkpoint; a third live boot
  was killed during an atomic initramfs publication. Resume handled each
  completed rename, verified identities/hashes and reached `complete`.
  Cancelled resume and a new restore during the pending transaction refused;
  redundant resume after completion refused. The fixture normally released
  killed-command mounts before cold boots; production instructions use a fresh
  live boot rather than forced/lazy unmount.
- **Restored disk:** with ISO detached, the saved Linux kernel and captured
  root booted to active greetd and the Titan desktop. The root marker reverted,
  separate-volume markers kept their latest data, the displaced root kept the
  broken-system marker, the source remained read-only, and every staged/retained
  boot hash matched the journal. No capture pacman lock leaked into the root;
  normal `titan boot refresh` succeeds. Restored Welcome/desktop and recovered
  lock captures were inspected at 1280×800. All final graphical checks pass.
  The shell log retains the known missing-BlueZ and Qt portal registration
  warnings; this recovery work does not resolve those VM integration warnings.
- **Corrections retained:** the first fresh run `install.8r3BzA` exposed OVMF's
  persistent disk-first BootOrder. The harness now preserves its virtual
  variable store and uses a fresh store when explicitly booting the ISO.
  Development retries found missing executable permissions in the ISO profile
  and rejection of standalone `nologreplay` by live Linux 7.2.8; explicit file
  permissions and `ro,rescue=nologreplay` fix those. A focused recovery run with
  a development overlay passed before the final embedded-source acceptance.
  Those failures and successful retry logs remain in `install.8r3BzA`.
- **Build capacity:** a final rebuild filled the 24 GiB build guest. Its failed
  log is `run.OWNZaL/restore-iso-disk-full.log`. Only the verified stopped qcow2
  was expanded to 64 GiB; its third partition and Btrfs root were grown inside
  the guest. The rebuilt ISO passes. All task QEMU processes are stopped. Host
  disks, bootloader, services, power policy and user settings remain unchanged.

Artifacts: `install.Yl6544/{iso-source-check.json,restore-iso-source.json,
restore-snapshot.json,restore-interrupt.log,restore-resume-interrupt.log,
restore-finish.log,restore-verify.log,restore-verified.json}` and graphical
captures; `run.OWNZaL/{restore-final-packages.log,restore-final-iso-rebuild.log,iso}`.
Test ISO keys remain disposable and these images must not be distributed.

Next: bounded snapshot/ESP capacity and automatic Snapper menu synchronization,
then package-family migration to Bash. Physical-machine restore, Secure Boot,
encryption, graphical preview and a public 0.3.0 release remain outside this
verified scope. Omarchy coverage remains 66 adapted, 109 partial, 6 policy and
298 pending out of 479; this experimental recovery path does not imply parity.

## Shell service migration and matched-kernel Limine previews — 2026-10-04

`titan service` now uses original Bash in `lib/titan/services.sh`; the previous
Python service module is removed. Public commands and JSON plans remain
compatible, including full `pacman -Syu`, explicit activation units and
systemctl status exit codes. The common Python entrypoint forwards direct
internal service callers to Shell. Boot/snapshot operations also use Bash;
this is an implementation change, without language-statistics exclusions.

- **Service acceptance:** `install.cQXPpv` ran `tools/vm-workflows --only services`
  against rebuilt packages, checking source hashes, JSON plan/list, real
  Docker/CUPS/Tailscale setup, active/enabled status, disable and re-enable.
  Docker/CUPS activation sockets/path units stayed disabled; Docker did not
  reactivate through its client, and the user was not added to the Docker group.
  All three services ended disabled. VM package-server failures were resolved
  before the passing run. All Bash plans matched the previous Python JSON
  contract. The receive-path regression uses a stub client to check literal
  spaces, shell expressions and trailing newlines, plus missing-directory
  refusal before privilege invocation. No Tailscale account login or actual
  external transfer was tested.
- **Recovery preview:** `titan snapshot create|list` captures independent
  read-only Btrfs roots and matched, hashed kernel/initramfs copies on the ESP.
  Capture holds the pacman and snapshot locks, removes its transient lock from
  the private copy before sealing it read-only, checks the running/installed
  kernel pair and initramfs support, and preserves captured recovery data on
  menu failure. Refresh validates manifests/assets before replacing the menu.
  Fresh Limine installation now adds Arch's `sd-volatile` hook.
- **Historical boot rehearsal:** in `install.cQXPpv`, the guest captured Linux
  `7.2.8-arch1-2`, removed Linux from the ordinary root through pacman, and booted
  normally with LTS `6.18.55-1-lts`. Limine then booted the snapshot's saved
  Linux kernel and module tree. The root was an OverlayFS temporary write
  layer; fstab/GPT automounts were disabled and home/log/cache/ESP mounts were
  absent. Writes to their underlying directories and `/etc` disappeared after
  normal boot; all persistent baseline markers stayed intact. Refresh and
  capture refused from the preview. Native systemd can detach its lower mount
  at switch-root; the fixture allows this and rejects any visible writable
  Btrfs/FAT mount. Creation verifies the snapshot's read-only property.
  Lock contention and a deliberately corrupt saved kernel refused without
  changing the published menu. The guest restored normal boot independently.
  A fresh installer run exposed a harness ordering error: a new menu entry
  does not appear in Limine's EFI `LoaderEntries` until Limine boots again.
  The harness now performs that normal boot before selecting LTS with bootctl;
  selecting from a newly generated menu in the same session was insufficient.
- **Final fresh ISO run:** `run.OWNZaL` built a current ISO, whose embedded
  installer/entrypoint hashes match the checkout in `install.PzOqZ8`.
  The full corrected `vm-install-test --bootloader limine` passed: independent
  disk boot without ISO, all eight graphical checks on Linux, LTS and the normal
  root after preview; guarded refresh and real kernel transaction; an LTS
  snapshot boot after removing LTS from the ordinary installation; volatile
  writes, excluded-volume preservation and capture-lock removal. A final hash
  comparison matched all 78 files under `bin`, `scripts`, `lib/titan`,
  `default/config` and `default/catalog` and confirmed the retired
  Python service file is absent. I inspected the greeter, welcome/desktop and
  restored lock captures. Final CLI plan/list and ordinary-user doctor passed
  through SSH login; optional services and the uninitialized tester account
  produced warnings. Static Hyprland validation requires an ordinary-user
  login environment, not a root or bare sudo invocation. All task VMs stopped.
- **Host checks:** 63 unit/integration tests, Bash parsing, `scripts/doctor`,
  compatible JSON plan comparison and `git diff --check` passed. `doctor` now
  parses library Shell modules too. Read-only host plan/list checks used jq
  provisioned through mise (1.8.2); no host pacman packages, bootloader, power
  policy or services changed. The desktop remains usable.

Artifacts: `install.cQXPpv/{workflow-results.json,workflow-source.json,
workflow-commands.log,snapshot-prepare.log,snapshot-kernel-removal.log,
snapshot-normal-lts.log,snapshot-preview.log,snapshot-verify.log}` and
`install.PzOqZ8/{iso-source-check.json,runtime-source-check.json,snapshot.json,
snapshot-*.log,bootloader-*.log,final-cli-check.log}` plus graphical captures and
`run.OWNZaL/iso`. The failed pre-correction selector run `install.oTsbJX` is
preserved for comparison. Test ISO keys remain disposable and images are not
published.

Next: confirmed offline restore with matching boot files and interruption
recovery, automatic Snapper menu synchronization and bounded snapshot capacity;
then package-family migration to Shell. Snapshot preview is an experimental
text recovery session, not a graphical desktop or a privileged security sandbox.
No automatic snapshot deletion, complete rollback or physical firmware/Secure
Boot support is claimed. Coverage remains 66 adapted, 109 partial, 6 policy
and 298 pending out of 479; this batch does not imply full Omarchy parity.

## Limine foundation, full-command triage and language direction — 2026-10-04

The owner asked to continue the full Omarchy command port and Limine work,
then clarified that Shell and QML should be Titan's primary languages. The
new runtime boot operation is original Bash (`lib/titan/boot.sh` and
`scripts/titan-boot`), reached through `titan boot`. The existing guarded Python
installer only adds the fresh-target choice; it has not been bulk-rewritten.
`AGENTS.md` and [implementation languages](implementation-languages.md) record
that boundary and a focused migration sequence. A local byte measurement found
about 133 KB of runtime Python in `lib/` and 86 KB in tests/developer tools;
it is not accurate to attribute the language share only to tests. No language
statistics exclusions or artificial source padding were added.

- **Port audit:** source summaries, option/function names and lexical command
  references from all 299 originally pending commands were triaged against
  pinned revision `5c4da021469517449770579793b37ce26d0a0d48`. This is not a
  line-by-line behavioral review. `tools/audit-omarchy --plan --write` produces
  [13 implementation batches](research/omarchy-port-plan.md) with owners,
  language direction, prerequisites and acceptance criteria, including partial
  equivalents and power-policy differences. Regeneration is reproducible.
  Counts now are 66 adapted, 109 partial, 6 policy and 298 pending out of 479;
  the Limine refresh mapping alone moved from pending to partial. Full parity
  remains unfinished.
- **Fresh VM:** `run.OWNZaL` built a current test ISO inside QEMU. In
  `install.cQXPpv`, the ISO's embedded installer/entrypoint hashes match the
  checkout, and installed Bash boot helper, templates and CLI hashes match
  the final runtime sources (`boot-source-check.json`). Limine 12.9.1 was
  installed from Arch's official package. The ISO retains Archiso's
  systemd-boot path; the new installed disk uses the opt-in Limine choice.
- **Visible boot/login:** a 1280×800 boot frame (`boot-frames/005.png`) was
  inspected: graphite menu, Titan branding, readable kernel selection and
  countdown. The ISO-detached installed disk booted Linux 7.2.8-arch1-2;
  `bootctl status` reports Limine 12.9.1. Both before and after a real LTS
  package transaction, all eight existing graphical checks passed, including
  ReGreet authentication, first-login setup, shell/keybinding, rendered lock,
  VT redraw, rescue, lockout explanation and unlock. No Quickshell styling or
  keyboard chords changed.
- **Boot operations:** real VM checks pass for repeatable refresh and preserved
  appearance settings; physical-machine detection refusal; competing refresh
  locking; unmanaged-menu refusal; an incomplete kernel update refusing before
  either output changes; changed-menu backups and restore. These checks pass
  again after the package transaction and while booted into LTS. Status reports
  schema 1 and `snapshot_boot: false`. The helper retains changed generated
  output files as `.previous`; this is not a transactional system rollback.
- **Kernel lifecycle:** an actual full pacman transaction installed Linux LTS
  and rebuilt its initramfs. The `99-titan-limine.hook` generated the additional
  menu entry. The upgraded disk passed desktop acceptance on the default
  kernel. A subsequent explicit one-shot selection booted `6.18.55-1-lts`, with
  greetd active and all six boot-operation checks passing. The final harness
  now selects LTS for its post-transaction boot; this last selection step was
  exercised separately on the same kept disk, after the original harness
  completed. The user's default appearance/entry was restored and the one-shot
  request was consumed. The LTS Plymouth frame was also inspected.
- **Corrections/failed evidence:** an old cloud guest `run.yFc9LX` refused a
  package-file conflict left by an earlier fixture; the latest kept workflow
  guest was used instead. The first fresh Limine attempt `install.I88YNu`
  stopped before EFI deployment because the generic virtualization query
  detected the install chroot. Querying `systemd-detect-virt --vm` correctly
  identifies KVM there; a diagnostic mount confirmed target Btrfs `@`/UUID and
  FAT ESP checks before the successful fresh retry. Failure artifacts are
  retained. No physical-machine guard was removed.
- **Final packaging:** the Titan package now declares `jq` for Shell JSON
  operations, including managed systemd-boot status. A final `--full --reuse`
  run against `run.OWNZaL` rebuilt and installed that package and passed all
  19 package/configuration checks (`limine-final-packages.log`). All task-owned
  VMs are stopped; their disks, build outputs and failure logs are retained.
- **Static/host:** 61 unit/integration tests, Python compile, changed Bash
  syntax and `git diff --check` pass. `scripts/doctor` passes with the actual
  current Hyprland instance (the agent's inherited instance is stale).
  Host `titan boot status --json` is read-only and refresh refuses nonroot.
  No host packages, services, power policy, bootloader or firmware were changed.

Artifacts remain under `~/.cache/titan/vm/runs/install.cQXPpv`, including
`install.log`, `iso-source-check.json`, `boot-source-check.json`,
`bootloader-{checks,status,upgrade,after-upgrade,select-lts,lts-boot}` logs and
boot/graphical frames. `run.OWNZaL/iso` holds the test ISO and build record.
The test ISO contains a throwaway SSH public key and must not be distributed.

Still open: Limine snapshot entry synchronization with matching historical
kernel/module assets, read-only snapshot overlay boot and explicit restore;
a real Limine version upgrade, physical firmware, Secure Boot, additional
kernel flavors and existing-machine bootloader migration. The laptop keeps
systemd-boot. Next boot milestone is the snapshot path in the
[boot batch](research/omarchy-port-plan.md#boot); next language migration is a
focused package/service command family with its VM lifecycle checks.

## Workflow VM acceptance and provisioning corrections — 2026-10-04

The modular workflow foundation now has repeatable real-package acceptance:
`tools/vm-test --workflows` implies full/graphical installation, then runs the
guest-only `tests/vm_workflows.py` through `tools/vm-workflows`. The companion
checks its QEMU owner PID and guest identity and compares installed library,
configuration and catalog hashes with the checkout. Logs, JSON results and
captures stay outside Git, under the disk-backed VM run directory.

- **Corrections found through acceptance:** PHP/Laravel previously failed at
  `buildconf` without build dependencies, and Composer's fixed HTTP URL had no
  version source. PHP recipes now install the required Arch dependencies;
  Composer uses its stable-version feed, semantic ordering and versioned URLs
  ([mise HTTP documentation](https://mise.jdx.dev/dev-tools/backends/http.html)).
  Docker disable left its socket active; enable/disable now manages Docker's
  socket and CUPS's socket/path units too. Arch's Helix package exposes
  `/usr/bin/helix`, so the editor selection now uses that wrapper.
- **Visual correction:** all initial automated workflow checks passed, but
  inspecting Foot's capture revealed an invalid generated `[colors]` section.
  The generator now uses `[colors-dark]`, following the
  [Foot manual](https://man.archlinux.org/man/foot.ini.5.en). The app fixture
  now runs `foot --check-config` and `ghostty +validate-config`, waits for the
  terminal text frame and captures all three optional terminals. Final captures
  show readable acceptance text and graphite backgrounds in Foot, Ghostty and
  Alacritty, with no configuration banner. Helix health and Neovim's actual
  headless configuration load pass; this does not verify every editor feature.
- **Guest/kernel:** `run.vs1w8a` exposed a cloud-image harness problem: a full
  upgrade replaced the running kernel's modules, so Docker couldn't create its
  networking rules. `vm-test` now reboots only the guest when its running kernel
  has no installed module directory. This path passed in fresh `run.OWNZaL`
  (7.2.7 → 7.2.8). No host reboot, application termination or service change.
- **Package and graphical baseline:** 19 package checks and 8 graphical checks
  pass: package setup, configuration/layers, theme/settings restoration, real
  ReGreet authentication and Welcome, workflow binding, rendered lock, console
  return redraw, lock rescue, lockout and unlock. Welcome and the rendered lock
  were visually inspected in the VM at 1280×800.
- **Real provisioning:** all 15 workflow checks passed in `run.OWNZaL` after
  the provisioning fixes. Node 24.21.0 executes through mise and interactive
  Bash; PHP 8.5.11, Composer 2.10.3 and Laravel Installer 5.32.0 execute after
  the Laravel recipe (about 217 s). Docker, CUPS and Tailscale setup/status/
  disable pass; activation units are inactive/disabled afterward, and a Docker
  client cannot reactivate the disabled daemon. No Docker-group membership.
- **Databases:** PostgreSQL, MySQL, MariaDB, Redis and MongoDB each bind only
  to guest loopback, accept a local TCP connection and preserve a written test
  record through stop/start and Compose down/recreation. Named volumes remain.
  They run sequentially in the 2 GiB guest. Readiness probes use TCP/database
  queries to avoid temporary initialization servers. MariaDB's io_uring
  fallback and Redis's overcommit warning remain in the logs; load/pressure
  behavior was not tested and no host sysctl was changed.
- **Preservation and boundaries:** real package reinstall, repeated setup,
  migrations and backup/reset/restore preserve custom tmux content and current
  theme/settings. The fixture reloads the guest compositor after pacman has
  finished replacing its watched Lua file, then verifies no config errors.
  AUR-helper and multilib refusal checks leave pacman's package list unchanged.
  Terminal launches execute a real command in the requested directory and
  restore the original terminal/editor choices and open panel.
- **Final focused checks:** after the Foot correction, the kept guest was
  rebuilt/retested with `--graphical --stay --reuse`, then
  `tools/vm-workflows RUN --only apps` and `--only preservation` passed with
  hashes matching the final sources. This avoided repeating unaffected runtime
  builds/database tests. Final evidence is `workflow-results-full.json`,
  `workflow-results-apps.json`, `workflow-results.json` (preservation), their
  command logs and `workflow-{foot,ghostty,alacritty}.png` in `run.OWNZaL`.
  Initial failures are retained in `run.vs1w8a`. An edit to the running Bash
  harness interrupted one handoff after graphical checks; the finalized
  harness completed on resume. Both task VMs were stopped; disks/logs retained.
- **Host/static:** all 57 unit/integration tests pass after the final production
  change; Python/Bash syntax, `scripts/doctor` and `git diff --check` pass.
  Doctor used the actual current Hyprland instance rather than the agent
  process's stale inherited instance ID. No new QML or compositor styling.

Still open: other framework/runtime recipes (including Symfony's CLI), actual
AUR builds, external Tailscale login/receipt and physical printing, SSH/rsync
acceptance, font switching, richer editor/theme behavior and hardware paths.
The successful local package pass is not a public 0.3.0 release or ISO test.

## Modular Omarchy workflows and local agent references — 2026-10-04

Reference: `omacom/omarchy` revision
`5c4da021469517449770579793b37ce26d0a0d48`; see
[the agent reference library](research/agent-references.md) and
[coverage ledger](research/omarchy.md). The local Quickshell 0.3.1 Process and
FileView pages were read for argv and file-watch behavior. The archive's 790-page
coverage wasn't independently re-audited here. Original code/defaults were
written; no Omarchy implementation or external desktop configuration was copied.

- **Automated:** 57 unit/integration tests pass. New cases exercise copied-once
  dotfiles, linked-directory refusal, backed-up reset/restore including Unicode
  and CRLF, launcher serialization and unsafe URLs, invalid default choices,
  side-effect-free package/runtime plans, database loopback ports/data volumes,
  archive roundtrip/traversal refusal, hook failure/argument boundaries,
  plugin installation/enable/disable/removal, Bash user-value preservation,
  generated theme files, four actual tmux panes on an owned socket and actual
  MP4/GIF/PNG conversions with output preservation. The existing first-login
  fixture now includes the new helper/modules and still preserves Welcome.
- **Static:** doctor passes on umbra, including new Bash modules; Hyprland
  config verification and live configerrors are clean. PluginHost and shell
  lint cleanly. CommandPanel has the pre-existing qmllint warning for unresolved
  `QProcess::ExitStatus` signal parameters; its exit code is 0. Runtime reloads
  report `Configuration Loaded`, with no corresponding runtime error.
- **Live menu:** inspected a UI crop of Application bundles at 1366×768, scale
  1, the owner's current everforest/theme-accent choice. 24 searchable catalog
  entries were loaded, with consistent rows/icons and no clipping in the
  visible first ten. The menu was closed afterward. Package installation and
  sudo transactions were not triggered. Other new menus were not individually
  visually inspected.
- **Live extension:** installed an original temporary nonvisual fixture,
  enabled it, and observed `Titan acceptance plugin: theme context received`
  in the shell log. Disabled and removed it afterward. The fixture's removed
  copy is retained under `state/titan/plugin-backups/`; no extension remains
  enabled. Third-party manifests and capabilities were not tested.
- **Activation:** ran the sole pending `1791096000-developer-defaults.sh`
  migration. Ten missing files were installed and report `default`; all prior
  migration markers remain applied. Regenerated application palettes from the
  current everforest theme. Shell status afterward still reports everforest,
  theme accent, bar visible, wallpaper enabled and no open panel. No new
  packages/services were installed or enabled on the laptop.
- **Dependency review:** official package names were checked against the
  local configured Arch databases. Steam requires the currently disabled
  multilib repository; its bundle checks for it before a transaction. LocalSend
  uses an explicit AUR recipe rather than an unavailable official package.
  Runtime tool names were checked with the installed mise registry; Composer
  and Symfony use documented explicit HTTP/GitHub backends. Those downloads
  and full framework installs were not executed.
- **Limits:** no QEMU/package/service acceptance run: MemAvailable was about
  1.75 GiB, below the harness's 3 GiB threshold for its 2 GiB guest. No host
  applications were terminated to free memory. Database startup/data persistence,
  SSH authentication/forwarding, rsync event delivery, optional terminal reloads,
  font switching, QR camera capture, service/AUR installation and physical
  hardware remain unverified. Full Omarchy parity is unfinished; the inventory
  explicitly distinguishes adapted, partial, policy and pending commands.

`git diff --check` passes. CLI usage, layers, agent guidance and design research
notes were updated. Follow the remaining-work ledger before repeating this batch.

## Completed during setup

- All manifest packages installed from Arch repositories, including Hyprland
  0.56.2-3 and Quickshell 0.3.1-1.
- `Hyprland --verify-config`: config ok; live `hyprctl configerrors`: empty.
- Bash syntax checked for all scripts; bootstrap run twice successfully.
- Live Quickshell loaded without runtime warnings after corrections.
- IPC exercised for launcher, controls, notifications, session, close and
  brightness OSD. No suspend, shutdown or reboot action was executed.
- Desktop, control center, launcher and notification history visually inspected
  at the physical 1366×768 resolution.
- Network list populated through native API without disconnecting Ethernet.
- Native notification delivered and rendered in retained history.
- PipeWire sink volume, battery, brightness, and power profile populated.
- Kitty and Thunar launched; Hyprland reports `xwayland: false` for both.
- Hyprland explicit DPMS-on Lua dispatcher returned ok and remained on across
  repeated calls. Idle commands use table arguments with an explicit action.
- Initial Hyprlock rendering stalled during TTY switching. Immediate rendering
  and disabled locker animations were applied. The replacement subsequently
  logged successful PAM authentication, unlocked and exited. The user regained
  the desktop. Reliable visible lock rendering during TTY switching remains
  unresolved; successful authentication does not establish that it is fixed.
  No password was collected by the agent.
- GTK, Hyprland and core XDG portals active.
- NetworkManager, Bluetooth, power profiles and UFW remain active.
- Quickshell resident memory observed around 202 MiB after opening all panels;
  process lifetime CPU around 0.9% during interactive checks. These are a brief
  observation, not a steady-state benchmark.

## Hands-on checks still required

1. Lock after a TTY switch on the laptop: fixed by `scripts/vt-redraw` and
   confirmed by the owner on 2026-10-03 (see below). The QEMU test now covers rendering, crash restore
   and faillock lockouts; see "Lock screen diagnosis" below and
   `docs/lock-recovery.md`.
2. Suspend/resume verification is deferred: the user now requires always-awake
   operation and all sleep targets are masked. Only test it after an explicitly
   requested change to that policy.
3. Test actual speaker/microphone output, audio-device switching, brightness
   keys and media playback with an MPRIS-capable application.
4. Join a known Wi-Fi network and pair a Bluetooth device. Ethernet remained
   connected during setup; credentials and radio state were not changed.
5. Print: select a region, verify the saved PNG and clipboard paste.
6. Firefox: test file dialogs and an explicit screen-sharing request. Portal
   activation was checked; no external call was initiated.
7. Plug in an external monitor if used; verify scaling, bar and focused-screen
   overlays. Only the internal screen was available during setup.

Run `~/dotfiles/scripts/doctor` for repeatable static/package/service checks.
The script does not claim to validate real authentication, suspend, hardware
output, screen-share negotiation or device pairing.

## Kernel observation

At 03:36:59 on 2026-10-03 the kernel logged a missing SystemCMOS address-space
handler for region CMS0 and aborted ACPI method `_SB.PC00.LPCB.EC0._Q33` with
AE_NOT_EXIST. This was after the initial black-screen report. The observation
does not establish a causal connection to Hyprlock. The rtc_cmos driver exists
and RTC devices rtc0/rtc1 are present. No ACPI overrides, firmware changes,
kernel parameters or bootloader edits were applied.

## Graphical login setup

- Installed greetd 0.10.3-2, greetd-regreet 0.5.0-1 and Cage 0.3.1-1.
- TOML parsed successfully; installed ReGreet and Cage CLI options checked.
- greetd systemd unit validates; display-manager.service points to greetd.
- greetd enabled, graphical.target default confirmed. The service was not
  started over the current TTY/desktop.
- Installed config and greeter stylesheet match the reviewed repository files.
- greeter account and ReGreet state/log directories exist with correct ownership.
- ReGreet demo launched and loaded the dark configuration; native login user
  shade and installed Wayland sessions were detected. Demo exited afterward.
- Preview reported a system locale C warning, benign GTK empty-declaration
  warnings, and missing remembered state before the first real login.
- Real reboot/login verified on 2026-10-03: greetd opened a session for shade,
  Hyprland started, and Quickshell/Hypridle launched automatically. Core system
  services and the repeatable doctor checks passed after reboot. No automatic
  login is configured.

## Dynamic-island redesign — 2026-10-03

- Studied English auto-captions from saneAspect's October 2 workspace-island
  video and October 1 design discussion; inspected sampled frames of the
  latest video and the full September 19 visual walkthrough. Source links and
  adaptations are recorded in design-reference.md.
- Rebuilt the bar as a centered island with native reactive workspace marks,
  compact clock/status icons, two side buttons and expanding hardware OSDs.
- Visually inspected controls, launcher, connections, calendar, appearance,
  session, media, notifications and toast at 1366×768. The test workspace was
  closed and the original workspace restored after captures.
- Runtime opened every panel without warnings in the final clean shell run.
  Launcher icons have a local vector fallback for unavailable theme icons.
- Accent preference written through native FileView, persisted across shell
  restart, then restored to silver. Original landscape rendered successfully.
- Volume OSD rendered without changing volume; native notification appeared
  both as a centered toast and in the history panel.
- All QML passed syntax parsing. Static qmllint still has upstream type-analysis
  warnings; this is not a claim of a warning-free static type check.
- Doctor, compositor validation, live configerrors and git diff checks passed.
- No additional packages, system login edits, boot edits, destructive operations,
  radio changes, suspend or power actions were needed for the redesign.
- Actual playback/artwork, tray menu interactions and external-monitor behavior
  remain hands-on checks. Existing authentication/suspend limitations above
  remain; this visual redesign does not resolve them.
- Final shell RSS observed at 203728 KiB (about 199 MiB), with 0.6% CPU over
  one five-second idle sample after panels closed. This is a brief observation,
  not a sustained performance benchmark.

## Theme switcher

- Inspected the reference video’s theme-picker frame at 05:50 and rebuilt the
  horizontal search/palette-card layout in Quickshell.
- Nine palette catalogs validated for unique IDs, valid RGB tokens and six
  swatches each. Unknown IDs reject without changing generated files.
- Live picker loaded without runtime warnings and fits the 1366×768 screen.
- Applied Nord through the native IPC/Process path; shell state and generated
  Kitty palette matched. Live compositor configuration errors remained empty.
- Saved palette survived shell restart; Graphite was restored after testing.
- Super+T binding verified in the live compositor. Doctor and QML syntax
  parsing passed. Pointer/keyboard navigation still benefits from user feedback.
- Theme application affects Quickshell, Kitty and Hyprland borders. It does not
  swap GTK themes, browser styling or wallpapers.
- Shell restart now waits for the old instance to release its single-instance
  lock, preventing the replacement from exiting during a restart race.

## Omarchy-inspired shortcuts

- Inspected current Omarchy application, tiling and utility bindings from its
  public quattro branch; sources and Titan mappings are in docs/keybindings.md.
- Added focused-window close, window/workspace cycling, scratchpad, grouping,
  swaps, resizing and installed-application aliases using native Hyprland Lua.
- Moved theme selection to Super+Ctrl+Shift+Space; Super+T now toggles floating.
- Static compositor validation, live reload/configerrors and doctor passed.
- Live binding inventory resolves all keys. Only intentional Alt+Tab focus/raise
  pairs share a chord. At this earlier stage physical codes were replaced with US keysyms based on
  an incorrect interpretation of empty exported key/keycode fields. The complete
  binding audit below corrects that finding: codes are supported internally.
- No user windows were closed, moved, grouped or resized during verification.
  Actual keypress behavior is a hands-on check; loaded bindings alone do not
  prove every compositor action under all window/layout states.

## Always-awake policy — live verification

- User ran scripts/install-always-awake with local sudo authentication. Original
  system destination files/target states are backed up under
  /var/lib/titan/always-awake/backup.sPyeT4. Initial profile was Performance with
  BatteryAware enabled; future installer runs also record those property values.
- Verified all five sleep targets masked and Performance service active/enabled.
- Live logind D-Bus properties report ignore for lid (all modes), sleep keys,
  power button and idle action. Reload completed without a session restart.
- ActiveProfile is performance, BatteryAware is false. System templates match
  installed files and the service completed successfully in the journal.
- Hypridle is stopped and absent from session-start. Stored idle config has no
  listeners. Monitor reports dpmsStatus true. Consoleblank was already 0.
- Automatic locking was removed with the idle timers; manual locking remains.
  Suspend tile is replaced by an always-awake indicator. Core checks and changed
  QML syntax passed; no actual sleep/lid test was forced on the running session.
- Configuration is persistent, but reboot behavior has not been exercised for
  this policy. Power loss and firmware/thermal protections remain physical limits.

## Complete Omarchy binding audit — 2026-10-03

- Pinned reference a85e29abb556816f4644cf975e98da694b486aa8; inspected all
  six binding files and relevant helper behavior. Executed reference and Titan
  registration in isolated mocked Lua environments and compared normalized
  modifier/key/release multisets: 231 expected, 231 actual, no missing or extra
  chords. Optional preinstalled application keys enabled; voxtype absent in both.
- Read the installed Hyprland commit's Lua parser: physical codes are stored in
  sMkKeys, while its exported key/keycode fields can be empty. Restored the exact
  physical codes from Omarchy. This corrects the earlier inventory interpretation.
- User installed the official workflow package set. Package checks pass; the
  event-driven titan-clipboard user service is active. Its initial unsupported
  size flag was corrected to an explicit bounded read and supported cliphist
  flags. No existing clipboard content was exposed in diagnostic output.
- Live picker test added eight scoped bindings, returned 0,0 1366x768 for full
  monitor selection, and removed all eight bindings on close. No screenshot of
  the user's working applications was saved as a project artifact.
- Created an isolated special-workspace test window. Tiled fullscreen on/off,
  floating/pinning on/off, width save/restore and transparency ran successfully
  against that address. Only the test window was closed; user windows were not
  closed or altered by these helper tests.
- Bounded calculator accepted arithmetic and rejected code execution, indexing
  and excessive powers. An isolated clipboard database retained exactly 100
  after 102 stores and excluded a marked-sensitive test item. Real clipboard
  contents and the user's database were not read for those tests.
- Eighteen new Quickshell menus opened and closed with no new runtime warnings.
  Root menu visually inspected at the laptop resolution. User-selected palette
  and unrelated generated theme changes were preserved.
- Top-bar visibility was changed through typed IPC, persisted to private state
  and restored to its original value.
- Doctor, compositor validation and live configerrors passed. Always-awake
  targets remain masked, Performance is active, BatteryAware is false and no
  hypridle process runs. No lock, sleep, logout, shutdown or close-all test ran.
- Exact chord parity is not a claim of every Omarchy feature/application being
  present: optional apps, shared panel equivalents, always-awake exceptions,
  live rather than frozen selection, and transient reminders are documented.
  Physical keyboard, external monitors, webcam, actual recording/OCR, media
  output switching and reliable Hyprlock rendering remain hands-on checks.

## Notch geometry match — 2026-10-03

- Measured saneAspect's compact island from native 1080p frames (J8s7O2IGogE,
  10:30–10:55) and rebuilt `modules/Bar.qml` to match it.
- The live shell was restarted with `scripts/shell-restart`, and no QML runtime
  warnings were logged. A grim capture measured the pill at 230×33, top y=11,
  centred on eDP-1. The volume OSD expansion and clock panel were opened through
  IPC and displayed correctly. `scripts/doctor` passed.
- Not hands-on tested: pointer clicks on workspace marks, the clock and status,
  the low-battery colour, and a Wi-Fi signal (this machine was on Ethernet).

## Island dashboard — 2026-10-03

- Built the click-expanded dashboard from frames of J8s7O2IGogE (10:36–10:55,
  including 30 fps transition scans). Reference and Titan were compared side by
  side at 1:1 scale.
- Live checks: the shell reloaded with no runtime warnings after fixes. The
  dashboard opened and closed through `ipc call shell island`. Rapid grim captures
  confirmed the open overshoot (peak ~650×167, settling at 648×167) and the
  height-then-width close. `scripts/workflow game-mode` was toggled on and off: all
  three Hyprland options went false, then were restored to true, and the runtime
  state file was removed. `scripts/workflow toggles` reported both states.
  `scripts/doctor` passed.
- An invalid fractional `font.pixelSize` briefly stopped the shell from loading
  during development. Run a live reload after QML edits, because qmllint did not
  catch it.
- Not hands-on tested: the media row with a live MPRIS player (none was playing),
  pointer hover/leave collapse, Escape, the Night light chip (it would start
  wlsunset), clicking workspace rows, and a dashboard on a second monitor.

## Island calendar morph — 2026-10-03

- Measured the reference calendar state from 30 fps frames (J8s7O2IGogE
  10:37.4–10:39.3). It is 336×280, and pointer leave collapses it to compact.
- Live checks: the calendar was opened through IPC from the dashboard. Rapid
  grim captures showed 648×167 → 334 (undershoot) → 336×280. Closing narrowed
  first, then dropped height to 230×33. The calendar matched the reference
  side by side at 1:1.
- Found and fixed: the fixed-height layer surface clipped the calendar at 199 px
  until it was sized to the tallest state.
- Not hands-on tested: pointer clicks on the month buttons, wheel paging,
  Left/Right keys and Super+Ctrl+Alt+D.

## Control center, Settings, wallpapers and dashboard fix — 2026-10-03

- **Dashboard clicks (user report):** workspace rows in the dashboard did not
  respond. Debug logging showed that exclusive keyboard focus made Hyprland
  send the island a pointer leave as it opened; the leave timer then collapsed
  it. On-demand focus keeps hover. Scripted pointer warps only produce
  enter/leave events, so this was verified through hover and enter logging,
  not real clicks.
- **Control center:** opened through IPC; the main page and Wi-Fi drill-in
  rendered with no warnings. Bluetooth, Sound and Display pages were not
  opened in this session.
- **Settings window:** floats at 820×560 through `config/hypr/rules.lua`, and
  `hyprctl configerrors` is clean. Bar & Island, Appearance, Motion and System
  were captured. A `scripts/workflow settings set islandWidth 300` change
  resized the live island, `reset` restored it, and an out-of-range value
  exited 1. Notch mode was toggled on, inspected and reset.
- **Wallpapers:** applying nord switched the wallpaper to the nord set, the
  theme and wallpaper carousels rendered, and `wallpaper next` crossfaded.
  Industrial was then restored, with Blacksite pinned as its wallpaper. The
  first fetch mapped pastel accents to greys, so those sets were replaced
  after the colour match became hue-aware.
- **A broken hot reload:** a missing `;` briefly broke the hot-reloaded
  configuration. The previous generation kept running behind an error banner
  until the fix.
- **Not hands-on tested:** real clicks on dashboard rows, control-center tiles
  and Settings controls; Bluetooth connect; per-app volume; the
  wallpaper-carousel keyboard; font changes across all panels.

## Menus, session, notifications and media — 2026-10-03

- **Menus:** the launcher, the Titan root menu, the toggle submenu and
  keybindings were opened through IPC and visually compared with the
  reference launcher frames. A
  `count` id collision first left the lists empty; it was fixed and verified.
- **Session menu:** rendered with tiles. The control-center power strip was
  checked with lint only, because opening it needs a click.
- **Notifications:** three test notifications showed the toast below the
  island, and the notification center grouped them by app with "+1 more".
  They were dismissed afterwards. The media panel rendered the blurred
  album-art card.
- **Game-mode bar:** `workflow game-mode` showed the full-width bar; toggling
  again restored the island, and the Hyprland effects read back as enabled.
- **Night light:** at 3500 K, `wlsunset -t 3500` ran, then it was turned off
  and the setting reset.
- **Shell freezes (twice):** `qs kill` sometimes leaves Quickshell deadlocked
  while exiting, holding the instance lock, so the desktop had no responsive
  shell. Recovery was SIGKILL and a relaunch. `scripts/shell-restart` now
  escalates and passed three consecutive restarts.
- **Doctor:** it had failed since `fetch-wallpapers` was added, because it
  ran `bash -n` on a Python file. It now parses scripts by shebang and exits 0.
- **Not hands-on tested:** clicks in the power strip and session confirmations
  (deliberately not confirmed), launching apps from the new launcher, menu
  submissions (calculator, reminder), emoji copy, and notification actions.

## Quickshell exit crash, root cause — 2026-10-03

- A symbolized core (`coredumpctl debug 23078`, using Arch's debuginfod)
  shows `qFatal("QPixmap: Must construct a QGuiApplication before a
  QPixmap")`. It is raised from `QWindow::unsetCursor()` while
  `QQuickItem` destructors run after the application object was destroyed.
  This is an upstream Quickshell 0.3.1 teardown bug, not Titan QML. It explains
  the SIGABRT and SIGSEGV cores and the occasional hang on `qs kill`; the
  workaround is the escalating `scripts/shell-restart`. The procedure is
  recorded in `default/agents/skills/diagnose-crash/SKILL.md`.

## Phase 1: user layer, version, migrations — 2026-10-03

- **Live migration:** before running, the old state, the tracked preferences,
  generated files and `mimeapps.list` were backed up to the session scratch
  directory. `titan migrate` then applied `1791060086-user-layer.sh` on this
  machine:
  - the industrial preferences moved to `~/.config/titan/preferences.json`;
  - settings moved to `~/.config/titan/settings.json`;
  - `~/.config/mimeapps.list` became a real file and kept the Claude Code
    handler;
  - the generated Kitty theme was byte-identical to the old tracked file;
  - `hyprctl configerrors` was empty.
- **Repeat runs:** a second `titan migrate` reported nothing pending.
- **Throwaway homes:** in an old-layout home, settings moved, the user layer
  was created and the theme was generated, and a re-run was a no-op. On a
  fresh home, `--mark-all` recorded the migration without running it.
- **Round-trip:** after a clean `titan-shell restart` (no shell warnings),
  `titan theme nord` changed the shell, the user preferences, the generated
  Kitty file and the Hyprland border (88c0d0). `titan theme industrial`
  restored them. `git status` showed no user changes: switching themes no
  longer dirties the checkout.
- **titan-app template:** rebuilt and run; it followed industrial → horizon
  live through the new paths.
- **Sound page fix:** its PipeWire tracker referenced `parent` from a
  non-Item, so per-app volume tracking got `undefined`. It now uses an id.
- **Not exercised:** `titan update`, because it needs sudo and the network.
  The user should run it the first time.
- **Snapshots:** `scripts/install-snapshots --dry-run` on this machine detected
  btrfs `subvol=/@`, no existing Snapper config, and missing
  `snapper`/`snap-pac`, and listed the five intended actions. The real run
  (sudo) is pending the user. Neither `undochange` nor the full rollback in
  `docs/snapshots.md` has been rehearsed; do that in a VM.
- **`TITAN_ROOT`:** after the change, `hyprctl configerrors` was empty and the
  restarted shell process carried `TITAN_ROOT=/home/shade/dotfiles`
  (inherited from Hyprland's `hl.env`). `titan-shell ipc theme industrial` ran
  `apply-theme` through `Paths.script()`. The root menu opened, and the shell
  log was free of Titan warnings. Not exercised: key-triggered lock and
  session-start, which run at the next login.
- **First real update and snapshot setup (run by the user, checked
  read-only):**
  - `titan update` upgraded hyprland 0.56.2-3→-4 and libutf8proc; the kernel
    was unchanged, so no reboot was needed.
  - `scripts/install-snapshots` installed snapper 0.13.2 and snap-pac 3.0.1,
    created the `root` config and took snapshot 1 ("titan: snapshots enabled").
  - Config check: TIMELINE_CREATE=no, NUMBER_LIMIT=10/5, ALLOW_USERS=shade,
    and `snapper-cleanup.timer` is active. `snapper-timeline.timer` is enabled
    but creates nothing while the timeline is off.
  - snap-pac's pre/post pair appears at the next pacman transaction.

## Phase 1: packaging and first run — 2026-10-03

- **Hyprland:** with `base` taken from `TITAN_ROOT`, `Hyprland --verify-config`
  printed `config ok` and live reloads had no errors.
- **Existing install:** `titan migrate` applied `1791060868-first-run-markers`
  here (setup-version and welcome-done recorded).
- **Welcome screen:** it did not open after a restart, because the marker
  exists. It rendered when opened through IPC. With the marker moved aside it
  opened by itself at startup (panel `welcome`); the marker was restored
  afterwards.
- **Packages:** `makepkg` built `titan` (208 entries: no `__pycache__`, `.git`
  or user files) and `titan-desktop` (40 dependencies).
- **Packaged tree:** extracted into a throwaway root, with a fresh home:
  - `titan setup` created the user layer, the thin Kitty config, the GTK and
    mimeapps defaults and the graphite theme;
  - both migrations were recorded as done;
  - `Hyprland --verify-config` on the packaged config printed `config ok`;
  - the packaged shell QML linted cleanly.
  The test's `gsettings` and `systemctl --user` calls hit this real session
  but set values it already had.
- **Repository:** `build-repo --channel edge` produced a valid repository
  database. A stable build correctly refused uncommitted changes.
- **`vm-test --full`: passed all 14 checks** on Arch's official cloud image
  (QEMU/KVM, 2 GB, kernel 7.2.7) after `qemu-base` was installed.
  - A full `pacman -Syu`, then `titan` and `titan-desktop` with all 40
    dependencies installed.
  - `titan setup` worked on the first run and on a repeat.
  - The default theme is graphite, and no migrations were pending.
  - The user layer, thin Kitty config, `/etc/xdg` shell and Titan session
    file were all present.
  - Hyprland accepted the packaged config, and the shell QML parsed.
  - Settings and theme round-trips worked.

  Two earlier attempts failed because this laptop's OOM killer ended QEMU:
  the VM had 4 GB on a 7.5 GB host, and its overlay disk was in the
  RAM-backed `/tmp`. `vm-test` now keeps runs under `~/.cache/titan/vm/runs`,
  defaults to 2 GB (`--memory`), refuses to start without enough free memory,
  and stops at once if QEMU dies. Package installs run as a detached
  `systemd-run` job polled over short SSH calls. A graphical login to the
  Titan session is still untested (Phase 2).

## First public release — 2026-10-03

- **Published:** `scripts/publish-repo --channel stable --sign 8A648F6B462B95C6
  --yes` published Titan 0.2.0 as the `repo-stable` release, with 12 assets:
  both packages, the database and files lists, and a `.sig` for each. The
  owner entered the passphrase in GPG's own prompt.
- **Visibility:** `ayoshade/titan` was private, so release assets returned
  404 to anonymous clients. With the owner's approval the repository was made
  public (a history scan found no secrets; the commit email and laptop notes
  are visible). The first anonymous requests still returned 404 for a short
  time while GitHub propagated the change.
- **Anonymous check:** an unauthenticated download of `titan.db`, both
  packages and their signatures, verified against
  `raw.githubusercontent.com/.../keys/titan-packager.asc`, gave "Good
  signature" for all three. The database lists `titan-0.2.0-1` and
  `titan-desktop-0.2.0-1`.
- **Install from the public repository: passed.**
  `scripts/vm-test --full --from-repo` followed the documented user steps on a
  clean Arch cloud VM:
  - the public key came from raw.githubusercontent.com and was added and
    locally signed;
  - `[titan]` was appended to `pacman.conf`;
  - `pacman -Syu titan-desktop` ran with default signature enforcement;
  - pacman reported `Validated By: SHA-256 Sum  Signature`.

  All 14 checks passed.

## Documentation audit and package release 2 — 2026-10-03

- **Documentation audit:** every repository path in the README, AGENTS.md,
  docs and skills was checked against the tree (only intentional examples
  remain). Every `titan-shell ipc`/`ipc call shell` function exists in
  `shell.qml`, every `scripts/workflow` operation in the dispatcher, every
  setting in the schema, and the live bind count is 231. The README was
  rewritten from the current code.
- **Packaging gap:** the published `titan 0.2.0-1` lacked `packages/`,
  `system/` and `keys/`. So `titan doctor`, `install-login` and
  `install-always-awake` could not work on packaged installs. `doctor` also
  wrote bytecode and required developer links. Release 2 ships those
  directories, and `doctor` is mode-aware: static checks are fatal, and on
  packaged installs missing packages, setup and optional services are
  warnings. On this laptop it behaves as before.
- **VM test:** `vm-test --full` on the local 0.2.0-2 build passed 16/16,
  including `titan doctor (package mode)` and the shipped login inputs.
- **Release 2 published:** `titan 0.2.0-2` was signed and published, and the
  stale `-1` package was pruned. `titan-desktop` stays `0.2.0-1` because its
  contents did not change.
- **Install from the published repository:** `vm-test --full --from-repo`
  passed 16/16, with `Validated By: SHA-256 Sum  Signature`.

## Phase 2: experimental ISO and dedicated-disk installation — 2026-10-03

- **Development version:** 0.3.0-1, not published or signed. Stable remains
  0.2.0-2. The new installer checks repository version before erase and refuses
  the older stable channel; these installation tests used an explicit unsigned
  repository available only to the disposable QEMU guest.
- **Complete install and independent boot: passed.**
  `scripts/vm-install-test` booted the newly built UEFI ISO using OVMF and a
  blank 40 GiB qcow2 disk. The real installer:
  - accepted the exact erase confirmation and terminal password prompts;
  - created GPT, 1 GiB FAT32 EFI and Btrfs `@`, `@home`, `@log`, `@pkg`;
  - installed Arch base, hardware packages, `titan` and `titan-desktop` 0.3.0-1;
  - generated locale/fstab, created a wheel account, locked root password
    login, enabled login/network/Bluetooth/power services and installed
    systemd-boot and the Titan Plymouth hook/theme;
  - unmounted its target without requesting a reboot.

  The harness added test-only SSH access, stopped that VM, **detached the ISO**
  and booted its installed disk. Btrfs root and active greetd were checked over
  SSH. ReGreet authenticated a new account into `titan-session`; Hyprland had
  no config errors; Quickshell IPC returned `panel=welcome`, `theme=graphite`,
  `screen=Virtual-1`. Setup-version exists and welcome-done does not.
- **Visual review:** QEMU screenshots at 1280×800 showed the centered Titan
  wordmark/progress dots, dark ReGreet login, wallpaper and first-login Welcome.
  Eighty boot frames were captured and inspected as contact sheets, with the
  splash, greeter and Welcome also viewed at full size. There is a brief
  libseat seatd-probe message before Cage falls back successfully to logind.
  This boot handoff still needs polish; it was not hidden or mistaken for a
  failed login. No host application screenshots were taken or committed.
- **Runtime limits:** the installed shell log has a BlueZ object-manager
  warning (the VM has no Bluetooth adapter) and a Qt portal app-registration
  warning. Configuration loaded and IPC responded. The earlier cloud-image
  test also warned about missing network/UPower/power-profile services; the
  complete desktop now declares those packages in `packages/services.txt`.
  The installed-disk shell no longer reports those missing backends.
- **Package regression:** the final `vm-test --full --reuse …` passed **17/17**
  on 0.3.0-1, including the explicit requested-version check, setup repeat,
  theme/settings preservation and round-trips, packaged Hyprland/QML and doctor.
  Reuse previously selected old archives already in the guest's home: it now
  installs exact current-version filenames from a dedicated test directory.
- **First-login regression:** `titan-session` creates the state directory and
  setup.log before setup. Treating that directory as an existing installation
  ran the legacy welcome-marker migration on a fresh user. Setup now ignores a
  lone setup.log when deciding freshness. A real fresh login shows Welcome;
  a throwaway-home regression verifies fresh markers, repeat behavior and
  preservation of an existing Hyprland override without touching host services
  or applying a theme.
- **Safety/unit checks:** 11 tests cover whole-disk boundaries, nested mounts,
  swap, storage holders, read-only/small/loop targets, non-live/non-QEMU apply
  rejection, development repository bounds, account/timezone validation,
  first-login detection and Intel/AMD/virtual/NVIDIA/unknown hardware selection.
  Host `scripts/doctor`, live `hyprctl configerrors`, script/Python syntax and
  `git diff --check` passed. The internal mounted NVMe was rejected by the
  read-only planner; no host partition or boot changes were made.
- **ISO build:** Archiso 91-1, built as root inside the isolated QEMU build
  guest, UEFI systemd-boot profile, zstd SquashFS. The ISO is ≈1.6 GiB and its
  SHA-256 check passes. An early launch failed because Archiso normalizes file
  permissions; the executable is now explicitly declared in file_permissions.
  A separate launch was interrupted by editing the running Bash harness;
  the successful run used a syntax-checked file. No disk writes happened in
  either of those failed launches.

  Local test image: `~/.cache/titan/vm/runs/run.mkTYG7/iso/`.
  Passing installed-disk artifacts: `~/.cache/titan/vm/runs/install.QsLfLe/`
  (install plan/log, hardware, shell status/logs, UI screenshots and boot
  frames). The final ISO already contained the overlaid installer module;
  the harness used the same source. Test images contain an ephemeral SSH
  public key and must not be distributed. All QEMU processes were stopped
  after verification.
- **Still open:** encryption, dual boot/manual partitioning, wider VM and
  multi-monitor coverage, real GPU/laptop tests (especially NVIDIA), smoother
  splash-to-greeter handoff, signed 0.3.0 channel testing, ISO source/license
  review and a public image without test access. Suspend/lock rendering on the
  development laptop remains untested under its always-awake policy.

## Omarchy developer skills port — 2026-10-03

The initial location and registration described below were corrected in the
following handoff section. The current inventory is `docs/agent-skills.md`.

- Reviewed all seven guides in Omarchy's `agents/skills/` at quattro revision
  `8e02fc84f5bdc511ed102e2a14f8935bba4f92bd`, plus its existing end-user skill
  inventory. Added `titan-commands`, `titan-installation`, `titan-shell-dev`,
  `titan-icons`, `titan-acceptance-tests`, `titan-visual-verification` and
  `titan-migrations`. The three existing Titan end-user skills are preserved.
  Commands, paths, SVG assets, shell lifecycle, setup, migration semantics and
  QEMU test interfaces follow Titan's implementation rather than nonexistent
  Omarchy compatibility APIs. Source mappings are in `docs/agent-skills.md`.
- Retained the full upstream MIT license in `default/agents/LICENSE.omarchy`,
  declared the adaptation in `NOTICE`, and installed its license text under
  `/usr/share/licenses/titan/`. No Omarchy executable, font, plugin registry or
  dotfiles were installed.
- Added `titan skills [--dry-run]` with complete destination preflight,
  CODEX_HOME support, idempotent links and refusal of custom entries/broken
  foreign links. Setup/update register new bundled skills, warning on conflicts
  without replacing personal skills or preventing desktop setup.
- **Local registration passed:** ten bundled directories resolve correctly in
  both Codex and Claude; the seven new skills are linked to the checkout. A
  subsequent preview is silent. All ten skill frontmatters pass the
  skill-creator validator; local Markdown references resolve. Validator PyYAML
  lives only in a disposable cache venv, not Titan's runtime dependencies.
- **Automated checks passed:** 17 unittest checks (six new registration tests
  plus the existing eleven), including preview without writes, path relocation
  with spaces, custom CODEX_HOME, repeat without replacing links, preservation
  of personal skills/broken links, atomic conflict refusal, blocked parent
  directories and invalid arguments. The first-login fixture also exercises
  setup's registration in an isolated HOME/CODEX_HOME.
- **Package VM checks passed: 18/18.** The rebuilt 0.3.0-1 development package
  installed after a successful full upgrade in the reused disposable QEMU
  guest, and setup linked every bundled skill for both agents. Both license
  locations were verified. Artifacts/log:
  `~/.cache/titan/vm/runs/run.mkTYG7/install.log`.
- Two earlier package checks failed on missing new links: the guest had a
  stale pacman database lock, so the package transaction never ran. The harness
  incorrectly accepted a previous install success marker. It now clears that
  marker before each job, requires systemd's successful Result as well as the
  new marker, and preserves the installation log. The unused lock was removed
  only inside the disposable guest after checking for active pacman/lock users;
  the complete package run then passed. No host package transaction ran.
- Host `scripts/doctor`, Bash syntax and `git diff --check` pass. The live shell
  still responds with the user's industrial theme on eDP-1. No QML/compositor,
  boot, power or shortcut settings changed; no visual or lock/suspend test was
  needed for the guide/registration work. The test VM was stopped on exit.
- New sessions can discover the linked skills. There is no persistent bundled
  skill opt-out yet: removing a discovery link is reversible, but setup/update
  registers it again. Static guide validation and package integration checks
  do not claim forward-testing every development recipe or a new public release.

## Development and end-user skill locations corrected — 2026-10-03

- The user clarified the two locations: all seven development guides now live
  in `agents/skills/`; `default/agents/skills/` contains exactly `titan`,
  `titan-app` and `diagnose-crash`. The guides were moved intact, with the MIT
  notice at `agents/LICENSE.omarchy`. AGENTS task links, documentation, NOTICE
  and the package's license source path now match this layout.
- Development guides are read through repository `AGENTS.md`. Setup/update
  and `titan skills` scan only end-user defaults. Packaging excludes the
  repository's `agents/` tree while retaining the upstream license in
  `/usr/share/licenses/titan/`.
- Removed only the fourteen mistaken development-guide symlinks created by
  the preceding task in the owner's Codex/Claude skill directories, checking
  their exact targets first. The three end-user links in both homes and all
  unrelated skills were preserved. No desktop configuration or service changed.
- Validation passed: all ten skill definitions and their relative references,
  AGENTS links, Bash syntax, `git diff --check`, host doctor, and 18 unittest
  checks. Registration tests include a checkout with both trees and prove only
  the three defaults are registered while a personal development skill remains
  untouched.
- The rebuilt package archive contains only the three end-user SKILL.md files
  and the license. `scripts/vm-test --full --reuse …` passed 18/18 in QEMU,
  explicitly asserting three packaged/registered end-user skills and no
  `/usr/share/titan/agents` tree. Artifacts remain in
  `~/.cache/titan/vm/runs/run.mkTYG7/`; QEMU stopped on exit. No ISO, graphical
  layout, lock or suspend retest was needed for this location correction.

## Installer interruption recovery — 2026-10-03

- Added an atomic, private live-session journal under `/run/titan-installer/`
  with installer checkpoints, disk identity, intended mounts, filesystem UUIDs
  and subvolume roots. It excludes passwords, subprocess input/output and
  command arguments. `titan-install --status [--json]` reads the journal and
  current mounts without creating state. `--recover --disk DEVICE` requires
  the live root/UEFI/QEMU guards and an exact `RECOVER DEVICE` confirmation.
- Recovery rechecks identity and mount ownership after confirmation, refuses
  outside mounts/swap, holders, changed filesystems, unrecorded/foreign mounts
  and busy filesystems, and uses ordinary recursive unmount (never lazy/force).
  It removes only the empty retry directory and preserves partial disk data.
  A fresh install still requires another ERASE and new password entry. This is
  cleanup and restart recovery; resume across live boots is not implemented.
- Installer commands inherit an exclusive operation lock. A surviving worker
  retains it when its installer is killed. Ordinary failures record the failed
  step and attempt safe unmount without hiding the original command error;
  interrupts leave the mounts for explicit recovery. Completed installs record
  `installed`/`complete` after cleanup and leave no target directory or mounts.
- **Local checks passed: 33 unittest checks**, including identity/UUID/boot
  changes, wrong Btrfs subvolume, mounts appearing during confirmation, outside
  mounts/swap, busy cleanup, cancellation, wrong disk, corrupt journals,
  nonempty-directory preservation, inherited child locks, journal write failure,
  CLI read-only JSON enforcement and non-live recovery refusal. Host doctor,
  Python/Bash syntax and `git diff --check` passed. The package baseline VM
  regression also passed 18/18.
- **Live failure and recovery checks passed** with
  `scripts/vm-install-test RUN --recovery` on a new 40 GiB QEMU disk:
  - an injected pacstrap exit 72 recorded `failed`/`base-packages`, preserved
    that error and released all target mounts;
  - a SIGKILL left the checkpoint and five filesystem mounts; recovery refused
    while the surviving test worker retained the inherited lock;
  - a foreign tmpfs stacked on `/boot` was refused and remained mounted;
  - a process holding the target as its working directory caused a real busy
    unmount failure, retaining the retry marker;
  - cancelled and wrong-disk recovery changed nothing; confirmed recovery then
    removed the target mounts/empty directory while preserving both filesystem
    labels. A new separately confirmed installation proceeded successfully.
  Fault injection is confined to the test harness, not shipped installer flags.
- **Current ISO and independent boot passed.** A new ISO was built in QEMU and
  its SHA-256 verified. Before any development overlay, both embedded installer
  files matched the current checkout hashes (`iso-source-check.json`). The final
  install status was `installed`/`complete`, `busy=false`, no target directory
  and no mounts. The harness detached the ISO and booted the installed disk,
  authenticated through ReGreet and verified first-login setup/Welcome, the
  graphite shell on Virtual-1 and empty live compositor errors. Greeter and
  Welcome screenshots were visually inspected at 1280×800. The VM shell still
  reports the previously documented missing-BlueZ-adapter and Qt portal
  registration warnings; this change does not resolve them.
- **Build capacity:** the reused 24 GiB build guest filled during an initial
  ISO rebuild. Its log is retained as `build-iso-recovery-disk-full.log`. Only
  that verified VM was stopped; its qcow2 disk was expanded to 64 GiB, then its
  third partition and Btrfs filesystem were grown inside the guest. The rebuild
  passed. No host disk, partition, bootloader, package, power policy or desktop
  configuration changed. All task-owned QEMU processes stopped; the owner's
  industrial shell still responds and live `hyprctl configerrors` is empty.
- **Artifacts:** current test ISO/build logs under
  `~/.cache/titan/vm/runs/run.mkTYG7/`; passing recovery/install logs, source
  hashes, status JSON and graphical captures under
  `~/.cache/titan/vm/runs/install.VqHudD/`. The previous ISO is retained under
  `run.mkTYG7/iso/previous/recovery-baseline/`. Test images contain temporary SSH
  access and must not be distributed; nothing was signed or published.
- **Next work:** encryption, interrupted-install resume across boots, wider
  VM/hardware coverage, signed 0.3.0 upgrade/install validation and public-image
  source/license review remain open. The laptop's visible lock rendering and
  other hands-on hardware checks remain separate outstanding tasks.

## mise as the default tool manager — 2026-10-03

- Added `mise` to `packages/workflow.txt` (so `titan-desktop` depends on it),
  `default/bash/rc` (activates mise only when installed), and
  `scripts/install-bash-defaults` (appends one marked line to `~/.bashrc`),
  called by `titan setup` and migration `1791072383-bash-defaults-mise`.
  `hyprland.lua` prepends the mise shims directory to the session `PATH`, guarded
  against duplicates on config reload.
- Verified in throwaway homes: a missing `~/.bashrc` is created, an existing one
  is only appended to, a second run changes nothing, the migration applies the
  same hook, and a shell without mise still loads cleanly.
  `Hyprland --verify-config` passes and the Bash syntax checks pass.
- The owner installed mise 2026.10.0 and moved `gh` to it (`mise use -g gh`,
  2.102.0; the copied `~/.local/bin/gh` was removed). Interactive Bash resolves
  `gh` through mise, the shim works with the existing `gh` login, and
  `scripts/doctor` passes again.
- Not yet verified: shim PATH in a live session needs a Hyprland
  restart (or a new login) and a `mise use -g` tool launched from a keybinding.

## Layout split step 1: developer tools in `tools/` — 2026-10-03

Following `docs/layout-plan.md`, `build-iso`, `build-repo`, `publish-repo`,
`vm-build-iso`, `vm-graphical`, `vm-install-test` and `vm-test` moved from
`scripts/` to `tools/`. Each still resolves the root from its own location, so
only callers and docs changed. Historical entries above keep their old paths.

- Verified: Bash/Python syntax of all tools, `scripts/doctor` (now also parses
  `tools/*`), 33 unit tests, and `tools/build-repo --channel edge` builds both
  packages; the `titan` package contains no `tools/` or VM/build/publish scripts.
  `tools/vm-test` gained a check that developer tools are not packaged.
- Not yet verified: `tools/build-iso --prepare` (needs archiso, absent on this
  laptop) and the VM runs (`vm-test --full`, `vm-build-iso`, `vm-install-test`).
  These are part of step 5 of the plan.

## Layout split steps 2–4: public commands in `bin/` — 2026-10-03

`titan`, `titan-shell`, `titan-session`, `titan-install` and `workflow` moved to
`bin/`, with relative `scripts/NAME → ../bin/NAME` compatibility links. Callers
updated: Hyprland bindings, `Paths.qml` (`workflow`, new `bin()`), Quickshell
users of `Paths.workflow`, `lib/titan/workflow.py`, helper scripts, `bootstrap`,
the PKGBUILD (`/usr/bin` links, `bin` copied) and the ISO (`/usr/share/titan-installer/bin/`).
`bin/workflow` now resolves its root through `readlink -f` like the others.
Migration `1791073344-public-commands-bin` repoints checkout `~/.local/bin` links
and reports (never rewrites) user files found by `scripts/legacy-paths`.

- Verified on umbra: 37 unit tests, including a new `tests/test_layout.py`. It checks
  the links, that no code in the tree calls the compatibility paths, and that the
  migration relinks, reports, leaves user files unchanged and is idempotent.
  `scripts/doctor` passes with the new bin/ checks. qmllint shows no errors.
  After `hyprctl reload` there are no config errors and 231 binds. The shell hot
  reload logged no errors and IPC responds. `titan settings/theme/shell`,
  `bin/workflow toggles` and the `scripts/workflow` compatibility path all work.
  The live migration repointed `~/.local/bin/titan{,-shell}` and found no
  user-file references.
- Not verified: a keypress through a `workflow` binding. Bindings are Lua
  closures, so the command path was checked in source, not inspected live.
  Also untested: the packaged layout in a VM, an upgrade from 0.2.0 with an
  old-path `hypr.lua`, and ISO build/install with the moved `titan-install`.
  All three belong to step 5.

## Layout split step 5: VM verification — 2026-10-03

All runs used the local 0.3.0 build of `6dd8bd2`, one 2 GiB VM at a time.

- `tools/vm-test --graphical --stay` (`run.yFc9LX`): all 19 package checks
  passed, including the new "developer tools are not packaged" check. Both
  graphical checks passed (ReGreet login, first-login setup, live shell). The
  desktop capture showed the Welcome screen over the shell. In the guest,
  `/usr/bin/titan*` resolve into `/usr/share/titan/bin/`, the five
  `scripts/NAME → ../bin/NAME` links exist, `tools/` is absent, and both
  `bin/workflow` and `scripts/workflow` work. The shell log errors were only
  the cloud VM's missing NetworkManager/BlueZ, the same as in earlier runs.
- `tools/vm-build-iso` in that VM built `titan-0.3.0-2026.10.04-x86_64.iso`,
  and its checksum passed. `tools/vm-install-test RUN --recovery`
  (`install.iavM9l`): the ISO's `bin/titan-install` and `install.py` match the
  checkout. Every recovery check passed (failed package step, killed installer
  with a surviving worker, foreign and busy mounts, cancel/wrong disk, confirmed
  recovery), then a fresh UEFI/Btrfs install booted to ReGreet and the shell.
- Upgrade (`run.aWcZ55`): installed the published stable `titan-desktop` 0.2.0
  through the documented steps. Two current checks fail there as expected
  (0.2.0 predates the skill scope and still ships the VM tools). Added a
  `hypr.lua` bind and a user unit that both call `/usr/share/titan/scripts/…`,
  then ran `pacman -U` with the 0.3.0 packages. `/usr/bin/titan` moved to
  `bin/titan`. `titan migrate` applied the mise and bin migrations, listed both
  user files with line numbers without changing them, and a second run reported
  none pending. The old `scripts/workflow` path still works. `titan doctor`
  passes with the legacy-path warning, and the packaged Hyprland config
  verifies. mise was installed as a new dependency and is active in
  interactive Bash.
- Still open: the version
  bump/release, and removing the compatibility links one release later.

## Lock screen diagnosis and QEMU lock test — 2026-10-03

- **Journal evidence (previous boot):** three failed attempts at 03:32:21–03:33:15
  triggered `pam_faillock` ("account temporarily locked"). A later Hyprlock was
  told "temporarily locked out" at 03:35:17. Hyprlock's own output was not
  captured, and there are no hyprlock core dumps. Arch's faillock defaults apply
  (deny 3, fail_interval 900 s, unlock_time 600 s). The first "black screen"
  report therefore at least overlapped a lockout during which the right
  password could not work.
- **Found in QEMU:** Hyprlock 0.9.6 shows PAM's "(N minutes left)" for only about
  2 s. Its input field faded out while empty, so an idle lock showed only the
  clock on `#08090b`. After a lockout expires (tested with a 40 s VM-only
  `unlock_time`) or is reset, the first correct password is still refused with
  a stale message. The attempt began during the lockout, it is not recorded,
  and the second try unlocks. Attempts refused during a lockout add no tally
  record, and the tally clears after expiry.
- **Changes:**
  - `scripts/lock` sends Hyprlock's output to the journal (`-t titan-lock`).
  - The `misc:allow_session_lock_restore` option is on.
  - `hyprlock.conf` keeps the field visible (`fade_on_empty = false`, an
    adaptation for clarity) and adds a `scripts/lock-status` label. The label
    reports the lockout and its remaining minutes, and then the "enter it
    again" hint.
  - New `docs/lock-recovery.md`.
- **QEMU graphical test, extended and passing:** a real Super+Shift+Backspace
  `workflow` binding toggles gaps and back. Super+Ctrl+L renders the lock
  (framebuffer measured, capture inspected: clock, label, field). A
  `kill -KILL` of Hyprlock shows Hyprland's lockdead screen, and the documented
  `hyprctl --instance 0 dispatch` relaunch renders the lock again. Three wrong
  passwords show the red lockout line, the right password stays refused,
  `faillock --reset` follows, and the unlock succeeds on try 2.
- **lock-status cases checked with a fake faillock:** a lockout, failures within
  and beyond `fail_interval`, an ended lockout, and invalid entries.
- **On umbra:** Hyprland reloads without config errors and
  `allow_session_lock_restore` is on. No lock was started on the owner's
  session. Still open: a hands-on Super+Ctrl+L on the Intel laptop, including a
  TTY switch while locked.

## Lock after a console switch (laptop) and lock-rescue — 2026-10-03

- **Owner test:** Super+Ctrl+L showed the clock, label and field, and the password
  unlocked. With the screen locked, switching to a text console and back left
  the lock looking frozen and ignoring typing. The owner restarted greetd from
  tty2, which ended the session.
- **Journal:**
  - The 20:14 lock got four "stray release" key events at the return
    (20:14:22). Three typed passwords then failed (20:14:51–20:15:16),
    `pam_faillock` locked the account, and greetd was restarted at 20:26:21.
  - The 20:28:41 lock logged two "key already pressed" events at 20:28:58,
    and greetd was restarted at 20:29:02.
  - Aquamarine logged "Restoring after VT switch" and restored the CRTC.
    Hyprlock received key events, so input reached it. Hyprland's own logging
    is disabled, so its render and keyboard state are not recorded.
- **QEMU:** not reproduced. Ctrl+Alt+F2, typing on tty2, then Ctrl+Alt+F1 with
  quick QMP keys and with separate slow press/release events: the correct
  password unlocked first time, with no key errors after the return.
- **Leading hypothesis (unconfirmed):** Ctrl/Alt state is lost across the
  switch on real hardware, so typed letters arrive as shortcuts (no dots, wrong
  password). Verbose Hyprland/Hyprlock input logging was deliberately not
  enabled, because it could record the password.
- **Added `scripts/lock-rescue`** for use from a TTY:
  - It saves a lock screenshot (grim works from outside the session while
    locked; verified in QEMU), Hyprlock's journal, the process state, Caps
    Lock, the faillock tally and the sessions. It never records keys.
  - It then replaces Hyprlock in the same session.
  - The QEMU graphical test now uses it for the restore stage. A fresh VM
    passed all 19 package checks and 7 graphical/lock checks.

## Cause of the post-console-switch freeze; vt-redraw — 2026-10-03

- **Owner run 3** (with a VT trace recording only `/sys/class/tty/tty0/active`
  changes): locked at 21:01:45, left for tty3 at 21:01:50.927, and returned to
  tty1 at 21:02:00.044. Hyprlock's next output configure came at 21:02:28.033.
  The owner waited 15 s, then typed: dots appeared and the unlock was
  immediate. Run 2: blind password authenticated at 20:59:35, but "Unlocking
  session" waited for the configure at 20:59:40. Aquamarine's log shows
  "Restoring crtc 151" followed by several keystrokes ("palm: keyboard
  timeout") before "Modesetting eDP-1". Conclusion: input works, but Hyprland
  defers the restoring modeset until a frame is requested, and an idle lock
  requests none. The stuck-modifier hypothesis is withdrawn.
- **Fix:** `scripts/vt-redraw`, started by `session-start` and logged with
  `-t titan-vt-redraw`.
  - It waits on sysfs notifications for `tty0/active`, with no polling.
  - When `XDG_VTNR` is active again it runs
    `hl.dsp.force_renderer_reload()`; the dispatcher was confirmed on umbra.
  - It exits when the Hyprland instance directory disappears.
- **QEMU:** the session started vt-redraw automatically, and it fired once on
  the return to tty1, not on leaving. A new graphical stage (Ctrl+Alt+F2 → F1
  while locked: one redraw, rendered lock) passed on a fresh VM, along with
  the other stages.
- **umbra, owner test:** returned to tty1 at 21:18:30.672. vt-redraw fired, and
  Hyprlock's configure arrived at 21:18:30.899, 0.23 s later; it was ~28 s
  before the fix. Dots appeared immediately, and the password unlocked at
  21:18:33. Confirmed.

## Hands-on workflow binding and mise PATH on umbra — 2026-10-03

Closes the two hands-on items left open by the bin/ layout split and the mise
change.

- **workflow keypress:** the owner pressed Super+Shift+Backspace twice. The
  `bin/workflow gaps` binding toggled `workflow.json` and the live layout
  (21:24:17: `gaps=false`, `gaps_in` 5; 21:24:20: `gaps=true`, `gaps_in` 0),
  returning to the owner's no-gaps choice. The binding path through `bin/`
  works from a real key, not only in QEMU.
- **mise shims in the session:** the running Hyprland session started at 20:29,
  after the mise change. A command started through `hl.dsp.exec_cmd`, the
  dispatcher every exec binding uses, received
  `~/.local/share/mise/shims` first on `PATH`, resolved `gh` to the mise shim
  and ran it (2.102.0). Processes Hyprland had already spawned (`vt-redraw`,
  Xwayland) carry the same `PATH`. No Titan binding launches a mise tool
  today; the check used a temporary dispatched command, not a key.

## saneAspect batch: toggles, game mode, scale chips, screen corners — 2026-10-03

Research: captions of nKomstQedmE and OeT5VgeLSIQ read in full, with native
frames sampled (see `docs/research/shell-panels.md`). rLFFjT6kAkA and
wcm95W876OU were not reviewed in this batch.

- **Island toggle announcement:** on umbra (1366×768, scale 1, theme industrial,
  accent theme), `bin/workflow nightlight` on, then off, was captured with grim:
  the pill kept its 230 px width and showed the ring, moon and "Night Light", then
  the slashed icon, then returned to the workspace marks, clock and status. No
  desktop notification was sent while the shell ran. Night light was restored
  to off.
- **Game mode:** toggled on and off live. Hyprland reported animations, blur and
  shadows off, rounding 0 and border 0, then 16 and 1 again with everything back
  on. The full-width bar showed the gamepad announcement, and the saved state file
  was removed afterwards.
- **Screen corners:** grim captures of the top-left and bottom-right corners show
  the black rounded corners at 14 px; the layer is `umbra-corners` with an empty
  input region. Clicks through a corner were not tested by hand.
- **Display scale chips:** the Display page was opened by temporarily making it
  the default control-center page (reverted). It shows eDP-1 with 1.0× selected
  and 2.0×; 2.0× was not clicked, so applying a scale from a chip is untested
  live. `scale set` validation (unclean value, unknown monitor, missing argument)
  and game-mode restore, including a state file saved by the previous version,
  are covered by `tests/test_workflow_display.py`.
- **Settings:** Bar & Island shows the Screen corners switch and radius.
- **Checks:** 42 unit tests pass, `scripts/doctor` passes, qmllint reports no
  errors (only the usual uncreatable PanelWindow warning), the live shell
  reloaded without errors, and `git diff --check` is clean.
- **Still open:** clicking a scale chip on a monitor with more clean scales,
  pointer pass-through at a corner, and the reference's game-bar contents,
  game-mode notification tab, notifications inside the island, two-phase notch
  morph, spring motion and screenshot-blur lock screen.
