# Battery icon stuck at 0% / flashing

Battery icon flashed green/red and the percentage jumped between 0% and ~95% while charging.
Checked the actual data pipeline while it was happening: `upower -i` on the real battery showed
100%, fully-charged — correct. Raw kernel sysfs (`/sys/class/power_supply/battery/capacity`)
agreed. Full kernel log history of the fuel gauge's own readings from boot never once dropped to
0%. So the hardware/kernel side was never the problem.

`indicator-power`'s own exported state told a different story — `gdbus call --session --dest
com.canonical.indicator.power --object-path /com/canonical/indicator/power --method
org.gtk.Actions.DescribeAll` showed `battery-level: 0`, `device-state: 'empty'`, icon
`battery-empty-symbolic`, completely desynced from the real 100%. Restarting the service didn't
help — a fresh process immediately came up stuck at the same wrong values, ruling out a boot-time
race.

Root cause: this device exposes a Maxim DS28E16 battery-authentication chip as its own separate
`power_supply`-class device (`batt_verify` — used for genuine-vs-counterfeit battery detection,
not a real battery). `upower -i` on it shows exactly the wrong values indicator-power was
displaying: `state: empty`, `percentage: 0%`, icon `battery-empty-symbolic`. Upower's own
`GetDisplayDevice()` method correctly picks the real battery over this decoy — but
`indicator-power` doesn't use that method at all (`device-provider-upower.c` has a comment
explaining why: "its composite rules differ from Design's so (for now) don't use it"). It does
its own device enumeration instead, and gets confused by having two "Battery"-kind devices.

Turns out this exact class of bug already has precedent in this codebase — there's an existing
exclusion for a different decoy device (`batt_therm`, a thermistor sensor) with the comment
"Android: Ignore batt_therm devices since they gives wrong values". Added the same kind of
exclusion for `batt_verify` right next to it in `refresh_device_soon()`.

Tried a udev rule first (overriding `batt_verify`'s reported type to hide it from upower's
classification) — didn't work, since upower reads the `type` file straight from sysfs, not from
udev's property database, so a udev override can't affect it. The actual fix has to be in
indicator-power itself.

Built from `github.com/ubports/indicator-power.git`, branch `xenial`, commit `9966c93` (matches
the installed version `12.10.8+ubports2+0~20210122175117.3~1.gbp9966c9` exactly). CMake build,
tests subdirectory disabled for the build (needs network access for gmock that isn't available,
and isn't needed for just building the service binary).

## Deploying

```sh
sudo mount -o remount,rw /
export DBUS_SESSION_BUS_ADDRESS=unix:abstract=/tmp/dbus-<yours>  # find via: cat /proc/<indicator-power-service pid>/environ | tr '\0' '\n' | grep DBUS
initctl --session stop indicator-power   # can't overwrite a running binary
sudo cp indicator-power-service /usr/lib/aarch64-linux-gnu/indicator-power/indicator-power-service
sudo chmod 755 /usr/lib/aarch64-linux-gnu/indicator-power/indicator-power-service
sudo chown root:root /usr/lib/aarch64-linux-gnu/indicator-power/indicator-power-service
sudo mount -o remount,ro /
initctl --session start indicator-power
```
