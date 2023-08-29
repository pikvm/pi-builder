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


# =====
all:
	true


_ARM = arch-rpi2-arm arch-rpi3-arm arch-rpi4-arm arch-zero2w-arm
_AARCH64 = arch-rpi3-aarch64 arch-rpi4-aarch64
$(_ARM): _SUFFIX=rpi-armv7
$(_AARCH64): _SUFFIX=rpi-aarch64
$(_ARM) $(_AARCH64):
	test -n "$(_SUFFIX)"
	test -n "$(REPO_URL)"
	if [ ! -e $@.tgz ]; then \
		curl -L -f $(REPO_URL)/os/ArchLinuxARM-$(_SUFFIX)-latest.tar.gz -o $@.tgz.tmp \
		&& mv $@.tgz.tmp $@.tgz \
	; fi


clean:
	@true
clean-all: clean
	rm -f *.tgz *.tgz.tmp
