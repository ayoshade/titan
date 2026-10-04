# Titan branding

Root `logo.txt` and `logo.png` are the owner-supplied branding masters. Keep
their content intact; consumers read or copy these files rather than maintain
separate artwork. The PNG is 405×184 RGBA, supplied on 2026-10-04. Its SHA-256
is `8f401e9544c1b9369df994d936b5ebb7b95b2b006f9beae3fa76f7c4c637e1d2`.

Packages install both under `/usr/share/titan/`; checkout commands resolve
their root from their own location. QML uses `Paths.root`.

| Surface | Integration |
| --- | --- |
| Terminal | `titan logo [--plain]` reads `logo.txt`; neutral silver on a TTY, plain when redirected, respecting `NO_COLOR` and `TERM=dumb` |
| Setup/maintenance | Interactive setup and `scripts/titan-task` show the same text header; structured/noninteractive output stays unchanged |
| Live ISO | Both masters and the Bash logo command ship; the login banner starts with `logo.txt` |
| Welcome/About | Shared `components/TitanLogo.qml` displays root `logo.png`, preserving its aspect ratio and supplied colours |
| Plymouth | `system/plymouth/titan/logo.png` links to `../../../logo.png`; fresh installer copying resolves it into a regular target image included in the initramfs |
| ReGreet | `scripts/install-login` backs up any existing `/etc/greetd/logo.png` and installs a root-owned copy beside its CSS; the logo appears above the login card |

This follows the pinned Omarchy reference's separation of terminal text and
raster boot/login branding, adapted to Titan's Quickshell, ReGreet and original
Plymouth code. No Omarchy artwork or implementation was copied. The supplied
red/magenta PNG remains unchanged inside Titan's dark surfaces.

Welcome can be reopened with `titan-shell ipc welcome`; About is in Settings
→ System and searchable by name. Existing settings/theme choices are preserved.
The Settings About path points to the user layer, `~/.config/titan/settings.json`.

Boot/logo changes apply only to fresh experimental QEMU targets. The laptop's
bootloader and initramfs were not changed. Updating an already installed greeter
uses the existing authenticated `sudo scripts/install-login --no-packages`
workflow, which backs up the files and takes effect on the next login; it does
not restart the active session. Do not replace files under `/etc/greetd` by hand.

Custom branding edit/import/reset APIs, text-to-image conversion, animated
fastfetch About and a screensaver are not implemented by this change. Titan's
always-awake policy remains intact. See [verification](verification.md) for the
exact host and fresh-VM checks.
