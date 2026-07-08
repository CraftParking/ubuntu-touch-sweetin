# Ubuntu Touch for Redmi Note 10 Pro (sweet/sweetin)

This is a set of bug fixes on top of the existing Ubuntu Touch / Halium port for the Xiaomi Redmi
Note 10 Pro (codename `sweet`, India variant `sweetin`, Snapdragon 732G).

I didn't make the original port. That was done back in 2022 by **dopaemon**, with the flashable
zip put together by **Erfan** and **Nobi Nobita** (their install script is based on osm0sis's
anykernel2 script). All of that is their work, not mine. What's here is a bunch of fixes I made on
top of it after running into the same known bugs everyone else running this port hits.

## What's actually fixed

The original 2022 build works, but has some annoying bugs. Here's what's different now:

- **Vibration motor** — didn't work at all before. Turns out the AW8624 haptic chip on this phone
  reports Force-Feedback support but the actual FF upload just silently fails on this kernel. Added
  a proper backend that talks to the chip directly instead.
- **Status bar covering the punch-hole camera** — this device never had a `deviceinfo` entry, so it
  fell back to desktop-sized UI scaling, and on top of that Lomiri has zero notch support to begin
  with. Added a real device profile and moved the status bar icons around the camera.
- **Wireless display toggle hidden in Settings** — the flag that turns it on was just never set.
  It's there now, under Settings > Brightness & Display.
- **Restart missing from the power menu**, and **Report a bug / UBports Help cluttering it up** —
  Restart is unhidden, the other two are gone.
- **Shutdown/Restart confirmation** — used to dump you into a confusing combined "Power" screen
  with extra options you didn't ask for. Now it's just a plain yes/no for whichever one you tapped.
- **Black screen during shutdown looks like a crash** — added a small progress screen so you know
  it's actually doing something and don't panic and hold the power button mid-shutdown.
- **Long-press to pin apps** — you can long press an app in the app drawer now to pin/unpin it to
  the launcher or jump to its OpenStore page.
- Also quietly holding back ~175 packages that are known to break boot if apt ever updates them on
  this image (mostly `unity8`/`ubuntu-touch`/`bluez` related stuff — updating these has bricked this
  exact install multiple times during testing).

None of this touches the kernel or the base rootfs build process, it's all userspace fixes on top
of the exact same 2022 image.

## Installing

You'll need to already be at a point where you can flash a Halium image on this device — that part
hasn't changed from the original guide. Rough order:

1. Flash the matching MIUI firmware via fastboot (this is a prerequisite, not part of any zip here)
2. Flash LineageOS 18.1 (this is the Android 11 base Halium runs on top of, you never actually boot
   into it)
3. Format data
4. Flash the Ubuntu Touch zip

Steps 2-4 use the same TWRP `install`/`format data` flow as any Halium port. The zip in step 4 is
built from the files in this repo — see [`installer/`](installer/) for the actual install script.
I haven't gotten around to packaging steps 2-4 into one zip yet (tried it, hit a real TWRP bug
where a nested `twrp install` call doesn't block properly — long story, see the commit history if
you're curious), so for now it's two flashes instead of one.

**Known bug from before that's still unsolved:** the phone froze once after a fresh boot — screen
dimmed to black and stopped responding to touch and the power button. Only happened once, hasn't
come back since, and I never figured out what caused it. If it happens to you too, let me know.

## What's in this repo

- [`fixes/`](fixes/) — every individual fix, with the actual patched source/config and a short
  writeup of what was wrong and why
- [`installer/`](installer/) — the (patched) flashable-zip install script

## Credits

- **dopaemon** — original Halium port for this device
- **Erfan** and **Nobi Nobita** — put together the original flashable zip installer
- **osm0sis** — the anykernel2 script the installer is based on
- me (Craftparking) — the fixes in this repo

If you're from the sweetin Telegram group and this breaks something for you, open an issue, I'll
try to help.
