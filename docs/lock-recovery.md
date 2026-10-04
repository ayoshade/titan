# Lock screen: diagnosis and recovery

Super+Ctrl+L runs `scripts/lock`, which starts Hyprlock with
`config/hypr/hyprlock.conf`. The lock is a Wayland session lock: until Hyprlock
confirms the right password, Hyprland shows no desktop content.

## What you may see

| Screen | Meaning | What to do |
| --- | --- | --- |
| Clock, `U M B R A / ACCESS RESTRICTED`, password field | Normal | Type your password and press Enter |
| A red line: "Too many failed attempts: locked for about N min…" | `pam_faillock` locked the account after 3 failures within 15 minutes (Arch defaults), for 10 minutes after the last one. **The right password is rejected until then** | Wait, or reset the tally from a TTY (below) |
| "Lockout over: if your password is refused once more, enter it again" | The lockout ended, but Hyprlock's next attempt started while it was active | Enter the password; if it is refused (often with a stale "N minutes left" message), enter it again |
| Lock looks frozen or ignores typing after switching to a text console and back | Seen on the Intel laptop (2026-10-03), not reproduced in QEMU. Typed passwords were rejected. Keys held during the switch (Ctrl+Alt) may be stuck | Tap Ctrl and Alt once, then type. If it stays stuck, run `scripts/lock-rescue` from a TTY. **Don't restart the display manager: that closes every app** |
| Plain near-black screen, no clock or field | Hyprlock is not drawing. The lock background is `#08090b`, so a lock with missing widgets looks black | Recover from a TTY (below) |
| Hyprland's "lockdead" screen | Hyprlock crashed; the session stays locked by design | Recover from a TTY (below) |

## Recover from a TTY

Switch to a text console with Ctrl+Alt+F3 and log in as yourself. Return to
the desktop afterwards with Ctrl+Alt+F1, or with the VT that `loginctl` lists
for your graphical session.

**First choice: `lock-rescue`** keeps your session and apps:

```sh
~/dotfiles/scripts/lock-rescue        # packaged: /usr/share/titan/scripts/lock-rescue
```

It saves diagnostics to `~/.local/state/titan/lock-rescue/TIME/`: a screenshot
of the lock, Hyprlock's journal, the process state, Caps Lock and the faillock
tally. Keystrokes are never recorded. It then replaces Hyprlock with a fresh
one. Return to the desktop, tap Ctrl and Alt, and unlock.
`--diagnose-only` saves the diagnostics without replacing Hyprlock. Restarting
greetd (`systemctl restart display-manager`) also unlocks, but it ends the
whole desktop session.

Manual steps, if needed:

```sh
faillock --user "$USER"                    # see recent failures (V = counted)
sudo faillock --user "$USER" --reset       # clear a lockout immediately

# Either relaunch the locker (Titan sets misc:allow_session_lock_restore)…
pkill -x hyprlock                          # only if one is still running but not drawing
hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("'"${TITAN_ROOT:-$HOME/dotfiles}"'/scripts/lock")'
# …or, as Hyprland's own lockdead screen suggests, end the dead lock entirely:
hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'
```

On a packaged install, the lock script is `/usr/share/titan/scripts/lock`.
After relaunching, switch back to the desktop and unlock normally. Clearing the
lock is acceptable because you have already authenticated on the TTY. Either
way, log out of the TTY afterwards with Ctrl+D.

## Why the first password after a lockout fails

Hyprlock begins its next PAM attempt as soon as one fails. `pam_faillock`
decides whether the account is locked at the start of an attempt, so an attempt
that began during the lockout fails even if the right password is entered after
the lockout expired or was reset. That failure is not recorded, and the
following attempt succeeds. This was confirmed in QEMU on 2026-10-03, with a
40-second test lockout and with `faillock --reset`.

## Diagnose

```sh
journalctl --user -t titan-lock -b         # Hyprlock's own log (since this change)
journalctl -b | grep -E 'hyprlock|faillock' # PAM results: failures and lockouts
coredumpctl list hyprlock                  # crashes
```

Report the lock state (clock visible, field visible, lockdead, plain black), the
time and these logs. A successful password check alone does not show that the
lock screen was visible.

## History

On 2026-10-03 the first reported "black screen" coincided with three failed
attempts at 03:32–03:33 and a `pam_faillock` lockout. Later attempts were
refused for 10 minutes with no on-screen reason, and Hyprlock's output was not
captured. Titan now shows the lockout on the lock screen, sends Hyprlock's log
to the journal, and allows a crashed lock to be replaced. The QEMU graphical
test (`tools/vm-test --graphical`) checks those three behaviors. Rendering
during TTY switches on the Intel laptop still needs a hands-on test.
