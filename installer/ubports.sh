# data/linux Touch Port
# Base Flashable With Erfan . Edit By Nobi Nobita
# Craftparking: removed the nested "twrp install firmware*.zip" step below -
# it doesn't block (confirmed empirically), which stalled the whole install.
# MIUI firmware is flashed separately via fastboot before this zip anyway.

OUTFD=/proc/self/fd/$1;
CODENAME=$(getprop ro.product.device)

# ui_print <text>
ui_print() { echo -e "ui_print $1\nui_print" > $OUTFD; }

## data/linux Touch Install For Sweet

# Remove Old File
ui_print " Remove old rootfs";
rm -rf /data/ubuntu.img;

# Copy And Patch New File
ui_print " Copy new rootfs";
mv -f /data/ubports/data/ubuntu.img /data/;
mv -f /data/ubports/data/boot.img /data/;

# 8GB Rootfs
ui_print " Resizing rootfs to 8GB";
e2fsck -fy /data/ubuntu.img
resize2fs -f /data/ubuntu.img 8G

# Swap images 4G
ui_print " Resizing SWAP 4GB";
fallocate -l 4G /data/SWAP.img
chmod 600 /data/SWAP.img
mkswap /data/SWAP.img

# Create Folder Mount
mkdir -p /data/linux/ubuntu;

# Mount *.img to Folder Mount
ui_print " Mount rootfs";
mount /data/ubuntu.img /data/linux/ubuntu;

# Udev
ui_print " Create rules";
cat /vendor/ueventd*.rc | grep ^/dev | sed -e 's/^\/dev\///' | awk '{printf "ACTION==\"add\", KERNEL==\"%s\", OWNER=\"%s\", GROUP=\"%s\", MODE=\"%s\"\n",$1,$3,$4,$2}' | sed -e 's/\r//' > /data/linux/ubuntu/etc/udev/rules.d/70-sweet.rules

# Bootable
ui_print " Flash halium boot";
dd if=/data/boot.img of=/dev/block/by-name/boot

# Umount All *.img
ui_print " Clean";
umount /data/linux/ubuntu;

# Remove Install file
rm -rf /data/ubports;
rm -rf /data/linux;

## Install Done ##
