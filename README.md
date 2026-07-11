# Ubuntu Touch for Redmi Note 10 Pro (sweet/sweetin)

Fixes and a single-flash installer on top of the existing Ubuntu Touch / Halium port for the
Xiaomi Redmi Note 10 Pro (`sweet`, India variant `sweetin`, SD732G).

I didn't do the original port — that's **dopaemon**'s work from 2022, flashable zip put together
by **Erfan** and **Nobi Nobita** (installer pattern based on osm0sis's anykernel2 script). What's
in this repo is the LineageOS+UBports single-zip merge and the bug fixes on top, all mine.

## What's new: one zip instead of four steps

Used to be: flash firmware, flash LineageOS, format data, flash UBports — four separate manual
steps, each one a chance to mess it up. Now it's one zip, one `twrp install`. See
[`installer/`](installer/) for how — short version: TWRP auto-creates device-mapper nodes for
LineageOS's dynamic partitions at boot, so the whole LineageOS side just becomes `dd` calls
straight onto those, no nested `twrp install` needed. `format data` turned out to need its own fix
too — more in the installer README.

## Fixes

- **Vibration didn't work** — the haptic chip reports FF support but the actual FF upload silently
  fails on this kernel. Talks to the chip directly now. ([`fixes/vibrator-aw8624/`](fixes/vibrator-aw8624/))
- **Status bar covered the camera cutout** — no `deviceinfo` entry existed for this device, so UI
  rendered at desktop scale. Added one, split the status bar around the notch (portrait only —
  landscape correctly falls back to the original all-right layout).
  ([`fixes/deviceinfo/`](fixes/deviceinfo/), [`fixes/unity8-shell/`](fixes/unity8-shell/))
- **Wireless display toggle was hidden** — the property that gates it in Settings was never set.
  ([`fixes/wireless-display/`](fixes/wireless-display/))
- **Restart missing from the power menu**, Report a bug / UBports Help cluttering it up, and
  Shutdown/Restart sharing one confusing combined screen instead of a plain yes/no each.
  ([`fixes/indicator-session/`](fixes/indicator-session/), [`fixes/unity8-shell/`](fixes/unity8-shell/))
- **Long-press an app in the drawer** to pin/unpin or jump to its OpenStore page.
  ([`fixes/unity8-shell/`](fixes/unity8-shell/))
- **Battery icon stuck at 0%/flashing** — indicator-power was reading a decoy
  battery-authentication chip instead of the real battery. ([`fixes/indicator-power/`](fixes/indicator-power/))
- **Restart disappearing again after a fresh flash** — a separate indicator-session gate that
  assumes Unity shows its own combined shutdown/reboot dialog. ([`fixes/indicator-session/`](fixes/indicator-session/))
- Holding back ~175 packages known to brick this exact image if apt updates them.

Each folder under `fixes/` has the actual patched files and the real story of what was broken.

## Installing

Flash MIUI firmware via fastboot first (not part of any zip here, has to happen before anything
else). After that, flash the single zip from [`installer/`](installer/) through TWRP.

**Known issue, unsolved:** the boot logo sometimes stalls and the screen goes black/unresponsive a
minute or so in. Force-rebooting fixes it every time it's happened so far. Never figured out the
actual cause.

## Credits

dopaemon (original port), Erfan + Nobi Nobita (original flashable zip), osm0sis (anykernel2
pattern this installer is built on) — respect to all of them. Everything else here, Craftparking.

Issues/questions welcome if you're running this on your own sweet/sweetin.
