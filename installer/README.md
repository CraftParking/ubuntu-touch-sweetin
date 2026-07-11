# Installer

Two ways to flash this. `single-zip/` is the one to use — one zip, one `twrp install`.
`two-zip/` is the older two-step version, kept around as a fallback.

## single-zip/

Flash order: MIUI firmware (fastboot, prerequisite) → this zip. That's it.

`update-binary` here does the whole thing itself instead of going through TWRP's own CLI:
LineageOS's 5 dynamic partitions get `dd`'d straight onto the device-mapper nodes TWRP
auto-creates at boot (no need to rebuild a `super.img`), then `format data`, then it falls
through into `ubports.sh` for the actual Ubuntu Touch side. Why not just call `twrp install`/
`twrp format data` from inside the script like you'd expect? Tried that first — a nested `twrp`
call from inside an already-running update-binary doesn't block properly on this device, so the
outer script races ahead while the real work's still happening. Bypassing the TWRP CLI entirely
turned out to be the actual fix, not a workaround.

Two device-specific bugs had to be worked around to make this work at all, both bundled as fixes
here:

- **No `mkfs.f2fs` binary exists anywhere on this TWRP build** (its own `format data` is linked
  into TWRP's binary directly, not a callable subprocess) — so `mkfs.f2fs.static` here is a
  statically-linked one, built from source, bundled in.
- **This TWRP's `unzip` can't read past the 2GB mark in a zip file** (a straddling entry just
  fails with a plain "I/O error") — worked around by bootstrapping the zip's own bundled busybox
  first and using its `unzip` applet for everything after that.

`build-single-zip.sh` builds the actual zip from a LineageOS OTA zip + a UBports zip (neither
bundled here — multi-GB binaries, wrong thing for a git repo).

## two-zip/

The original flow: flash LineageOS 18.1 → format data → flash this zip. `update-binary` here is
the original 2022 installer with one thing removed — it used to flash a bundled firmware zip
partway through via a nested `twrp install` call, which had the exact same non-blocking problem
described above. Wasn't needed anyway (firmware's a separate fastboot step before any of this),
so it's just gone now.
