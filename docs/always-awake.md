# Always-awake development laptop policy

Requested by the user for shade's laptop: no automatic sleep/hibernate, no
idle display-off, stay awake on lid closure and use Performance mode.

## User session

Hypridle is stopped and removed from session startup. Its stored configuration
has no listeners, so an accidental manual launch cannot trigger idle lock/DPMS.
The display is explicitly turned on. Manual locking still works. Reboot, logout
and power-off remain explicit user actions; the session menu has no Suspend.
The main power tile restores Performance rather than cycling to power saver.

## System installation

Run `~/dotfiles/scripts/install-always-awake` and authenticate locally with sudo.
The script verifies Performance support, backs up its destination files under
`/var/lib/titan/always-awake/backup.*`, installs root-owned logind/sleep drop-ins,
masks all five sleep targets, reloads logind, and enables/starts the Performance
service. The service disables power-profiles-daemon's BatteryAware setting and
selects Performance after the daemon starts at graphical boot. No bootloader
changes, reboot or desktop restart are needed.

## Check

Run `titan doctor`. For detailed effective settings:

```sh
systemd-analyze cat-config systemd/logind.conf
systemd-analyze cat-config systemd/sleep.conf
systemctl status titan-performance.service
busctl --system get-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles ActiveProfile
busctl --system get-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles BatteryAware
```

Expected profile: performance; BatteryAware: false. sleep.target, suspend.target,
hibernate.target, hybrid-sleep.target and suspend-then-hibernate.target must all
be masked. Inspect logind's D-Bus properties to confirm its reloaded lid/key and
idle handling. Do not invoke sleep just to test that it is blocked.

The kernel consoleblank parameter was already 0 when inspected; it was not
changed. Graphical idle blanking is controlled by the session policy above.
No critical-battery or thermal protection is disabled. The laptop needs power
to remain running; firmware may physically blank a closed internal panel.

## Restore intentionally

The installer records previous destination files and target states in its backup
folder. Restore the appropriate prior files (or remove only the added Titan
files if none existed), restore only target masks introduced by this installer,
disable the added titan-performance service, then daemon-reload and reload logind.
Restore the prior power profile/BatteryAware setting and any desired idle policy.
Review backup contents before restoration; do not unmask previously masked units
or overwrite newer user configuration. The current desktop changes are tracked
in Git and can be selectively reverted when the user requests it.
