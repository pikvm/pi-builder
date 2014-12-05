#!/bin/sh
set -e
set -x

. ../functions.sh


cp *.pub "$FS/etc/ssh/authorized_keys"
chmod 600 "$FS/etc/ssh/authorized_keys"
sed -i -e "s|AuthorizedKeysFile[[:space:]]\+\.ssh/authorized_keys|AuthorizedKeysFile /etc/ssh/authorized_keys|g" "$FS/etc/ssh/sshd_config"
echo "PasswordAuthentication no" >> "$FS/etc/ssh/sshd_config"
rpi ssh-keygen -A
