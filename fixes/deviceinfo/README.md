# Missing deviceinfo entry

No `deviceinfo` config existed for this device under `/etc/deviceinfo/devices/`, so it fell back
to the desktop default (`GridUnit: 8`) instead of the phone baseline (`GridUnit: 21`) — everything
rendered at roughly a third size, which is part of why the status bar looked so broken against the
camera cutout.

`GridUnit: 21` matches the Poco X3 NFC and Redmi Note 9 Pro — same panel/PPI, no override needed.

## Deploying

```sh
sudo mount -o remount,rw /
sudo mkdir -p /etc/deviceinfo/devices
sudo cp sweet.yaml /etc/deviceinfo/devices/sweet.yaml
sudo mount -o remount,ro /
```

Reboot to take effect. Only fixes scaling — pair with `fixes/unity8-shell/` for the actual
camera-cutout positioning.
