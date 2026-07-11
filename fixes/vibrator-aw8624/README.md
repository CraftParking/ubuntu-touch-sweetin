# Vibration motor fix

This phone's AW8624 haptic chip reports Force-Feedback support, so `hfd-service` picks the FF
backend — except the actual FF upload just fails every time on this kernel
(`Failed to upload rumble effect`), so nothing vibrates. The chip works fine, just not through FF:
Android's own vibrator HAL talks to it directly via sysfs, so that's what this backend does too.

Gotcha: the driver defaults to `activate_mode=0`, which plays a fixed built-in effect and ignores
whatever duration you send — looks like it works (motor buzzes) but the length's always wrong.
Needs `activate_mode=1` set first.

**Second bug**, only shows up once the above is fixed: still nothing vibrated, because the D-Bus
interface `hfd-service` checks to see if vibration's even allowed
(`com.lomiri.hfd.AccountsService.Settings`) was never installed on this image — fails closed.
`com.lomiri.hfd.AccountsService.Settings.xml` here is the missing interface file.

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
# symlink target has to be exactly this relative path or accounts-daemon ignores it silently

sudo mount -o remount,ro /
sudo pkill -9 -f accounts-daemon
sudo initctl start hfd-service
```

`vibrator-aw8624.h`/`.cpp` is the backend source, drops into `hfd-service`'s `src/` next to the
existing `vibrator-*.cpp` files if you'd rather rebuild than use the binary here.
