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


qemu-arm: qemu-arm-static qemu-arm-static-orig
qemu-aarch64: qemu-aarch64-static


qemu-arm-static:
	$(eval _guest_arch = $(subst -static,,$(subst qemu-,,$@)))
	gcc \
			-static \
			-DQEMU_GUEST_ARCH=\"$(_guest_arch)\" \
			$(call contains,aarch64,$(_guest_arch),-m64,-m32) \
			qemu-wrapper.c \
		-o qemu-$(_guest_arch)-static


qemu-arm-static-orig qemu-aarch64-static:
	$(call not_empty,QEMU_REPO_URL)
	$(eval _guest_arch = $(call contains,aarch64,$@,aarch64,arm))
	$(eval _pkg = ./.pkg.$(_guest_arch))
	# Using i386 QEMU because of this:
	#   - https://bugs.launchpad.net/qemu/+bug/1805913
	#   - https://lkml.org/lkml/2018/12/27/155
	#   - https://stackoverflow.com/questions/27554325/readdir-32-64-compatibility-issues
	rm -rf $(_pkg)
	mkdir -p $(_pkg)
	curl -L -f $(QEMU_REPO_URL)/`curl -s -S -L -f $(QEMU_REPO_URL)/ \
			| grep qemu-user-static \
			| grep _$(call contains,aarch64,$(_guest_arch),amd64,i386).deb \
			| sort -n \
			| tail -n 1 \
			| sed -n 's/.*href="\([^"]*\).*/\1/p'` \
		-o $(_pkg)/qemu-user-static.deb
	cd $(_pkg) \
		&& ar vx qemu-user-static.deb \
		&& tar -xJf data.tar.xz
	cp $(_pkg)/usr/bin/qemu-$(_guest_arch)-static $@
	rm -rf $(_pkg)


clean-all:
	rm -rf .pkg.*
