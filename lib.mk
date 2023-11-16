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


define optbool
$(filter $(shell echo $(1) | tr A-Z a-z),yes on 1)
endef


define say
@ tput -Txterm bold
@ tput -Txterm setaf 2
@ echo "===== $1 ====="
@ tput -Txterm sgr0
endef


define die
@ tput -Txterm bold
@ tput -Txterm setaf 1
@ echo "===== $1 ====="
@ tput -Txterm sgr0
@ exit 1
endef


define notempty
$(eval $(if $($(1)),,$(error $(1) is empty)))
endef


define append
$(foreach _item,$(3),$(1)$(_item)$(2))
endef


define contains
$(if $(findstring $(1),$(2)),$(3),$(4))
endef


define cachetag
test -n "$1"
echo "Signature: 8a477f597d28d172789f06886806bc55" > "$1/CACHEDIR.TAG"
endef
