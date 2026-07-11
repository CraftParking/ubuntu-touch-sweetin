#!/bin/bash
# Builds the single flashable zip from a LineageOS 18.1 OTA zip + a UBports flashable zip.
# Neither of those is bundled here (multi-GB binaries, not something to put in a git repo) -
# grab your own copies and point this script at them.
#
# Usage: ./build-single-zip.sh <lineage-ota.zip> <ubports-zip> <output.zip>

set -e
LINEAGE_ZIP="$1"
UBPORTS_ZIP="$2"
OUT="$3"
WORK=$(mktemp -d)

if [ -z "$OUT" ]; then
  echo "usage: $0 <lineage-ota.zip> <ubports-zip> <output.zip>"
  exit 1
fi

echo "-- pulling LineageOS's 5 dynamic partitions + boot/dtbo/vbmeta out of the OTA zip --"
mkdir -p "$WORK/lineage-parts"
unzip -o "$LINEAGE_ZIP" -d "$WORK/lineage-extract" > /dev/null

# sdat2img converts each .new.dat(.br) + .transfer.list into a flat, dd-able .img.
# get it from https://github.com/xpirt/sdat2img if you don't have it already.
for part in system vendor product odm system_ext; do
  [ -f "$WORK/lineage-extract/$part.new.dat.br" ] && brotli -d "$WORK/lineage-extract/$part.new.dat.br"
  python3 sdat2img.py "$WORK/lineage-extract/$part.transfer.list" \
    "$WORK/lineage-extract/$part.new.dat" "$WORK/lineage-parts/$part.img"
done
cp "$WORK/lineage-extract/boot.img" "$WORK/lineage-extract/dtbo.img" "$WORK/lineage-extract/vbmeta.img" \
  "$WORK/lineage-parts/"

echo "-- pulling ubuntu.img/boot.img/busybox/ubports.sh out of the UBports zip --"
unzip -o "$UBPORTS_ZIP" "data/ubuntu.img" "data/boot.img" "tools/busybox" -d "$WORK" > /dev/null

echo "-- assembling the zip --"
mkdir -p "$WORK/META-INF/com/google/android" "$WORK/bin"
cp update-binary "$WORK/META-INF/com/google/android/update-binary"
chmod 755 "$WORK/META-INF/com/google/android/update-binary"
echo "# dummy" > "$WORK/META-INF/com/google/android/updater-script"
cp mkfs.f2fs.static "$WORK/bin/mkfs.f2fs.static"
chmod 755 "$WORK/bin/mkfs.f2fs.static"
cp ubports.sh "$WORK/ubports.sh"

cd "$WORK"
zip -r "$OUT" META-INF lineage-parts bin data tools ubports.sh
cd - > /dev/null
rm -rf "$WORK"

echo "-- done: $OUT --"
