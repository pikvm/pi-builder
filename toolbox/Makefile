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
	exit 1


toolbox: clean-all
	test -n "$(DOCKER)"
	test -n "$(BOARD)"
	test -n "$(ARCH)"
	test -n "$(ARCH_DIST_REPO_URL)"
	test -n "$(_TOOLBOX_IMAGE)"
	test -n "$(__HOST_ARCH)"
	test $(ARCH) != $(__HOST_ARCH) || ln ../base/arch-$(BOARD)-$(ARCH).tgz .
	sed -e 's|%BASE_ROOTFS_TGZ%|arch-$(BOARD)-$(ARCH).tgz|g' Dockerfile.$(__HOST_ARCH) > Dockerfile
	cat Dockerfile.common >> Dockerfile
	$(DOCKER) build \
			--rm \
			--tag $(_TOOLBOX_IMAGE) \
			--build-arg "ARCH_DIST_REPO_URL=$(ARCH_DIST_REPO_URL)" \
			$(if $(call optbool,$(NC)),--no-cache,) \
		.


clean-all:
	rm -f *.tgz Dockerfile
