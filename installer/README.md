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

One non-device-specific bug worth calling out too: `show_progress <fraction> <seconds>` ADDS
`<fraction>` of the bar's full width to wherever it already sits, it doesn't set an absolute
position. Every call in an earlier version passed `1.0` (meaning "100% of the whole bar") by
mistake, so the second call already overshot a full bar and the progress UI snapped to 100%
within the first few seconds while the real install kept running for another 10+ minutes. Fixed
by giving each phase a real fraction (sized off actual observed timings on this device, ~650s for
a full install) so they sum to ~1.0 across the script, and the `dd` loop further splits its own
slice proportionally by each partition's real byte size via `set_progress`, so the bar moves
through system/vendor/product/odm/system_ext at roughly the right relative pace instead of
jumping the same amount regardless of size.

`build-single-zip.sh` builds the actual zip from a LineageOS OTA zip + a UBports zip (neither
bundled here — multi-GB binaries, wrong thing for a git repo).

## two-zip/

The original flow: flash LineageOS 18.1 → format data → flash this zip. `update-binary` here is
the original 2022 installer with one thing removed — it used to flash a bundled firmware zip
partway through via a nested `twrp install` call, which had the exact same non-blocking problem
described above. Wasn't needed anyway (firmware's a separate fastboot step before any of this),
so it's just gone now.
