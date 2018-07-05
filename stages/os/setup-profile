#!/bin/sh
set -e
set -x


PROFILE="$1"; [ -n "$PROFILE" ] || die "Required argument: path to profile (/root for example)"
USER=`basename "$PROFILE"`; [ "$PROFILE" != "/" ] || die "Invalid user '/'"


mkdir /tmp/linux-profile
git clone https://github.com/mdevaev/linux-profile.git /tmp/linux-profile --depth=1
cp -a /tmp/linux-profile/{.bash_profile,.bashrc,.gitconfig,.vimrc,.vim} "$PROFILE"
rm -rf /tmp/linux-profile
chown -R "$USER:$USER" "$PROFILE"
