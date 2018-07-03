#!/bin/sh
set -e
set -x

. ../functions.sh


# === Common ===
setup-profile "$FS/root"


echo pi > "$FS/etc/hostname"
ln -sf "/usr/share/zoneinfo/Europe/Moscow" "$FS/etc/localtime"


echo "en_US.UTF-8 UTF-8" > "$FS/etc/locale.gen"
# https://lists.gnu.org/archive/html/qemu-devel/2017-10/msg03681.html
# <hack>
cd "$FS/usr/share/i18n/charmaps"
gunzip --keep UTF-8.gz
cd -
rpi locale-gen en_US.UTF-8
# </hack>
#rpi locale-gen en_US.UTF-8


echo "gpu_mem=16" > "$FS/boot/config.txt"


# === Packages ===
rpi pacman-key --init
rpi pacman-key --populate archlinuxarm
rpi pacman --noconfirm -Syy
rpi pacman --noconfirm -S pacman
rpi pacman-db-upgrade
rpi pacman --noconfirm -S \
	archlinux-keyring \
	ca-certificates \
	ca-certificates-cacert \
	ca-certificates-mozilla \
	ca-certificates-utils
rpi pacman --noconfirm -Sc
#rpi pacman-key --refresh-keys

rpi pacman --noconfirm -Syu

rpi pacman --noconfirm -S \
	vim \
	colordiff \
	wget \
	unzip \
	htop \
	iftop \
	iotop \
	strace \
	lsof \
	patch \
	make \
	fakeroot \
	binutils \
	gcc \
	git \
	jshon \
	python \
	python-requests \
	python-regex \
	pyalpm \
	expac \
	sudo
rpi pacman --noconfirm -Sc

rpi useradd -r -m aurman -s /bin/bash
# FIXME: Official repo has a broken expac:
# https://github.com/falconindy/expac/pull/36
rpi bash -c '
		cd /tmp \
		\
		&& sudo -u aurman git clone --depth=1 https://aur.archlinux.org/aurman.git \
		&& cd aurman \
		&& sudo -u aurman makepkg --skippgpcheck \
		&& pacman --noconfirm -U aurman-*.pkg.tar.xz \
		&& cd - \
		\
		&& sudo -u aurman git clone --depth=1 https://github.com/mdevaev/expac.git \
		&& cd expac \
		&& sudo -u aurman make expac \
		&& cp expac /usr/bin/expac \
		&& echo -e "\n# https://github.com/falconindy/expac/pull/36\n[options]\nIgnorePkg = expac" >> /etc/pacman.conf \
		&& cd - \
		\
		&& rm -rf /tmp/aurman /tmp/expac
'

echo "aurman ALL=(ALL) NOPASSWD: ALL" >> "$FS/etc/sudoers"
cp `which user-aurman` "$FS/usr/local/bin/user-aurman"
chmod +x "$FS/usr/local/bin/user-aurman"
