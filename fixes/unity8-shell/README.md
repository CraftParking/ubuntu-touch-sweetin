# Unity8 shell fixes

A handful of QML changes. No rebuild needed, this stuff is interpreted at runtime, just drop the
files in and restart the shell.

## Restart hidden in the launcher/panel

`IndicatorMenuItemFactory.qml` had `"indicator.reboot": Platform.isPC ? undefined : null` — flat
out hiding Restart on phones no matter what indicator-session itself decided. Changed to
`undefined` so it shows.

## Combined Power screen instead of a direct yes/no

`Dialogs.qml` used to route both shutdown and reboot into one big multi-button "Power" screen.
Now each gets its own plain confirm dialog (needs the paired `indicator-session` fix, see
`fixes/indicator-session/`, otherwise Shutdown still behaves like Restart under the hood).

## Shutdown/restart progress screen

New file, `ActionInProgressScreen.qml`. Shows an icon + spinner + message the moment you confirm,
fires the actual shutdown/reboot call after ~300ms (just long enough for the screen to paint, not
long enough to actually delay anything — an earlier version waited a fixed 13 seconds first, which
just made the whole thing take longer for no reason). Plymouth doesn't work on this hardware at
all in any config I tried, and this device doesn't have a bootanimation binary or a notification
LED, so a screen inside Unity8 itself is about as good as it's going to get here.

## Camera cutout / notch

`Panel.qml`, `PanelMenu.qml`, `sweet.yaml` (in `fixes/deviceinfo/`) — Lomiri has no notch support
whatsoever, and this device never had a `deviceinfo` entry either so it was rendering at desktop
scale. Splits the status bar into a left notification row and a right system-icons row so neither
one ever sits under the camera.

## Launcher covering the moved notification icon

Once the notch fix moved the notification icon to the left, the launcher's side panel (which also
lives on the left edge) started covering it whenever it slid open. `LauncherPanel` in `Launcher.qml`
just never had the same top-margin logic its sibling components (`Drawer`, `BackgroundBlur`)
already had. One line fix, matching the pattern already used elsewhere in the same file.

## Long-press to pin apps

`Drawer.qml` — long-pressing an app icon in the drawer now pops up Open / Pin (or Unpin) / Go to
Store instead of doing both at once like it used to. Uses `LauncherModel.pin()`, which already
existed in the launcher plugin and just wasn't wired up to anything.

## Deploying

```sh
sudo mount -o remount,rw /
sudo cp Dialogs.qml ActionInProgressScreen.qml Drawer.qml Launcher.qml Shell.qml /usr/share/unity8/... # match each file to its real path under /usr/share/unity8/
sudo cp Panel.qml PanelMenu.qml /usr/share/unity8/Panel/
sudo cp IndicatorMenuItemFactory.qml /usr/share/unity8/Panel/Indicators/
sudo chown root:root <all the above>
sudo chmod 644 <all the above>
sudo mount -o remount,ro /
sudo pkill -9 -f 'unity8 --mode=full-greeter'   # respawns and reloads QML automatically
```
