# Implementation languages

The owner's direction (2026-10-04) is Shell and QML as Titan's primary
implementation languages. Use Bash for command routes, provisioning,
package/service operations, update/recovery and desktop tool orchestration;
use QML and native Quickshell services for reactive desktop state and UI.
Hyprland configuration stays Lua. New Omarchy workflow ports follow this
boundary instead of adding another Python runtime family by default.

The existing Python architecture is a real implementation choice, not only
an effect of counting tests: large command families live under `lib/titan/`,
and their executable wrappers dispatch to a common Python parser. That choice
helped share JSON validation, atomic writes and argument handling, but it
expanded Python beyond the owner's intended workflow architecture.

A local byte count around commit `3b2207e` found roughly 233 KB of Python,
157 KB of QML, 93 KB of Shell and 20 KB of Lua. Python comprised about 133 KB
under `lib/`, 70 KB of tests, 16 KB of developer tools and 15 KB of executable
entrypoints/wrappers. These are approximate extension/shebang-based measurements,
not a reproduction of GitHub Linguist's percentages. [GitHub Linguist](https://github.com/github-linguist/linguist/blob/main/docs/how-linguist-works.md)
language shares are size-based and include eligible test/development code;
they are not a measure of desktop process language or CPU time.

No Linguist exclusions, padding or source-generation tricks are used to alter
those percentages. Shell/QML should grow through actual implementation choices.
Python remains suitable for developer analysis/tests and structured algorithms
where there is a concrete benefit. Record exceptions before adding new runtime
Python modules; this does not require stopping routine authorized work for
approval.

## Focused migration sequence

1. Implement new system workflows in Shell now: the initial Limine helper is
   `scripts/titan-boot` plus `lib/titan/boot.sh`.
2. Service lifecycles now use `lib/titan/services.sh`; the Python service module
   has been retired after real Docker/CUPS/Tailscale VM checks. Continue with
   package operations and simple wrappers from `packages.py` and
   `system_status.py` one family at a time. Keep the public
   CLI, structured status, confirmation boundaries and exit codes; use `jq`
   for JSON and argv arrays for subprocess arguments.
   Dependency predicates (`commands.sh`), package predicates/drop/history/cache
   helpers (`packages.sh`) and mise list/upgrade wrappers (`development.sh`) now
   use Bash. Update readiness/status and staged execution live in `update.sh`,
   preserving full upgrades and recording failures/interruption for inspection.
   Package installation/catalogs and developer recipes/databases remain
   Python until their transaction/provisioning paths pass a focused migration;
   this keeps existing menus usable on checkouts missing jq.
3. Migrate developer environment/jobs, defaults/launchers and configuration
   operations with their existing real-VM acceptance checks. Keep user data,
   backups, locks and old paths compatible throughout.
4. Move reactive desktop logic into QML/native Quickshell APIs where appropriate;
   do not add polling or process wrappers to replace an existing native service.
5. Review remaining Python deliberately, including the guarded installer,
   archive traversal checks and generated palette handling. Do not remove a
   proven safety boundary merely to change the language chart.

Migrations must preserve behavior: full Arch upgrades, local authentication,
quoted filenames/URLs, atomic state changes, side-effect-free status and
recoverable failures. Run the affected CLI and VM checks before retiring the
old implementation. The [Omarchy port batches](research/omarchy-port-plan.md)
track feature work separately from this language migration.
