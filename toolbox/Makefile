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


toolbox: clean-all
	$(call not_empty,DOCKER)
	$(call not_empty,BOARD)
	$(call not_empty,ARCH)
	$(call not_empty,ARCH_DIST_REPO_URL)
	$(call not_empty,_TOOLBOX_IMAGE)
	$(call not_empty,__HOST_ARCH)
	if grep -q '^ADD %BASE_ROOTFS_TGZ%' Dockerfile.$(__HOST_ARCH); then ln ../base/arch-$(BOARD)-$(ARCH).tgz . ; fi
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
