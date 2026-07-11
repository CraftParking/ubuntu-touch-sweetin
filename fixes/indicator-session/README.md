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

**Restart still didn't show up even with both fixes above deployed** — found this one after the
single-zip install went out. Binary and QML both correct, action registered and enabled over
D-Bus, polkit authorized reboot — and it *still* wasn't in the menu. Turns out `my_can_reboot()`
in `backend-dbus-actions.c` has its own separate gate: if it sees a D-Bus name owner for the old
`com.canonical.Unity.Session.EndSessionDialog` interface, it assumes Unity's about to show its
own combined shutdown/reboot prompt and hides Restart as redundant — a legacy check that doesn't
know the `Dialogs.qml` fix above already splits that combined prompt in two.
`force-restart-menuitem` is indicator-session's own built-in override for exactly this mismatch,
just was never set to `true`. `craftparking-force-restart-menuitem.conf` is a one-shot upstart
session job that sets it every session start (a fresh phablet user has no dconf overrides yet, so
this has to run somewhere, not just be set once by hand).

## Deploying

```sh
sudo mount -o remount,rw /
sudo initctl stop indicator-session
sudo cp indicator-session-service /usr/lib/aarch64-linux-gnu/indicator-session/indicator-session-service
sudo chmod 755 /usr/lib/aarch64-linux-gnu/indicator-session/indicator-session-service
sudo chown root:root /usr/lib/aarch64-linux-gnu/indicator-session/indicator-session-service
sudo mount -o remount,ro /
sudo initctl start indicator-session
sudo cp craftparking-force-restart-menuitem.conf /usr/share/upstart/sessions/craftparking-force-restart-menuitem.conf
```

Pair with the `Dialogs.qml`/`IndicatorMenuItemFactory.qml` changes in `fixes/unity8-shell/` —
this half alone just makes Shutdown behave like Restart.
