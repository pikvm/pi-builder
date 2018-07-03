#!/bin/sh


rpi() {
	[ -n "$FS" ] || die "Empty variable \$FS"
	arch-chroot "$FS" "$@"
}

pkg_install() {
	rpi pacman --noconfirm -Syy
	rpi env MAKEPKGOPTS=--ignorearch user-aurman --noconfirm --noedit -S $@
	rpi pacman --noconfirm -Sc
}
