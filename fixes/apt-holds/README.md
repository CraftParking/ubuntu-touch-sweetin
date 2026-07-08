# Package holds

Upgrading `unity8`, `ubuntu-touch`/`ubuntu-touch-session`, `bluez`/`bluebinder`, or the keyboard
packages on this image has bricked the boot (stuck at the Mi logo) multiple times during testing.
This upstart job just runs `apt-mark hold` on the ~175 packages that make up that whole dependency
web, so a plain `apt upgrade` can't touch them by accident.

Root is read-only at the point this job runs (`start on filesystem`), and `apt-mark`/`dpkg` need to
write to the dpkg status file, so the job remounts rw for just that one command and back to ro
right after — same pattern as every other fix here that touches system files.

## Deploying

```sh
sudo mount -o remount,rw /
sudo cp craftparking-apt-holds.conf /etc/init/craftparking-apt-holds.conf
sudo chown root:root /etc/init/craftparking-apt-holds.conf
sudo chmod 644 /etc/init/craftparking-apt-holds.conf
sudo mount -o remount,ro /
```

Runs automatically on every boot from then on. To apply immediately without rebooting:
`sudo start craftparking-apt-holds`.
