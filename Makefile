CARD ?= /dev/mmcblk0
CARD_BOOT ?= $(CARD)p1
CARD_ROOT ?= $(CARD)p2

PLATFORM ?= rpi
STAGES ?= __init__

PROJECT ?= common
BUILD_OPTS ?=
QEMU_ARM_STATIC_PLACE ?= /usr/bin/qemu-arm-static
HOSTNAME ?= pi
LOCALE ?= en_US.UTF-8
TIMEZONE ?= Europe/Moscow
REPO_URL ?= http://mirror.yandex.ru/archlinux-arm


# =====
_TMP_DIR = ./.tmp
_BUILD_DIR = ./.build
_BUILDED_IMAGE = ./.builded_image

_QEMU_USER_STATIC_BASE_URL = http://mirror.yandex.ru/debian/pool/main/q/qemu
_QEMU_ARM_STATIC = $(_TMP_DIR)/qemu-arm-static

_IMAGES_PREFIX = pi-builder

_ROOT_RUNNER = $(_IMAGES_PREFIX)-root-runner

_RPI_BASE_ROOTFS_TGZ = $(_TMP_DIR)/base-rootfs.tar.gz
_RPI_BASE_IMAGE = $(_IMAGES_PREFIX)-base-$(PLATFORM)
_RPI_RESULT_IMAGE = $(PROJECT)-$(_IMAGES_PREFIX)-result-$(PLATFORM)
_RPI_RESULT_ROOTFS_TAR = $(_TMP_DIR)/result-rootfs.tar
_RPI_RESULT_ROOTFS = $(_TMP_DIR)/result-rootfs


# =====
all:
	@ echo "Available commands:"
	@ echo "    make           # Print this help"
	@ echo "    make rpi|rpi2  # Build Arch-ARM rootfs"
	@ echo "    make shell     # Run Arch-ARM shell"
	@ echo "    make binfmt    # Before build"
	@ echo "    make scan      # Find all RPi devices in the local network"
	@ echo "    make clean     # Remove the generated rootfs"
	@ echo "    make format    # Format $(CARD) to $(CARD_BOOT) (vfat), $(CARD_ROOT) (ext4)"
	@ echo "    make install   # Install rootfs to partitions on $(CARD)"


rpi: binfmt
	make _rpi \
		PLATFORM=rpi \
		BUILD_OPTS="--build-arg NEW_SSH_KEYGEN=$(shell uuidgen)" \
		STAGES="__init__ os watchdog ro rootssh __cleanup__"


rpi2: binfmt
	make _rpi \
		PLATFORM=rpi-2 \
		BUILD_OPTS="--build-arg NEW_SSH_KEYGEN=$(shell uuidgen)" \
		STAGES="__init__ os watchdog ro rootssh __cleanup__"


shell: binfmt
	@ test -e $(_BUILDED_IMAGE) || ./tools/die "===== Not builded yet ====="
	docker run --rm -it `cat $(_BUILDED_IMAGE)` /bin/bash


binfmt: _root_runner
	docker run --privileged --rm -it $(_ROOT_RUNNER) install-binfmt $(QEMU_ARM_STATIC_PLACE)


scan: _root_runner
	@ ./tools/say "===== Searching pies in the local network ====="
	docker run --net=host --rm -it $(_ROOT_RUNNER) arp-scan --localnet | grep b8:27:eb: || true


# =====
_root_runner:
	docker build --rm --tag $(_ROOT_RUNNER) tools -f tools/Dockerfile.root


_rpi: _buildctx
	@ ./tools/say "===== Building rootfs ====="
	rm -f $(_BUILDED_IMAGE)
	docker build $(BUILD_OPTS) \
			--build-arg "QEMU_ARM_STATIC_PLACE=$(QEMU_ARM_STATIC_PLACE)" \
			--build-arg "LOCALE=$(LOCALE)" \
			--build-arg "TIMEZONE=$(TIMEZONE)" \
			--build-arg "REPO_URL=$(REPO_URL)" \
		--rm --tag $(_RPI_RESULT_IMAGE) $(_BUILD_DIR)
	echo $(_RPI_RESULT_IMAGE) > $(_BUILDED_IMAGE)
	@ ./tools/say "===== Build complete ====="


_buildctx: $(_RPI_BASE_ROOTFS_TGZ) $(_QEMU_ARM_STATIC)
	@ ./tools/say "===== Assembling Dockerfile ====="
	rm -rf $(_BUILD_DIR)
	mkdir -p $(_BUILD_DIR)
	cp $(_RPI_BASE_ROOTFS_TGZ) $(_BUILD_DIR)
	cp $(_QEMU_ARM_STATIC) $(_BUILD_DIR)
	cp -r tools/{say,die} $(_BUILD_DIR)
	cp -r stages $(_BUILD_DIR)
	echo -n > $(_BUILD_DIR)/Dockerfile
	for stage in $(STAGES); do \
		cat $(_BUILD_DIR)/stages/$$stage/Dockerfile.part >> $(_BUILD_DIR)/Dockerfile; \
	done


$(_RPI_BASE_ROOTFS_TGZ):
	mkdir -p $(_TMP_DIR)
	@ ./tools/say "===== Fetching base rootfs ====="
	curl -L -f $(REPO_URL)/os/ArchLinuxARM-$(PLATFORM)-latest.tar.gz -z $@ -o $@


$(_QEMU_ARM_STATIC):
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
	cp $(_TMP_DIR)/qemu-user-static-deb/usr/bin/qemu-arm-static $@


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
	@ test -e $(_BUILDED_IMAGE) || ./tools/die "===== Not builded yet ====="
	@ ./tools/say "===== Formatting $(CARD) ====="
	$(__DOCKER_RUN_TMP_PRIVILEGED) bash -c " \
		(echo -e "o\nn\np\n1\n\n+128M\nt\nc\nn\np\n2\n\n\nw\n" | fdisk $(CARD) || true) \
		&& partprobe $(CARD) \
		&& mkfs.vfat $(CARD_BOOT) \
		&& yes | mkfs.ext4 $(CARD_ROOT) \
	"
	@ ./tools/say "===== Format complete ====="


extract: _root_runner
	@ test -e $(_BUILDED_IMAGE) || ./tools/die "===== Not builded yet ====="
	@ ./tools/say "===== Extracting image from Docker ====="
	#
	$(__DOCKER_RUN_TMP) rm -rf $(_RPI_RESULT_ROOTFS)
	docker save --output $(_RPI_RESULT_ROOTFS_TAR) `cat $(_BUILDED_IMAGE)`
	$(__DOCKER_RUN_TMP) docker-extract --root $(_RPI_RESULT_ROOTFS) $(_RPI_RESULT_ROOTFS_TAR)
	$(__DOCKER_RUN_TMP) bash -c " \
		echo $(HOSTNAME) > $(_RPI_RESULT_ROOTFS)/etc/hostname \
		&& mv $(_RPI_RESULT_ROOTFS)/$(QEMU_ARM_STATIC_PLACE) $(_RPI_RESULT_ROOTFS)/usr/local/bin \
		&& ln -sf $(QEMU_ARM_STATIC_PLACE) $(_RPI_RESULT_ROOTFS)/usr/local/bin/qemu-arm-static \
	"
	@ ./tools/say "===== Extraction complete ====="


install: extract format
	@ ./tools/say "===== Installing to $(CARD) ====="
	$(__DOCKER_RUN_TMP_PRIVILEGED) bash -c " \
		mkdir -p mnt/boot mnt/rootfs \
		&& mount $(CARD_BOOT) mnt/boot \
		&& mount $(CARD_ROOT) mnt/rootfs \
		&& rsync -a --info=progress2 $(_RPI_RESULT_ROOTFS)/boot/* mnt/boot \
		&& rsync -a --info=progress2 $(_RPI_RESULT_ROOTFS)/* mnt/rootfs --exclude boot \
		&& mkdir mnt/rootfs/boot \
		&& umount mnt/boot mnt/rootfs \
	"
	@ ./tools/say "===== Installation complete ====="
