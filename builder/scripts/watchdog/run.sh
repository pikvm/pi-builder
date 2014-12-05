#!/bin/sh
set -e
set -x

. ../functions.sh


pkg_install watchdog
cp modules-load.d.conf "$FS/etc/modules-load.d/watchdog.conf"
cp modprobe.d.conf "$FS/etc/modprobe.d/watchdog.conf"
cp watchdog.conf "$FS/etc/watchdog.conf"
rpi systemctl enable watchdog
