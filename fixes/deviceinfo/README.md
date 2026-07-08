# Missing deviceinfo entry

This device never had a `deviceinfo` config under `/etc/deviceinfo/devices/`, so it fell back to
the generic desktop default (`GridUnit: 8`, `DeviceType: desktop`) instead of the phone baseline
(`GridUnit: 21`). Every UI element rendered at roughly a third of its intended size, which is part
of why the status bar looked so broken against the camera cutout — a tiny bar next to a
fixed-size physical hole was never going to look right.

`GridUnit: 21` here matches the Poco X3 NFC (`surya`) and Redmi Note 9 Pro (`miatoll`) — same PPI,
same panel size, both already use 21 with no per-device override needed.

## Deploying

```sh
sudo mount -o remount,rw /
sudo mkdir -p /etc/deviceinfo/devices
sudo cp sweet.yaml /etc/deviceinfo/devices/sweet.yaml
sudo mount -o remount,ro /
```

Needs a reboot (or at least a shell restart) to take effect. On its own this only fixes the
scaling — see `fixes/unity8-shell/` for the actual camera-cutout positioning fix, both are needed
together.
