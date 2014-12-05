#!/bin/sh
set -e
set -x

. ../functions.sh

# Based on https://gist.github.com/yeokm1/8b0ffc03e622ce011010
cp fstab "$FS/etc/fstab"
sed -i -e "s|\<rw\>|ro|g" "$FS/boot/cmdline.txt"
cp ro.sh "$FS/usr/local/bin/ro"
cp rw.sh "$FS/usr/local/bin/rw"

# rpi systemctl disable systemd-readahead-collect
rpi systemctl disable systemd-random-seed
rpi systemctl disable systemd-update-done
rpi systemctl disable man-db.service
rpi systemctl disable man-db.timer
