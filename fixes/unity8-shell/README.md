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
under the camera.

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
