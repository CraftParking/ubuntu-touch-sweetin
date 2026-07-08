# Vibration motor fix

This phone uses an Awinic AW8624 haptic driver. `hfd-service` (Ubuntu Touch's haptic daemon)
picks a vibrator backend in priority order, and this chip reports Force-Feedback support so the FF
backend gets picked — except the actual FF upload on this kernel just fails every time
(`Failed to upload rumble effect`), so nothing ever vibrates.

The chip actually works fine, just not through the generic FF path — Android's own vibrator HAL
talks to it directly through sysfs (`/sys/bus/i2c/devices/<addr>/activate` etc), completely
bypassing FF. So that's what the new backend here does too.

One thing that got me for a while: the driver defaults to `activate_mode=0`, which plays a fixed
built-in effect and ignores whatever duration you actually send it — so a naive fix looks like it
works (motor buzzes) but the length is always wrong. Needs `activate_mode=1` set first.

## Second bug, only shows up after deploying the above

Even with the backend working, nothing vibrated, because the D-Bus interface `hfd-service` checks
to see if vibration is even allowed (`com.lomiri.hfd.AccountsService.Settings`) was never installed
on this image at all. It fails closed, so haptics were disabled at the settings layer regardless of
whether the backend worked. `com.lomiri.hfd.AccountsService.Settings.xml` here is that missing
interface file.

## Deploying

```sh
sudo mount -o remount,rw /
sudo initctl stop hfd-service
sudo cp hfd-service /usr/bin/hfd-service
sudo chmod 755 /usr/bin/hfd-service
sudo chown root:root /usr/bin/hfd-service

sudo mkdir -p /usr/share/dbus-1/interfaces /usr/share/accountsservice/interfaces
sudo cp com.lomiri.hfd.AccountsService.Settings.xml /usr/share/dbus-1/interfaces/
sudo ln -sf ../../dbus-1/interfaces/com.lomiri.hfd.AccountsService.Settings.xml \
    /usr/share/accountsservice/interfaces/com.lomiri.hfd.AccountsService.Settings.xml
# symlink target has to be exactly this relative path or accounts-daemon silently ignores it

sudo mount -o remount,ro /
sudo pkill -9 -f accounts-daemon
sudo initctl start hfd-service
```

Source for the backend itself is `vibrator-aw8624.h`/`.cpp`, meant to drop into `hfd-service`'s
`src/` next to the existing `vibrator-*.cpp` files if you want to rebuild from scratch instead of
using the binary here.
