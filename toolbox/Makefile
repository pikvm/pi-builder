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


toolbox:
	test -n "$(DOCKER)"
	test -n "$(_TOOLBOX_IMAGE)"
	$(DOCKER) build \
			--rm \
			--tag $(_TOOLBOX_IMAGE) \
			$(if $(call optbool,$(NC)),--no-cache,) \
		.


clean:
	@true
clean-all: clean
	@true
