# Wireless display toggle was hidden

Settings > Brightness & Display should show a "Wireless display" row, but it's gated behind an
Android property, `ubuntu.widi.supported`, that never got set — `aethercast` itself was already
running the whole time.

There's a commented-out line in `/etc/init/mount-android.conf` that sets this exact property.
Uncommenting it directly causes a boot hang: it runs before the Android container's property
service exists yet. `enable-widi.conf` here is a separate upstart job on the `android` event
instead, which only fires once that service is confirmed up.

## Deploying

```sh
sudo mount -o remount,rw /
sudo cp enable-widi.conf /etc/init/enable-widi.conf
sudo chown root:root /etc/init/enable-widi.conf
sudo chmod 644 /etc/init/enable-widi.conf
sudo mount -o remount,ro /
```

Takes effect next boot. To see it live: `sudo setprop ubuntu.widi.supported 1`, restart Settings.

Note: only makes the toggle appear and turns on the Aethercast backend — actual casting to a real
receiver hasn't been tested.
