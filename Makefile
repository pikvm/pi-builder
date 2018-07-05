CARD=/dev/mmcblk0
CARD_BOOT=$(CARD)p1
CARD_ROOT=$(CARD)p2

PLATFORM=rpi
STAGES=base

QEMU_ARM_STATIC_PLACE=/usr/bin/qemu-arm-static
HOSTNAME=pi
LOCALE=en_US.UTF-8
TIMEZONE=Europe/Moscow
REPO_URL=http://mirror.yandex.ru/archlinux-arm


# =====
all:
	@ echo "Available commands:"
	@ echo "    make           # Print this help"
	@ echo "    make binfmt    # Before build"
	@ echo "    make rpi|rpi2  # Build Arch-ARM rootfs"
	@ echo "    make clean     # Remove the generated rootfs"
	@ echo "    make format    # Format $(CARD) to $(CARD_BOOT) (vfat), $(CARD_ROOT) (ext4)"
	@ echo "    make install   # Install rootfs to partitions on $(CARD)"
	@ echo "    make scan      # Find all RPi devices in the local network"


binfmt:
	./tools/install-binfmt $(QEMU_ARM_STATIC_PLACE)


rpi:
	make _rpi \
		PLATFORM=rpi \
		STAGES="base os ssh watchdog ro"


rpi2:
	make _rpi \
		PLATFORM=rpi-2 \
		STAGES="base os ssh watchdog ro"


shell:
	@ test -e $(_BUILDED_IMAGE) || ./tools/die "===== Not builded yet ====="
	docker run --rm -it `cat $(_BUILDED_IMAGE)` /bin/bash


# =====
_TMP_DIR=./.tmp
_BUILD_DIR=./.build
_MNT_DIR=./.mnt
_BUILDED_IMAGE=./.builded_image

_RPI_BASE_ROOTFS_URL=http://mirror.yandex.ru/archlinux-arm/os
_RPI_BASE_ROOTFS_TGZ=$(_TMP_DIR)/base-rootfs.tar.gz

_QEMU_USER_STATIC_BASE_URL=http://mirror.yandex.ru/debian/pool/main/q/qemu
_QEMU_ARM_STATIC=$(_TMP_DIR)/qemu-arm-static

_RPI_BASE_IMAGE=pi-base-$(PLATFORM)
_RPI_RESULT_IMAGE=pi-result-$(PLATFORM)
_RPI_RESULT_ROOTFS_TAR=$(_TMP_DIR)/result-rootfs.tar
_RPI_RESULT_ROOTFS=$(_TMP_DIR)/result-rootfs


_rpi: _buildctx
	@ ./tools/say "===== Building rootfs ====="
	rm -f $(_BUILDED_IMAGE)
	docker build $(RPI_OPTS) \
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


$(_RPI_BASE_ROOTFS_TGZ): $(_TMP_DIR)
	@ ./tools/say "===== Fetching base rootfs ====="
	curl -L -f $(_RPI_BASE_ROOTFS_URL)/ArchLinuxARM-$(PLATFORM)-latest.tar.gz -z $@ -o $@


$(_QEMU_ARM_STATIC): $(_TMP_DIR)
	@ ./tools/say "===== QEMU magic ====="
	rm -rf $(_TMP_DIR)/qemu-user-static-deb
	mkdir -p $(_TMP_DIR)/qemu-user-static-deb
	curl -L -f $(_QEMU_USER_STATIC_BASE_URL)/`curl -s -S -L -f $(_QEMU_USER_STATIC_BASE_URL)/ -z $@ \
			| grep qemu-user-static \
			| grep _amd64.deb \
			| sort -n \
			| tail -n 1 \
			| sed -n 's/.*href="\([^"]*\).*/\1/p'` -z $@ \
		-o $(_TMP_DIR)/qemu-user-static-deb/qemu-user-static.deb
	- cd $(_TMP_DIR)/qemu-user-static-deb \
	&& ar vx qemu-user-static.deb \
	&& tar -xJf data.tar.xz
	cp $(_TMP_DIR)/qemu-user-static-deb/usr/bin/qemu-arm-static $@


$(_TMP_DIR):
	mkdir -p $(_TMP_DIR)


clean:
	rm -rf $(_BUILD_DIR) $(_BUILDED_IMAGE)


clean-all: clean
	@ test `whoami` == root || ./tools/die "===== Run as root plz ====="
	rm -rf $(_TMP_DIR)


format:
	@ test `whoami` == root || ./tools/die "===== Run as root plz ====="
	@ test -e $(_BUILDED_IMAGE) || ./tools/die "===== Not builded yet ====="
	@ ./tools/say "===== Formatting $(CARD) ====="
	#
	echo -e "o\nn\np\n1\n\n+128M\nt\nc\nn\np\n2\n\n\nw\n" | fdisk $(CARD) || true
	partprobe $(CARD)
	mkfs.vfat $(CARD_BOOT)
	yes | mkfs.ext4 $(CARD_ROOT)
	@ ./tools/say "===== Format complete ====="


extract:
	@ test `whoami` == root || ./tools/die "===== Run as root plz ====="
	@ test -e $(_BUILDED_IMAGE) || ./tools/die "===== Not builded yet ====="
	@ ./tools/say "===== Extracting image from Docker ====="
	#
	rm -rf $(_RPI_RESULT_ROOTFS)
	docker save --output $(_RPI_RESULT_ROOTFS_TAR) `cat $(_BUILDED_IMAGE)`
	./tools/docker-extract --debug --root $(_RPI_RESULT_ROOTFS) $(_RPI_RESULT_ROOTFS_TAR)
	echo $(HOSTNAME) > $(_RPI_RESULT_ROOTFS)/etc/hostname
	@ ./tools/say "===== Extraction complete ====="


install: extract format
	@ test `whoami` == root || ./tools/die "===== Run as root plz ====="
	#
	@ ./tools/say "===== Installing to $(CARD) ====="
	mkdir $(_MNT_DIR) $(_MNT_DIR)/boot $(_MNT_DIR)/rootfs
	#
	mount $(CARD_BOOT) $(_MNT_DIR)/boot
	mount $(CARD_ROOT) $(_MNT_DIR)/rootfs
	rsync -a --info=progress2 $(_RPI_RESULT_ROOTFS)/boot/* $(_MNT_DIR)/boot
	rsync -a --info=progress2 $(_RPI_RESULT_ROOTFS)/* $(_MNT_DIR)/rootfs --exclude boot
	mkdir $(_MNT_DIR)/rootfs/boot
	#
	umount $(_MNT_DIR)/boot $(_MNT_DIR)/rootfs
	rmdir $(_MNT_DIR)/boot $(_MNT_DIR)/rootfs $(_MNT_DIR)
	#
	@ ./tools/say "===== Installation complete ====="


scan:
	@ test `whoami` == root || ./tools/die "===== Run as root plz ====="
	arp-scan --localnet | grep b8:27:eb: || true
