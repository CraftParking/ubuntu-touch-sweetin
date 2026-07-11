# Software Update panel

An in-Settings "check for updates" panel, since there's no real UBports system-image OTA
infrastructure behind this ROM (no signing keys, no channel on an image server) - this is a
lightweight, custom equivalent instead.

## How it works

- `/etc/craftparking-version` on the device holds the installed build's version string (e.g.
  `v0.0.1`).
- The panel's C++ backend (`update.cpp`/`update.h`, built as `libCraftparkingUpdatePanel.so`, QML
  module `Craftparking.SystemSettings.Update`) fetches a small `latest.json` manifest straight from
  `raw.githubusercontent.com/CraftParking/ubuntu-touch-sweetin/master/latest.json` and compares its
  `version` field against the installed one.
- The actual flashable zip is **not** hosted as a GitHub Release asset - GitHub caps a single
  release asset at 2GB, easy to blow past as this ROM grows, so the zip lives on SourceForge
  instead (`sourceforge.net/projects/ubuntu-touch-sweetin`). `latest.json` just points at it
  (`zip_url`, plus `sha256` and `size` for verification/progress).
- Downloads stream straight to disk with the sha256 computed incrementally alongside (not loaded
  into memory all at once), verified against `latest.json`'s hash before anything is considered
  "ready to install."
- Installing calls a new `CraftparkingApplyUpdate(path)` D-Bus method added to `system-image-dbus`
  (see below) - never auto-triggered, only from an explicit confirm dialog in the panel.

## The privileged half: patching system-image-dbus

The panel itself runs as the unprivileged `phablet` user (system-settings is unconfined by
AppArmor, but that's not root) - actually moving the downloaded zip into place and rebooting to
recovery needs root. Rather than inventing a new privilege-escalation path (a sudoers rule, a new
D-Bus service, etc.), this reuses the exact mechanism the **factory reset** panel already uses:
`com.canonical.SystemImage`, a D-Bus system service that's bus-activated as root and already
callable by any session (its `FactoryReset`/`ProductionReset` methods work the same way).

Added `craftparking_apply_update(src_path)` to `systemimage/apply.py` (Python, part of the
`system-image-dbus` package - patched in place on the device, not rebuilt from source), following
the exact same pattern as the existing `factory_reset()`/`production_reset()` functions:

- Validates `src_path` is a `.zip` under `/home/phablet/` (where the unprivileged download landed).
- Relocates it to `/android/data/media/0/craftparking-update/update.zip` - the one real,
  root-only-writable location TWRP actually recognizes as "Internal Storage"
  (`/data/media/0/...` from TWRP's own perspective; the `/android/` prefix is purely a Halium
  boot-time bind-mount artifact, confirmed matching `st_dev` with `/home` - so this is a
  same-filesystem `os.rename()`, not a multi-GB copy, with a `shutil.copy2` fallback just in case).
- Writes `install /data/media/0/craftparking-update/update.zip` to
  `/cache/recovery/openrecoveryscript` - TWRP's own OpenRecoveryScript format (the same mechanism
  third-party tools like Flashify use), **not** `ubuntu_command` (system-image's own format, which
  this TWRP doesn't understand at all).
- Calls the exact same `config.hooks.apply().apply()` → `/sbin/reboot -f recovery` that
  `factory_reset()` already uses.

Exposed as `CraftparkingApplyUpdate` on the existing `/Service` object (`dbus.py`), routed through
`Mediator.craftparking_apply_update()` (`api.py`) - same three-layer structure
(dbus.py → api.py → apply.py) the built-in reset methods already use.

## Deploying

The panel files (QML + `.so` + `.settings`) go under the standard system-settings locations:
```
/usr/share/ubuntu/settings/system/craftparking-update.settings
/usr/share/ubuntu/settings/system/qml-plugins/craftparking-update/{EntryComponent,PageComponent}.qml
/usr/lib/aarch64-linux-gnu/ubuntu-system-settings/private/Craftparking/SystemSettings/Update/{qmldir,libCraftparkingUpdatePanel.so}
```
(root:root, 644 for files, 755 for directories - matches the existing `about`/`reset` panels.)

The `system-image-dbus` patch (`apply.py`/`api.py`/`dbus.py`) replaces the installed copies at
`/usr/lib/python3/dist-packages/systemimage/`, then the running service needs killing so it
respawns with the new code (`pkill -f /usr/sbin/system-image-dbus` - it's bus-activated, so it
comes back on the next D-Bus call automatically).

Built with CMake in the same Xenial arm64 chroot used for `mkfs.f2fs.static` and
`indicator-power` - `find_package(Qt5 REQUIRED COMPONENTS Qml Quick Network DBus)`, no
autotools/full-source-tree build needed for a small standalone plugin like this.
