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

QEMU_PREFIX ?=
QEMU_RM ?= 1


# =====
_IMAGES_PREFIX = pi-builder
_TOOLBOX_IMAGE = $(_IMAGES_PREFIX)-toolbox

_TMP_DIR = ./.tmp
_BUILD_DIR = ./.build
_BUILDED_IMAGE_CONFIG = ./.builded.conf

_QEMU_RUNNER_ARCH = $(shell bash -c " \
	if [ '$(BOARD)' == rpi3-x64 ]; then echo aarch64; \
	else echo arm; \
	fi \
")
_QEMU_USER_STATIC_BASE_URL = http://mirror.yandex.ru/debian/pool/main/q/qemu
_QEMU_RUNNER_STATIC = $(_TMP_DIR)/qemu-$(_QEMU_RUNNER_ARCH)-static
_QEMU_RUNNER_STATIC_PLACE ?= $(QEMU_PREFIX)/usr/bin/qemu-$(_QEMU_RUNNER_ARCH)-static

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
_SAY = ./tools/say
_DIE = ./tools/die


# =====
define read_builded_config
$(shell grep "^$(1)=" $(_BUILDED_IMAGE_CONFIG) | cut -d"=" -f2)
endef

define show_running_config
	@ $(_SAY) "===== Running configuration ====="
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
	@ test -e $(_BUILDED_IMAGE_CONFIG) || $(_DIE) "===== Not builded yet ====="
endef


# =====
all:
	@ echo
	@ $(_SAY) "===== Available commands  ====="
	@ echo "    make                # Print this help"
	@ echo "    make rpi|rpi2|rpi3  # Build Arch-ARM rootfs with pre-defined config"
	@ echo "    make shell          # Run Arch-ARM shell"
	@ echo "    make toolbox        # Build the image with internal tools"
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


run: binfmt
	$(call check_build)
	docker run \
			--hostname $(call read_builded_config,HOSTNAME) \
			$(if $(RUN_CMD),$(RUN_OPTS),-i) \
		--rm -t $(call read_builded_config,IMAGE) $(if $(RUN_CMD),$(RUN_CMD),/bin/bash)


shell: override RUN_OPTS:="$(RUN_OPTS) -i"
shell: os


toolbox:
	@ $(_SAY) "===== Ensuring toolbox image ====="
	docker build --rm --tag $(_TOOLBOX_IMAGE) tools -f tools/Dockerfile.root
	@ $(_SAY) "===== Toolbox image is ready ====="


binfmt: toolbox
	docker run --privileged --rm -t $(_TOOLBOX_IMAGE) install-binfmt $(_QEMU_RUNNER_STATIC_PLACE) $(_QEMU_RUNNER_ARCH)


scan: toolbox
	@ $(_SAY) "===== Searching pies in the local network ====="
	docker run --net=host --rm -t $(_TOOLBOX_IMAGE) arp-scan --localnet | grep b8:27:eb: || true


os: binfmt _buildctx
	@ $(_SAY) "===== Building OS ====="
	rm -f $(_BUILDED_IMAGE_CONFIG)
	docker build $(BUILD_OPTS) \
			--build-arg "BOARD=$(BOARD)" \
			--build-arg "BASE_ROOTFS_TGZ=`basename $(_RPI_BASE_ROOTFS_TGZ)`" \
			--build-arg "QEMU_RUNNER_ARCH=$(_QEMU_RUNNER_ARCH)" \
			--build-arg "QEMU_RUNNER_STATIC_PLACE=$(_QEMU_RUNNER_STATIC_PLACE)" \
			--build-arg "LOCALE=$(LOCALE)" \
			--build-arg "TIMEZONE=$(TIMEZONE)" \
			--build-arg "REPO_URL=$(REPO_URL)" \
			--build-arg "REBUILD=$(shell uuidgen)" \
		--rm --tag $(_RPI_RESULT_IMAGE) $(_BUILD_DIR)
	echo "IMAGE=$(_RPI_RESULT_IMAGE)" > $(_BUILDED_IMAGE_CONFIG)
	echo "HOSTNAME=$(HOSTNAME)" >> $(_BUILDED_IMAGE_CONFIG)
	$(call show_running_config)
	@ $(_SAY) "===== Build complete ====="


# =====
_buildctx: _rpi_base_rootfs_tgz _qemu_runner_static
	@ $(_SAY) "===== Assembling main Dockerfile ====="
	rm -rf $(_BUILD_DIR)
	mkdir -p $(_BUILD_DIR)
	cp $(_RPI_BASE_ROOTFS_TGZ) $(_BUILD_DIR)
	cp $(_QEMU_RUNNER_STATIC) $(_BUILD_DIR)
	cp -r $(_SAY) $(_DIE) $(_BUILD_DIR)
	cp -r stages $(_BUILD_DIR)
	echo -n > $(_BUILD_DIR)/Dockerfile
	for stage in $(STAGES); do \
		cat $(_BUILD_DIR)/stages/$$stage/Dockerfile.part >> $(_BUILD_DIR)/Dockerfile; \
	done
	@ $(_SAY) "===== Main Dockerfile is ready ====="


_rpi_base_rootfs_tgz:
	@ $(_SAY) "===== Ensuring base rootfs ====="
	if [ ! -e $(_RPI_BASE_ROOTFS_TGZ) ]; then \
		mkdir -p $(_TMP_DIR) \
		&& curl -L -f $(_RPI_ROOTFS_URL) -z $(_RPI_BASE_ROOTFS_TGZ) -o $(_RPI_BASE_ROOTFS_TGZ) \
		&& $(_SAY) "===== Base rootfs downloaded =====" \
	; else \
		$(_SAY) "===== Base rootfs found =====" \
	; fi


_qemu_runner_static:
	@ $(_SAY) "===== Ensuring QEMU ====="
	# Using i386 QEMU because of this:
	#   - https://bugs.launchpad.net/qemu/+bug/1805913
	#   - https://lkml.org/lkml/2018/12/27/155
	#   - https://stackoverflow.com/questions/27554325/readdir-32-64-compatibility-issues
	if [ ! -e $(_QEMU_RUNNER_STATIC) ]; then \
		mkdir -p $(_TMP_DIR)/qemu-user-static-deb \
		&& curl -L -f $(_QEMU_USER_STATIC_BASE_URL)/`curl -s -S -L -f $(_QEMU_USER_STATIC_BASE_URL)/ -z $(_QEMU_RUNNER_STATIC) \
				| grep qemu-user-static \
				| grep _i386.deb \
				| sort -n \
				| tail -n 1 \
				| sed -n 's/.*href="\([^"]*\).*/\1/p'` -z $(_QEMU_RUNNER_STATIC) \
			-o $(_TMP_DIR)/qemu-user-static-deb/qemu-user-static.deb \
		&& pushd $(_TMP_DIR)/qemu-user-static-deb \
		&& ar vx qemu-user-static.deb \
		&& tar -xJf data.tar.xz \
		&& popd \
		&& cp $(_TMP_DIR)/qemu-user-static-deb/usr/bin/qemu-$(_QEMU_RUNNER_ARCH)-static $(_QEMU_RUNNER_STATIC) \
		&& $(_SAY) "===== QEMU downloaded =====" \
	; else \
		$(_SAY) "===== QEMU found =====" \
	; fi


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


clean-all: toolbox clean
	$(__DOCKER_RUN_TMP) rm -rf $(_RPI_RESULT_ROOTFS)
	rm -rf $(_TMP_DIR)


format: toolbox
	$(call check_build)
	@ $(_SAY) "===== Formatting $(CARD) ====="
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
	@ $(_SAY) "===== Format complete ====="


extract: toolbox
	$(call check_build)
	@ $(_SAY) "===== Extracting image from Docker ====="
	$(__DOCKER_RUN_TMP) rm -rf $(_RPI_RESULT_ROOTFS)
	docker save --output $(_RPI_RESULT_ROOTFS_TAR) $(call read_builded_config,IMAGE)
	$(__DOCKER_RUN_TMP) docker-extract --root $(_RPI_RESULT_ROOTFS) $(_RPI_RESULT_ROOTFS_TAR)
	$(__DOCKER_RUN_TMP) bash -c " \
		echo $(call read_builded_config,HOSTNAME) > $(_RPI_RESULT_ROOTFS)/etc/hostname \
		&& (test -z '$(QEMU_RM)' || rm $(_RPI_RESULT_ROOTFS)/$(_QEMU_RUNNER_STATIC_PLACE)) \
	"
	@ $(_SAY) "===== Extraction complete ====="


install: extract format
	@ $(_SAY) "===== Installing to $(CARD) ====="
	$(__DOCKER_RUN_TMP_PRIVILEGED) bash -c " \
		mkdir -p mnt/boot mnt/rootfs \
		&& mount $(_CARD_BOOT) mnt/boot \
		&& mount $(_CARD_ROOT) mnt/rootfs \
		&& rsync -a --info=progress2 $(_RPI_RESULT_ROOTFS)/boot/* mnt/boot \
		&& rsync -a --info=progress2 $(_RPI_RESULT_ROOTFS)/* mnt/rootfs --exclude boot \
		&& mkdir mnt/rootfs/boot \
		&& umount mnt/boot mnt/rootfs \
	"
	@ $(_SAY) "===== Installation complete ====="


.NOTPARALLEL: clean-all install
