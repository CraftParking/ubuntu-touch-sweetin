# Wireless display toggle was hidden

Settings > Brightness & Display should have a "Wireless display" row for Aethercast/Miracast, but
it's gated behind an Android property, `ubuntu.widi.supported`, that just never got set. The
`aethercast` service itself was already installed and running the whole time.

There's a commented-out line in `/etc/init/mount-android.conf` that sets this exact property —
looks like whoever built the original image tried it and it broke something, so they just
commented it out and left it disabled. Uncommenting it directly caused a boot hang for me too: it
runs before the Android container's property service even exists yet, so the call just hangs
forever and takes the whole boot down with it.

The fix is `enable-widi.conf`, a separate upstart job that runs on the `android` event instead —
that event only fires once the property service is confirmed up (something else already waits on
this exact condition before emitting it), so the property gets set safely, after boot has already
gotten past the risky part.

## Deploying

```sh
sudo mount -o remount,rw /
sudo cp enable-widi.conf /etc/init/enable-widi.conf
sudo chown root:root /etc/init/enable-widi.conf
sudo chmod 644 /etc/init/enable-widi.conf
sudo mount -o remount,ro /
```

Takes effect on next boot. To see it without rebooting: `sudo setprop ubuntu.widi.supported 1`
then kill and restart the Settings app.

Note: this only makes the toggle show up and turn on the Aethercast backend. Actually casting to a
real Miracast receiver hasn't been tested yet.
