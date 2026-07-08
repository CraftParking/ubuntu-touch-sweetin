# Flashable zip installer

This is the original 2022 install script (`update-binary`/`ubports.sh`, originally by Erfan / Nobi
Nobita, based on osm0sis's anykernel2 pattern) with one thing removed and a couple of credit lines
added. Everything else is unchanged.

## What changed

`ubports.sh` used to flash a bundled old (Dec 2021) firmware zip near the end, via a nested
`twrp install /data/firmware-sweet.zip` call from inside the already-running install script. That
call doesn't actually block until the nested install finishes — TWRP just returns almost
immediately while the real work keeps going in the background — so the outer script would race
ahead into its cleanup steps while the firmware was still mid-flash. Removed that whole step. It
wasn't needed anyway: MIUI firmware is flashed separately via fastboot before any of this, as its
own step, and firmware partitions aren't touched by anything else in this script.

By the time that removed step used to run, `boot.img` is already flashed and `ubuntu.img` is
already in place — so nothing about actually booting Ubuntu Touch depended on it.

`update-binary` just has a few `ui_print` lines added near the top crediting the original authors,
so it shows up in TWRP's install log, not just buried in a text file nobody opens.

## How this fits into the actual install

This script expects `data/ubuntu.img` and `data/boot.img` to sit alongside it inside the same zip
(see the file layout used in this project's build script, not included here since it's just a
`zip -r` of this folder plus the data files). Flash order is: LineageOS 18.1 → format data → this
zip. See the main README for the full picture.
