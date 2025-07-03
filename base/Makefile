# ========================================================================== #
#                                                                            #
#    pi-builder - extensible tool to build Arch Linux ARM for Raspberry Pi   #
#                 on x86_64 host using Docker.                               #
#                                                                            #
#    Copyright (C) 2018-2023  Maxim Devaev <mdevaev@gmail.com>               #
#                                                                            #
#    This program is free software: you can redistribute it and/or modify    #
#    it under the terms of the GNU General Public License as published by    #
#    the Free Software Foundation, either version 3 of the License, or       #
#    (at your option) any later version.                                     #
#                                                                            #
#    This program is distributed in the hope that it will be useful,         #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of          #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           #
#    GNU General Public License for more details.                            #
#                                                                            #
#    You should have received a copy of the GNU General Public License       #
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.  #
#                                                                            #
# ========================================================================== #


include ../lib.mk


# =====
all:
	exit 1


# =====
_ARCH_LIST := \
	$(call append,arch-,-arm,rpi2 rpi3 rpi4 zero2w) \
	$(call append,arch-,-aarch64,rpi3 rpi4 rpi5 zero2w)


$(call append,,.tgz,$(_ARCH_LIST)):
	$(call notempty,ARCH_DIST_REPO_URL)
	$(eval _arch = $(call contains,-arm,$@,armv7,aarch64))
	curl -L -f $(ARCH_DIST_REPO_URL)/os/ArchLinuxARM-rpi-$(_arch)-latest.tar.gz -o $@.tmp
	mv $@.tmp $@


# =====
_RPIOS_LIST := \
	$(call append,rpios-,-arm,rpi rpi2 rpi3 rpi4 rpi5 zerow zero2w) \
	$(call append,rpios-,-aarch64,rpi3 rpi4 rpi5 zero2w)


$(call append,,.tgz,$(_RPIOS_LIST)):
	$(eval _base = $(subst .tgz,,$@))
	$(MAKE) $(_base).img
	mkdir $(_base).mnt
	#
	set -Eeuo pipefail \
		&& loop=`$(SUDO) losetup -P -f --show $(_base).img` \
		&& $(SUDO) mount $${loop}p2 $(_base).mnt \
		&& $(SUDO) mount $${loop}p1 $(_base).mnt/boot/firmware \
		&& $(SUDO) tar -czf $@.tmp -C $(_base).mnt . \
		&& $(SUDO) chown `id -u`:`id -g` $@.tmp \
		&& $(SUDO) mv $@.tmp $@ \
		&& $(SUDO) umount $(_base).mnt/boot/firmware \
		&& $(SUDO) umount $(_base).mnt \
		&& $(SUDO) losetup -d $$loop
	#
	rmdir $(_base).mnt


$(call append,,.img,$(_RPIOS_LIST)):
	$(call notempty,RPIOS_IMAGES_URL)
	$(eval _arch = $(call contains,-arm,$@,armhf,arm64))
	rm -f $@.xz.tmp $@.tmp
	set -Eeuo pipefail \
		&& url=$(RPIOS_IMAGES_URL)/raspios_lite_$(_arch)/images \
		&& url=$$url/raspios_lite_$(_arch)-`curl -s -S -L -f $$url \
			| grep raspios_lite_$(_arch)-2 \
			| sort -n \
			| tail -n 1 \
			| sed -n 's/.*href="raspios_lite_$(_arch)-\([^\/]*\).*/\1/p'` \
		&& url=$$url/`curl -s -S -L -f $$url \
			| grep '$(_arch)-lite.img.xz"' \
			| sed -n 's/.*href="\([^\"]*\).*/\1/p'` \
		&& echo "Downloading: $$url" \
		&& curl -L -f $$url -o $@.xz.tmp
	#
	xzcat $@.xz.tmp > $@.tmp
	rm -f $@.xz.tmp
	mv $@.tmp $@


# =====
clean-all:
	rm -f *.tgz *.tmp *.img *.xz
