# indicator-session fixes

Two changes to the service behind the top-right "System" dropdown.

**Restart hidden, Report a bug / UBports Help not removable** — Restart unhidden, the other two
removed from `service.c`'s `create_admin_section()`.

**Shutdown and Restart triggered the same dialog** — `my_power_off()` in
`backend-dbus-actions.c` was requesting `END_SESSION_TYPE_REBOOT` even for a plain shutdown, so
Unity8 couldn't tell them apart. Now requests `END_SESSION_TYPE_SHUTDOWN` properly (needs the
matching `Dialogs.qml` change in `fixes/unity8-shell/`).

Built from `github.com/ubports/indicator-session.git`, branch `xenial`, matching version
`20.3.0+ubports+0~20220124104820.34~1.gbpdc5827` exactly — not the newer `ayatana-indicator-session`
rewrite on GitLab, that's a different codebase.

## Deploying

```sh
sudo mount -o remount,rw /
sudo initctl stop indicator-session
sudo cp indicator-session-service /usr/lib/aarch64-linux-gnu/indicator-session/indicator-session-service
sudo chmod 755 /usr/lib/aarch64-linux-gnu/indicator-session/indicator-session-service
sudo chown root:root /usr/lib/aarch64-linux-gnu/indicator-session/indicator-session-service
sudo mount -o remount,ro /
sudo initctl start indicator-session
```

Pair with the `Dialogs.qml`/`IndicatorMenuItemFactory.qml` changes in `fixes/unity8-shell/` —
this half alone just makes Shutdown behave like Restart.
