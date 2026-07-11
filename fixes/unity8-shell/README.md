# Unity8 shell fixes

QML changes, no rebuild needed — drop in and restart the shell.

**Restart hidden** — `IndicatorMenuItemFactory.qml` had `"indicator.reboot":
Platform.isPC ? undefined : null`, hiding it on phones outright regardless of what
indicator-session decided. Changed to `undefined`.

**Combined Power screen instead of a direct yes/no** — `Dialogs.qml` used to route shutdown and
reboot into one multi-button screen. Now each gets a plain confirm dialog (pair with the
`indicator-session` fix, otherwise Shutdown still behaves like Restart underneath).

**Shutdown/restart progress screen** — new `ActionInProgressScreen.qml`, shows an icon + spinner
the moment you confirm. Plymouth doesn't work on this hardware in any config, there's no
bootanimation binary or notification LED here either, so this is about as good as feedback gets.

**Camera cutout / notch** — `Panel.qml`, `PanelMenu.qml` + `sweet.yaml` (in `fixes/deviceinfo/`).
Lomiri has no notch support at all, splits the status bar into left/right rows so neither sits
under the camera. Portrait-only by design — the physical camera is only horizontally centered
when the phone's held upright, so this split needs to disable itself in landscape (see next).

**Same fix overlapping the app name in landscape** — the split makes sense in portrait but the
physical camera obviously isn't centered anymore once rotated, so in landscape it just misplaced
the notification icon on top of the app title. Gating this on `Screen.height > Screen.width`
seemed obvious but doesn't work on this device: confirmed via a live debug label that
`Screen.width`/`Screen.height` stay fixed at `1080x2400` (physical panel's native portrait
resolution) even with a rotated app in the foreground — this shell's own coordinate space never
rotates, only the focused app's content does. The actual signal that tracks the focused app's
real rotation is `Shell.qml`'s existing `mainAppWindowOrientationAngle` — wired a new
`orientationAngle` property through from `Shell.qml`'s `Panel {}` instantiation into `Panel.qml`,
and gated the whole split (`hideCameraOverlap`, `notificationRow`, `hideMessagesIndicator`) on
`orientationAngle === 0 || orientationAngle === 180` instead. Landscape now correctly falls back
to the original all-icons-on-the-right layout.

**Launcher covering the notch fix's icon** — `LauncherPanel` in `Launcher.qml` was missing the
same top-margin logic its siblings (`Drawer`, `BackgroundBlur`) already had.

**Long-press to pin apps** — `Drawer.qml`, long-press now offers Open / Pin / Store instead of
just opening. Uses `LauncherModel.pin()`, already existed, just wasn't wired up.

## Deploying

```sh
sudo mount -o remount,rw /
sudo cp Dialogs.qml ActionInProgressScreen.qml Drawer.qml Launcher.qml Shell.qml /usr/share/unity8/... # match each to its real path
sudo cp Panel.qml PanelMenu.qml /usr/share/unity8/Panel/
sudo cp IndicatorMenuItemFactory.qml /usr/share/unity8/Panel/Indicators/
sudo chown root:root <all the above> && sudo chmod 644 <all the above>
sudo mount -o remount,ro /
sudo pkill -9 -f 'unity8 --mode=full-greeter'   # respawns, reloads QML automatically
```
