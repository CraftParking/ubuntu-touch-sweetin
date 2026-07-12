# Software Update panel

An in-Settings "check for updates" panel, since there's no real UBports system-image OTA
infrastructure behind this ROM (no signing keys, no channel on an image server) - this is a
lightweight, custom equivalent instead. Shows up under Settings → System → **Software Update**.

## How it works

- `/etc/craftparking-version` on the device holds the installed build's version string (e.g.
  `v0.0.1`).
- The panel's C++ backend (`update.cpp`/`update.h`, built as `libCraftparkingUpdatePanel.so`, QML
  module `Craftparking.SystemSettings.Update`) fetches a small `latest.json` manifest straight from
  `raw.githubusercontent.com/CraftParking/ubuntu-touch-sweetin/master/latest.json` and compares its
  `version` field against the installed one. This is the *only* check that goes through GitHub -
  the checker has no awareness of SourceForge's folder listing at all, it just trusts whatever
  `latest.json` currently says. Publishing a new version means manually updating that file.
- The actual flashable zip is **not** hosted as a GitHub Release asset - GitHub caps a single
  release asset at 2GB, easy to blow past as this ROM grows, so the zip lives on SourceForge
  instead (`sourceforge.net/projects/ubuntu-touch-sweetin`, uploaded via SFTP/rsync since
  SourceForge's own browser uploader caps out at 500MB). `latest.json` just points at it
  (`zip_url`, plus `sha256` and `size` for verification/progress). SourceForge puts large uploads
  through a staging/replication step before the direct `/download` link resolves - if it 404s right
  after uploading, that's normal, not a broken upload; it clears on its own.
- **Downloading does not happen inside this QML plugin** - see
  [`fixes/system-image-dbus/`](../system-image-dbus/) for why and how. The panel just starts the
  download over D-Bus and displays whatever progress signals arrive; the download itself runs
  inside a separate root service that survives navigating away from this page, switching apps, or
  closing Settings entirely.
- sha256 is verified incrementally as bytes arrive (not loaded into memory all at once) before
  anything is considered "ready to install."
- Installing calls `CraftparkingApplyUpdate()` (no arguments - see below) - never auto-triggered,
  only from an explicit confirm dialog in the panel.

## The privileged half: system-image-dbus

The panel itself runs as the unprivileged `phablet` user (system-settings is unconfined by
AppArmor, but that's not root) - actually downloading, moving the zip into place, and rebooting to
recovery all need root, and the download specifically needs to survive this page's own QObject
being destroyed on back-navigation (confirmed happens) and this whole process's networking getting
throttled when backgrounded (also confirmed). Full details, including a notification feature that
was attempted and abandoned, are in [`fixes/system-image-dbus/README.md`](../system-image-dbus/README.md).

Short version: reuses `com.canonical.SystemImage`, the same D-Bus service the **factory reset**
panel already calls (`FactoryReset`/`ProductionReset`) - bus-activated as root, already callable by
any session - rather than inventing a new privilege-escalation path.

## The settings-panel category gotcha

Manifest originally set `"category": "uncategorized-bottom"` (matching the "about" panel) with a
custom `EntryComponent.qml` copied from it. Moved to `"category": "system"` per the user's request
to live in the System section - but that category renders as a **grid of icon+label tiles**, not
the flat list "uncategorized-bottom" uses, and a custom `EntryComponent.qml` written for the list
style breaks there (icon renders but squished, no visible label, not tappable). Confirmed by
checking `battery.settings` (also `"category": "system"`): it has **no** `entry-component` field at
all - grid-category panels are rendered generically by system-settings itself from just the
manifest's `icon`+`name` fields. Removed our `EntryComponent.qml` and the manifest reference to it
entirely; the tile now renders and behaves identically to every other System-section entry.

## QML plugin cache gotcha

After deploying an updated `libCraftparkingUpdatePanel.so` with a new QML-visible signal, the page
failed to open with `Cannot assign to non-existent property "onDownloadStatus"` even though the
`.so` on disk was confirmed correct (byte-identical to the freshly built one). Cause: Qt's QML
engine caches compiled bytecode/type info per-app under
`~/.cache/{system-settings,ubuntu-system-settings}/qmlcache/` - stale entries there don't always
get invalidated just because the plugin `.so` changed underneath. Clearing those two directories
and restarting `system-settings` picked up the new signal correctly.

## Deploying

The panel files (QML + `.so` + `.settings`) go under the standard system-settings locations:
```
/usr/share/ubuntu/settings/system/craftparking-update.settings
/usr/share/ubuntu/settings/system/qml-plugins/craftparking-update/PageComponent.qml
/usr/lib/aarch64-linux-gnu/ubuntu-system-settings/private/Craftparking/SystemSettings/Update/{qmldir,libCraftparkingUpdatePanel.so}
```
(root:root, 644 for files, 755 for directories - matches the existing `about`/`battery` panels.)
After updating the `.so` or QML, clear `~/.cache/{system-settings,ubuntu-system-settings}/qmlcache/`
before restarting `system-settings`, or the cache gotcha above will bite again.

Built with CMake in the same Xenial arm64 chroot used for `mkfs.f2fs.static` and
`indicator-power` - `find_package(Qt5 REQUIRED COMPONENTS Qml Quick Network DBus)`, no
autotools/full-source-tree build needed for a small standalone plugin like this.

**Reliability note on file transfers to/from this device during development**: base64-encoding a
file over a plain `exec_command` SSH channel occasionally hangs indefinitely (confirmed: the
remote `base64` process itself sits alive but stalled for 5-10+ minutes on a plain 10MB file, no
error, no progress) - switching to real SFTP `get`/`put` was reliably fast every time in
comparison. Prefer SFTP for any file transfer to/from this device going forward.
