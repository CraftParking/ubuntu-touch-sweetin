# system-image-dbus patch: background-safe update download

Part of [`fixes/system-update-panel/`](../system-update-panel/) - the Settings panel itself only
starts/watches the download; the actual downloading happens here instead, for one concrete reason:
the Settings page's own QObject gets destroyed on back-navigation, and the whole `system-settings`
process gets its networking throttled when backgrounded - either kills an in-process download.
`system-image-dbus` is root, bus-activated, and already proven to survive regardless of what's
open (that's the whole point of it being a system service), so the download lives here instead.

## What's added

- `craftparking_download.py`: the actual download - a background thread, sha256 verified
  incrementally as bytes arrive (not loaded into memory all at once), writes to
  `/home/phablet/.cache/craftparking-update/update.zip`.
- `apply.py`: `craftparking_apply_update()` - moves that file into
  `/android/data/media/0/craftparking-update/update.zip` (the one place TWRP actually looks for
  install media as `/data/media/0/...`; `/android/` is purely a Halium boot-time bind-mount prefix,
  confirmed via matching `st_dev` that `/home` and `/android/data` are the same partition, so this
  is an instant `os.rename()`, not a multi-GB copy), writes TWRP's own OpenRecoveryScript format to
  `/cache/recovery/openrecoveryscript` (not `ubuntu_command` - that's system-image's own format,
  which this TWRP doesn't understand), then reboots via the same
  `config.hooks.apply().apply()` → `/sbin/reboot -f recovery` path `factory_reset()` already uses.
  Takes no arguments at all - only ever applies whatever `craftparking_download` actually
  downloaded and verified, not an arbitrary caller-supplied path.
- `api.py`: thin `Mediator` pass-throughs, same pattern as the existing `factory_reset()`/
  `production_reset()` wrappers.
- `dbus.py`: new D-Bus methods/signals on the existing `/Service` object -
  `CraftparkingStartDownload(url, sha256, size)`, `CraftparkingCancelDownload()`,
  `CraftparkingDownloadStatus()` (lets a reopened Settings page resync with a download that's
  still running from a previous visit), `CraftparkingApplyUpdate()`, plus
  `CraftparkingDownloadProgress`/`CraftparkingDownloadFinished` signals.

## Why this D-Bus service specifically

Rather than inventing a new privileged mechanism, this reuses `com.canonical.SystemImage` - the
same D-Bus service the **factory reset** panel already calls (`FactoryReset`/`ProductionReset`),
already bus-activated as root, already callable by any session. See
[`fixes/system-update-panel/README.md`](../system-update-panel/README.md) for the full reasoning.

## Tried and abandoned: a live progress notification

Wanted a system notification with a progress bar while the download runs. Got most of the way
there, then hit a wall worth documenting so it isn't re-attempted blind next time:

- `org.freedesktop.Notifications` lives on the phablet user's **session** bus, not the system bus
  this service normally talks on. Confirmed via `/proc/<pid>/environ` scanning that the live
  session bus address is discoverable (`unix:abstract=/tmp/dbus-<hash>`, changes across
  boots/relogins - some phablet-owned processes carry stale addresses from old sessions, so
  candidates need to be tried in turn, not just the first match).
- A **root**-owned process's D-Bus connection to that session bus times out on its own `Hello()`
  handshake (`org.freedesktop.DBus.Error.NoReply`) no matter how correct the address is - this is
  the session bus's own security boundary rejecting a non-owning UID, not a bug to patch around.
- Fixed that specific problem by spawning a child process with `preexec_fn` dropping real+effective
  UID/GID to phablet's *before* it connects - since it's now a genuine phablet-owned process, the
  session bus accepts it exactly like any other app. (Gotcha hit along the way: the helper script
  must NOT live inside the `systemimage/` package directory - Python prepends a script's own
  directory to `sys.path`, so a helper there shadows the real `dbus` package and stdlib `logging`
  with this package's own same-named `dbus.py`/`logging.py` modules. Moved it to plain
  `/usr/lib/python3/dist-packages/craftparking_notify_helper.py` instead.)
- Also had to throttle notification updates to once per percent-point, not once per 256KB chunk -
  spawning a subprocess and waiting on it for every single chunk stalled this service's whole
  GLib main loop, which froze Settings on open (any other D-Bus call to this service blocks
  while it's busy running a notify subprocess).
- After all of that: the D-Bus call succeeds and returns a valid notification id (confirmed
  `unity8` itself, not a separate daemon, owns `org.freedesktop.Notifications` here) - but no
  visible banner ever appeared. The one *confirmed-working* system notification found on this
  device (`ciborium`'s "SD card cannot be read") turns out not to use this API at all - it goes
  through `ubuntu-push-client`'s own "legacy helper" push-message protocol instead, a materially
  bigger thing to replicate. Given the actual goal (download surviving backgrounding/navigation)
  already works and this was a nice-to-have, stopped here rather than reverse-engineer unity8's
  private notification-filtering C++ or the push-client protocol. **Removed** the notify/helper
  files entirely rather than leave unused dead code in place - if revisited, start from the
  `ubuntu-push-client` legacy-helper angle, not another `org.freedesktop.Notifications` attempt.

## Deploying

Same pattern as the earlier system-image-dbus patches: `mount -o remount,rw /`, copy into
`/usr/lib/python3/dist-packages/systemimage/`, `chown root:root`/`chmod 644`, remount `ro`, then
`pkill -f /usr/sbin/system-image-dbus` (bus-activated, respawns on the next D-Bus call).
