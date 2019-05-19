-include config.mk

PROJECT ?= common
BOARD ?= rpi
STAGES ?= __init__ os watchdog ro rootssh sshkeygen __cleanup__

HOSTNAME ?= pi
LOCALE ?= en_US
TIMEZONE ?= Europe/Moscow
REPO_URL ?= http://mirror.yandex.ru/archlinux-arm
BUILD_OPTS ?=

CARD ?= /dev/mmcblk0


# =====
_TMP_DIR = ./.tmp
_BUILD_DIR = ./.build
_BUILDED_IMAGE = ./.builded_image

ifeq ($(BOARD), rpi)
	_QEMU_RUNNER_ARCH = arm
	_RPI_ROOTFS_URL = $(REPO_URL)/os/ArchLinuxARM-rpi-latest.tar.gz
else ifeq ($(BOARD), rpi2)
	_QEMU_RUNNER_ARCH = arm
	_RPI_ROOTFS_URL = $(REPO_URL)/os/ArchLinuxARM-rpi-2-latest.tar.gz
else ifeq ($(BOARD), rpi3)
	_QEMU_RUNNER_ARCH = arm
	_RPI_ROOTFS_URL = $(REPO_URL)/os/ArchLinuxARM-rpi-2-latest.tar.gz
else ifeq ($(BOARD), rpi3-x64)
	_QEMU_RUNNER_ARCH = aarch64
	_RPI_ROOTFS_URL = $(REPO_URL)/os/ArchLinuxARM-rpi-3-latest.tar.gz
endif

_QEMU_USER_STATIC_BASE_URL = http://mirror.yandex.ru/debian/pool/main/q/qemu
_QEMU_RUNNER_STATIC = $(_TMP_DIR)/qemu-$(_QEMU_RUNNER_ARCH)-static
_QEMU_RUNNER_STATIC_PLACE ?= /usr/bin/qemu-$(_QEMU_RUNNER_ARCH)-static

_IMAGES_PREFIX = pi-builder

_ROOT_RUNNER = $(_IMAGES_PREFIX)-root-runner

_RPI_BASE_ROOTFS_TGZ = $(_TMP_DIR)/base-rootfs-$(BOARD).tar.gz
_RPI_BASE_IMAGE = $(_IMAGES_PREFIX)-base-$(BOARD)
_RPI_RESULT_IMAGE = $(PROJECT)-$(_IMAGES_PREFIX)-result-$(BOARD)
_RPI_RESULT_ROOTFS_TAR = $(_TMP_DIR)/result-rootfs.tar
_RPI_RESULT_ROOTFS = $(_TMP_DIR)/result-rootfs

ifeq ($(findstring mmcblk, $(CARD)), mmcblk)
	_CARD_P = p
else ifeq ($(findstring loop, $(CARD)), loop)
	_CARD_P = p
endif
_CARD_BOOT ?= $(CARD)$(_CARD_P)1
_CARD_ROOT ?= $(CARD)$(_CARD_P)2


# =====
define show_config
	@ ./tools/say "===== Target configuration ====="
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
endef

define check_build
	@ test -e $(_BUILDED_IMAGE) || ./tools/die "===== Not builded yet ====="
endef


# =====
all:
	@ echo
	@ ./tools/say "===== Available commands  ====="
	@ echo "    make                # Print this help"
	@ echo "    make rpi|rpi2|rpi3  # Build Arch-ARM rootfs with pre-defined config"
	@ echo "    make shell          # Run Arch-ARM shell"
	@ echo "    make binfmt         # Before build"
	@ echo "    make scan           # Find all RPi devices in the local network"
	@ echo "    make clean          # Remove the generated rootfs"
	@ echo "    make format         # Format $(CARD) to $(_CARD_BOOT) (vfat), $(_CARD_ROOT) (ext4)"
	@ echo "    make install        # Install rootfs to partitions on $(CARD)"
	@ echo
	$(call show_config)
	@ echo


rpi:
	make os \
		BUILD_OPTS="$(BUILD_OPTS) --build-arg NEW_SSH_KEYGEN=$(shell uuidgen)"


rpi2:
	make os \
		BOARD=rpi2 \
		BUILD_OPTS="$(BUILD_OPTS) --build-arg NEW_SSH_KEYGEN=$(shell uuidgen)"


rpi3:
	make os \
		BOARD=rpi3 \
		BUILD_OPTS="$(BUILD_OPTS) --build-arg NEW_SSH_KEYGEN=$(shell uuidgen)"


shell: binfmt
	$(call check_build)
	docker run --rm -it `cat $(_BUILDED_IMAGE)` /bin/bash


binfmt: _root_runner
	docker run --privileged --rm -it $(_ROOT_RUNNER) install-binfmt $(_QEMU_RUNNER_STATIC_PLACE) $(_QEMU_RUNNER_ARCH)


scan: _root_runner
	@ ./tools/say "===== Searching pies in the local network ====="
	docker run --net=host --rm -it $(_ROOT_RUNNER) arp-scan --localnet | grep b8:27:eb: || true


os: binfmt _buildctx
	@ ./tools/say "===== Building rootfs ====="
	rm -f $(_BUILDED_IMAGE)
	docker build $(BUILD_OPTS) \
			--build-arg "BOARD=$(BOARD)" \
			--build-arg "BASE_ROOTFS_TGZ=`basename $(_RPI_BASE_ROOTFS_TGZ)`" \
			--build-arg "QEMU_RUNNER_ARCH=$(_QEMU_RUNNER_ARCH)" \
			--build-arg "QEMU_RUNNER_STATIC_PLACE=$(_QEMU_RUNNER_STATIC_PLACE)" \
			--build-arg "LOCALE=$(LOCALE)" \
			--build-arg "TIMEZONE=$(TIMEZONE)" \
			--build-arg "REPO_URL=$(REPO_URL)" \
		--rm --tag $(_RPI_RESULT_IMAGE) $(_BUILD_DIR)
	echo $(_RPI_RESULT_IMAGE) > $(_BUILDED_IMAGE)
	$(call show_config)
	@ ./tools/say "===== Build complete ====="


# =====
_root_runner:
	docker build --rm --tag $(_ROOT_RUNNER) tools -f tools/Dockerfile.root


_buildctx: $(_RPI_BASE_ROOTFS_TGZ) $(_QEMU_RUNNER_STATIC)
	@ ./tools/say "===== Assembling Dockerfile ====="
	rm -rf $(_BUILD_DIR)
	mkdir -p $(_BUILD_DIR)
	cp $(_RPI_BASE_ROOTFS_TGZ) $(_BUILD_DIR)
	cp $(_QEMU_RUNNER_STATIC) $(_BUILD_DIR)
	cp -r tools/say tools/die $(_BUILD_DIR)
	cp -r stages $(_BUILD_DIR)
	echo -n > $(_BUILD_DIR)/Dockerfile
	for stage in $(STAGES); do \
		cat $(_BUILD_DIR)/stages/$$stage/Dockerfile.part >> $(_BUILD_DIR)/Dockerfile; \
	done


$(_RPI_BASE_ROOTFS_TGZ):
	mkdir -p $(_TMP_DIR)
	@ ./tools/say "===== Fetching base rootfs ====="
	curl -L -f $(_RPI_ROOTFS_URL) -z $@ -o $@


$(_QEMU_RUNNER_STATIC):
	mkdir -p $(_TMP_DIR)
	@ ./tools/say "===== QEMU magic ====="
	mkdir -p $(_TMP_DIR)/qemu-user-static-deb
	curl -L -f $(_QEMU_USER_STATIC_BASE_URL)/`curl -s -S -L -f $(_QEMU_USER_STATIC_BASE_URL)/ -z $@ \
			| grep qemu-user-static \
			| grep _amd64.deb \
			| sort -n \
			| tail -n 1 \
			| sed -n 's/.*href="\([^"]*\).*/\1/p'` -z $@ \
		-o $(_TMP_DIR)/qemu-user-static-deb/qemu-user-static.deb
	cd $(_TMP_DIR)/qemu-user-static-deb \
	&& ar vx qemu-user-static.deb \
	&& tar -xJf data.tar.xz
	cp $(_TMP_DIR)/qemu-user-static-deb/usr/bin/qemu-$(_QEMU_RUNNER_ARCH)-static $@


# =====
clean:
	rm -rf $(_BUILD_DIR) $(_BUILDED_IMAGE)


__DOCKER_RUN_TMP = docker run \
	-v $(shell pwd)/$(_TMP_DIR):/root/$(_TMP_DIR) \
	-w /root/$(_TMP_DIR)/.. \
	--rm -it $(_ROOT_RUNNER)


__DOCKER_RUN_TMP_PRIVILEGED = docker run \
	-v $(shell pwd)/$(_TMP_DIR):/root/$(_TMP_DIR) \
	-w /root/$(_TMP_DIR)/.. \
	--privileged --rm -it $(_ROOT_RUNNER)


clean-all: _root_runner clean
	$(__DOCKER_RUN_TMP) rm -rf $(_RPI_RESULT_ROOTFS)
	rm -rf $(_TMP_DIR)


format: _root_runner
	$(call check_build)
	@ ./tools/say "===== Formatting $(CARD) ====="
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
	@ ./tools/say "===== Format complete ====="


extract: _root_runner
	$(call check_build)
	@ ./tools/say "===== Extracting image from Docker ====="
	#
	$(__DOCKER_RUN_TMP) rm -rf $(_RPI_RESULT_ROOTFS)
	docker save --output $(_RPI_RESULT_ROOTFS_TAR) `cat $(_BUILDED_IMAGE)`
	$(__DOCKER_RUN_TMP) docker-extract --root $(_RPI_RESULT_ROOTFS) $(_RPI_RESULT_ROOTFS_TAR)
	$(__DOCKER_RUN_TMP) bash -c " \
		echo $(HOSTNAME) > $(_RPI_RESULT_ROOTFS)/etc/hostname \
	"
	@ ./tools/say "===== Extraction complete ====="


install: extract format
	@ ./tools/say "===== Installing to $(CARD) ====="
	$(__DOCKER_RUN_TMP_PRIVILEGED) bash -c " \
		mkdir -p mnt/boot mnt/rootfs \
		&& mount $(_CARD_BOOT) mnt/boot \
		&& mount $(_CARD_ROOT) mnt/rootfs \
		&& rsync -a --info=progress2 $(_RPI_RESULT_ROOTFS)/boot/* mnt/boot \
		&& rsync -a --info=progress2 $(_RPI_RESULT_ROOTFS)/* mnt/rootfs --exclude boot \
		&& mkdir mnt/rootfs/boot \
		&& umount mnt/boot mnt/rootfs \
	"
	@ ./tools/say "===== Installation complete ====="


.NOTPARALLEL: clean-all install
