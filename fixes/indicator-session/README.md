# indicator-session fixes

Two changes to the `indicator-session` service (this is what draws the top-right "System"
dropdown menu).

## Restart was hidden, Report a bug / UBports Help weren't

Restart is unhidden now, and Report a bug / UBports Help are removed from `service.c`'s
`create_admin_section()` — they were unconditionally added with no way to turn them off.

## Shutdown and Restart used to trigger the same dialog

`backend-dbus/actions.c`'s `my_power_off()` was requesting `END_SESSION_TYPE_REBOOT` even for a
plain shutdown (a workaround comment in the original code explains why, something about avoiding
extra lock/logout options). Side effect: Unity8 couldn't actually tell Shutdown and Restart apart,
so both landed on the same combined multi-button screen. Changed it to request
`END_SESSION_TYPE_SHUTDOWN` properly — needs the matching `Dialogs.qml` change in
`fixes/unity8-shell/` to actually show a separate dialog.

## Source

Built from `github.com/ubports/indicator-session.git`, branch `xenial`, the commit matching this
version string exactly: `20.3.0+ubports+0~20220124104820.34~1.gbpdc5827`. Don't grab source from
the newer `ayatana-indicator-session` project on GitLab — different rewrite, doesn't match what's
actually installed here.

## Deploying

```sh
sudo mount -o remount,rw /
sudo initctl stop indicator-session   # can't overwrite a running binary
sudo cp indicator-session-service /usr/lib/aarch64-linux-gnu/indicator-session/indicator-session-service
sudo chmod 755 /usr/lib/aarch64-linux-gnu/indicator-session/indicator-session-service
sudo chown root:root /usr/lib/aarch64-linux-gnu/indicator-session/indicator-session-service
sudo mount -o remount,ro /
sudo initctl start indicator-session
```

Deploy this together with the `Dialogs.qml`/`IndicatorMenuItemFactory.qml` fixes in
`fixes/unity8-shell/` — this half alone would make Shutdown behave like Restart.
