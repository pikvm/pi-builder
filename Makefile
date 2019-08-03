-include config.mk

PROJECT ?= common
BOARD ?= rpi
STAGES ?= __init__ os pikvm-repo watchdog ro ssh-root ssh-keygen __cleanup__

HOSTNAME ?= pi
LOCALE ?= en_US
TIMEZONE ?= Europe/Moscow
REPO_URL ?= http://mirror.yandex.ru/archlinux-arm
BUILD_OPTS ?=

CARD ?= /dev/mmcblk0

QEMU_PREFIX ?= /usr
QEMU_RM ?= 1


# =====
_IMAGES_PREFIX = pi-builder
_TOOLBOX_IMAGE = $(_IMAGES_PREFIX)-toolbox

_TMP_DIR = ./.tmp
_BUILD_DIR = ./.build
_BUILDED_IMAGE_CONFIG = ./.builded.conf

_QEMU_GUEST_ARCH = $(shell bash -c " \
	if [ '$(BOARD)' == rpi3-x64 ]; then echo aarch64; \
	else echo arm; \
	fi \
")
_QEMU_STATIC_BASE_URL = http://mirror.yandex.ru/debian/pool/main/q/qemu
_QEMU_COLLECTION = $(_TMP_DIR)/qemu
_QEMU_STATIC = $(_QEMU_COLLECTION)/qemu-$(_QEMU_GUEST_ARCH)-static
_QEMU_STATIC_GUEST_PATH ?= $(QEMU_PREFIX)/bin/qemu-$(_QEMU_GUEST_ARCH)-static

_RPI_ROOTFS_URL = $(REPO_URL)/os/ArchLinuxARM-$(shell bash -c " \
	if [ '$(BOARD)' == rpi ]; then echo rpi; \
	elif [ '$(BOARD)' == rpi2 -o '$(BOARD)' == rpi3 ]; then echo rpi-2; \
	elif [ '$(BOARD)' == rpi3-x64 ]; then echo rpi-3; \
	else exit 1; \
	fi \
")-latest.tar.gz
_RPI_BASE_ROOTFS_TGZ = $(_TMP_DIR)/base-rootfs-$(BOARD).tar.gz
_RPI_BASE_IMAGE = $(_IMAGES_PREFIX)-base-$(BOARD)
_RPI_RESULT_IMAGE = $(PROJECT)-$(_IMAGES_PREFIX)-result-$(BOARD)
_RPI_RESULT_ROOTFS_TAR = $(_TMP_DIR)/result-rootfs.tar
_RPI_RESULT_ROOTFS = $(_TMP_DIR)/result-rootfs

_CARD_P = $(if $(findstring mmcblk,$(CARD)),p,$(if $(findstring loop,$(CARD)),p,))
_CARD_BOOT = $(CARD)$(_CARD_P)1
_CARD_ROOT = $(CARD)$(_CARD_P)2


# =====
define optbool
$(filter $(shell echo $(1) | tr A-Z a-z),yes on 1)
endef

define say
@ tput bold
@ tput setaf 2
@ echo "===== $1 ====="
@ tput sgr0
endef

define die
@ tput bold
@ tput setaf 1
@ echo "===== $1 ====="
@ tput sgr0
@ exit 1
endef

define read_builded_config
$(shell grep "^$(1)=" $(_BUILDED_IMAGE_CONFIG) | cut -d"=" -f2)
endef

define show_running_config
$(call say,"Running configuration")
@ echo "    PROJECT = $(PROJECT)"
@ echo "    BOARD   = $(BOARD)"
@ echo "    STAGES  = $(STAGES)"
@ echo
@ echo "    BUILD_OPTS = $(BUILD_OPTS)"
@ echo "    HOSTNAME   = $(HOSTNAME)"
@ echo "    LOCALE     = $(LOCALE)"
@ echo "    TIMEZONE   = $(TIMEZONE)"
@ echo "    REPO_URL   = $(REPO_URL)"
@ echo
@ echo "    CARD = $(CARD)"
@ echo "           |-- boot: $(_CARD_BOOT)"
@ echo "           +-- root: $(_CARD_ROOT)"
@ echo
@ echo "    QEMU_PREFIX = $(QEMU_PREFIX)"
@ echo "    QEMU_RM     = $(QEMU_RM)"
endef

define check_build
$(if $(wildcard $(_BUILDED_IMAGE_CONFIG)),,$(call die,"Not builded yet"))
endef


# =====
__DEP_BINFMT := $(if $(call optbool,$(PASS_ENSURE_BINFMT)),,binfmt)
__DEP_TOOLBOX := $(if $(call optbool,$(PASS_ENSURE_TOOLBOX)),,toolbox)


# =====
all:
	@ echo
	$(call say,"Available commands")
	@ echo "    make                # Print this help"
	@ echo "    make rpi|rpi2|rpi3  # Build Arch-ARM rootfs with pre-defined config"
	@ echo "    make shell          # Run Arch-ARM shell"
	@ echo "    make toolbox        # Build the toolbox image"
	@ echo "    make binfmt         # Configure ARM binfmt on the host system"
	@ echo "    make scan           # Find all RPi devices in the local network"
	@ echo "    make clean          # Remove the generated rootfs"
	@ echo "    make format         # Format $(CARD) to $(_CARD_BOOT) (vfat), $(_CARD_ROOT) (ext4)"
	@ echo "    make install        # Install rootfs to partitions on $(CARD)"
	@ echo
	$(call show_running_config)
	@ echo


rpi: BOARD=rpi
rpi2: BOARD=rpi2
rpi3: BOARD=rpi3
rpi rpi2 rpi3: os


run: $(__DEP_BINFMT)
	$(call check_build)
	docker run \
			--hostname $(call read_builded_config,HOSTNAME) \
			$(if $(RUN_CMD),$(RUN_OPTS),-i) \
		--rm -t $(call read_builded_config,IMAGE) $(if $(RUN_CMD),$(RUN_CMD),/bin/bash)


shell: override RUN_OPTS:="$(RUN_OPTS) -i"
shell: run


toolbox:
	$(call say,"Ensuring toolbox image")
	docker build --rm --tag $(_TOOLBOX_IMAGE) toolbox -f toolbox/Dockerfile.root
	$(call say,"Toolbox image is ready")


binfmt: $(__DEP_TOOLBOX)
	$(call say,"Ensuring $(_QEMU_GUEST_ARCH) binfmt")
	docker run --privileged --rm -t $(_TOOLBOX_IMAGE) /tools/install-binfmt \
		--mount \
		$(_QEMU_GUEST_ARCH) \
		$(_QEMU_STATIC_GUEST_PATH)
	$(call say,"Binfmt $(_QEMU_GUEST_ARCH) is ready")


scan: $(__DEP_TOOLBOX)
	$(call say,"Searching pies in the local network")
	docker run --net=host --rm -t $(_TOOLBOX_IMAGE) arp-scan --localnet | grep b8:27:eb: || true


os: $(__DEP_BINFMT) _buildctx
	$(call say,"Building OS")
	rm -f $(_BUILDED_IMAGE_CONFIG)
	docker build $(BUILD_OPTS) \
			$(if $(call optbool,$(NC)),--no-cache,) \
			--build-arg "BOARD=$(BOARD)" \
			--build-arg "BASE_ROOTFS_TGZ=`basename $(_RPI_BASE_ROOTFS_TGZ)`" \
			--build-arg "QEMU_RUNNER_ARCH=$(_QEMU_GUEST_ARCH)" \
			--build-arg "QEMU_RUNNER_STATIC_PLACE=$(_QEMU_STATIC_GUEST_PATH)" \
			--build-arg "LOCALE=$(LOCALE)" \
			--build-arg "TIMEZONE=$(TIMEZONE)" \
			--build-arg "REPO_URL=$(REPO_URL)" \
			--build-arg "REBUILD=$(shell uuidgen)" \
		--rm --tag $(_RPI_RESULT_IMAGE) $(_BUILD_DIR)
	echo "IMAGE=$(_RPI_RESULT_IMAGE)" > $(_BUILDED_IMAGE_CONFIG)
	echo "HOSTNAME=$(HOSTNAME)" >> $(_BUILDED_IMAGE_CONFIG)
	$(call show_running_config)
	$(call say,"Build complete")


# =====
_buildctx: _rpi_base_rootfs_tgz $(_QEMU_COLLECTION)
	$(call say,"Assembling main Dockerfile")
	rm -rf $(_BUILD_DIR)
	mkdir -p $(_BUILD_DIR)
	cp $(_RPI_BASE_ROOTFS_TGZ) $(_BUILD_DIR)
	cp $(_QEMU_STATIC) $(_BUILD_DIR)
	cp -r stages $(_BUILD_DIR)
	echo -n > $(_BUILD_DIR)/Dockerfile
	for stage in $(STAGES); do \
		cat $(_BUILD_DIR)/stages/$$stage/Dockerfile.part >> $(_BUILD_DIR)/Dockerfile; \
	done
	$(call say,"Main Dockerfile is ready")


_rpi_base_rootfs_tgz:
	$(call say,"Ensuring base rootfs")
	if [ ! -e $(_RPI_BASE_ROOTFS_TGZ) ]; then \
		mkdir -p $(_TMP_DIR) \
		&& curl -L -f $(_RPI_ROOTFS_URL) -z $(_RPI_BASE_ROOTFS_TGZ) -o $(_RPI_BASE_ROOTFS_TGZ) \
	; fi
	$(call say,"Base rootfs is ready")


$(_QEMU_COLLECTION):
	$(call say,"Downloading QEMU")
	# Using i386 QEMU because of this:
	#   - https://bugs.launchpad.net/qemu/+bug/1805913
	#   - https://lkml.org/lkml/2018/12/27/155
	#   - https://stackoverflow.com/questions/27554325/readdir-32-64-compatibility-issues
	mkdir -p $(_TMP_DIR)/qemu-user-static-deb
	curl -L -f $(_QEMU_STATIC_BASE_URL)/`curl -s -S -L -f $(_QEMU_STATIC_BASE_URL)/ \
			-z $(_TMP_DIR)/qemu-user-static-deb/qemu-user-static.deb \
				| grep qemu-user-static \
				| grep _i386.deb \
				| sort -n \
				| tail -n 1 \
				| sed -n 's/.*href="\([^"]*\).*/\1/p'` \
		-o $(_TMP_DIR)/qemu-user-static-deb/qemu-user-static.deb \
		-z $(_TMP_DIR)/qemu-user-static-deb/qemu-user-static.deb
	cd $(_TMP_DIR)/qemu-user-static-deb \
		&& ar vx qemu-user-static.deb \
		&& tar -xJf data.tar.xz
	rm -rf $(_QEMU_COLLECTION).tmp
	mkdir $(_QEMU_COLLECTION).tmp
	cp $(_TMP_DIR)/qemu-user-static-deb/usr/bin/qemu-arm-static $(_QEMU_COLLECTION).tmp
	cp $(_TMP_DIR)/qemu-user-static-deb/usr/bin/qemu-aarch64-static $(_QEMU_COLLECTION).tmp
	mv $(_QEMU_COLLECTION).tmp $(_QEMU_COLLECTION)
	$(call say,"QEMU ready")


# =====
clean:
	rm -rf $(_BUILD_DIR) $(_BUILDED_IMAGE_CONFIG)


__DOCKER_RUN_TMP = docker run \
	-v $(shell pwd)/$(_TMP_DIR):/root/$(_TMP_DIR) \
	-w /root/$(_TMP_DIR)/.. \
	--rm -t $(_TOOLBOX_IMAGE)


__DOCKER_RUN_TMP_PRIVILEGED = docker run \
	-v $(shell pwd)/$(_TMP_DIR):/root/$(_TMP_DIR) \
	-w /root/$(_TMP_DIR)/.. \
	--privileged --rm -t $(_TOOLBOX_IMAGE)


clean-all: $(__DEP_TOOLBOX) clean
	$(__DOCKER_RUN_TMP) rm -rf $(_RPI_RESULT_ROOTFS)
	rm -rf $(_TMP_DIR)


format: $(__DEP_TOOLBOX)
	$(call check_build)
	$(call say,"Formatting $(CARD)")
	$(__DOCKER_RUN_TMP_PRIVILEGED) bash -c " \
		set -x \
		&& set -e \
		&& dd if=/dev/zero of=$(CARD) bs=512 count=1 \
		&& partprobe $(CARD) \
	"
	$(__DOCKER_RUN_TMP_PRIVILEGED) bash -c " \
		set -x \
		&& set -e \
		&& parted $(CARD) -s mklabel msdos \
		&& parted $(CARD) -a optimal -s mkpart primary fat32 0% 128MiB \
		&& parted $(CARD) -s mkpart primary 128MiB 100% \
		&& partprobe $(CARD) \
	"
	$(__DOCKER_RUN_TMP_PRIVILEGED) bash -c " \
		set -x \
		&& set -e \
		&& mkfs.vfat $(_CARD_BOOT) \
		&& yes | mkfs.ext4 $(_CARD_ROOT) \
	"
	$(call say,"Format complete")


extract: $(__DEP_TOOLBOX)
	$(call check_build)
	$(call say,"Extracting image from Docker")
	$(__DOCKER_RUN_TMP) rm -rf $(_RPI_RESULT_ROOTFS)
	docker save --output $(_RPI_RESULT_ROOTFS_TAR) $(call read_builded_config,IMAGE)
	$(__DOCKER_RUN_TMP) /tools/docker-extract --root $(_RPI_RESULT_ROOTFS) $(_RPI_RESULT_ROOTFS_TAR)
	$(__DOCKER_RUN_TMP) bash -c " \
		echo $(call read_builded_config,HOSTNAME) > $(_RPI_RESULT_ROOTFS)/etc/hostname \
		&& (test -z '$(call optbool,$(QEMU_RM))' || rm $(_RPI_RESULT_ROOTFS)/$(_QEMU_STATIC_GUEST_PATH)) \
	"
	$(call say,"Extraction complete")


install: extract format
	$(call say,"Installing to $(CARD)")
	$(__DOCKER_RUN_TMP_PRIVILEGED) bash -c " \
		mkdir -p mnt/boot mnt/rootfs \
		&& mount $(_CARD_BOOT) mnt/boot \
		&& mount $(_CARD_ROOT) mnt/rootfs \
		&& rsync -a --info=progress2 $(_RPI_RESULT_ROOTFS)/boot/* mnt/boot \
		&& rsync -a --info=progress2 $(_RPI_RESULT_ROOTFS)/* mnt/rootfs --exclude boot \
		&& mkdir mnt/rootfs/boot \
		&& umount mnt/boot mnt/rootfs \
	"
	$(call say,"Installation complete")


.PHONY: toolbox
.NOTPARALLEL: clean-all install
