CARD=/dev/mmcblk0
CARD_BOOT=$(CARD)p1
CARD_ROOT=$(CARD)p2

PLATFORM=rpi
BUILDER=rpi-builder
STAGES=base


# =====
all:
	@ echo "Available commands:"
	@ echo "    make           # Print this help"
	@ echo "    make rpi|rpi2  # Build Arch-ARM rootfs"
	@ echo "    make clean     # Remove the generated rootfs"
	@ echo "    make format    # Format $(CARD) to $(CARD_BOOT) (vfat), $(CARD_ROOT) (ext4)"
	@ echo "    make install   # Install rootfs to partitions on $(CARD)"
	@ echo "    make scan      # Find all RPi devices in the local network"

rpi:
	make _rpi \
		PLATFORM=rpi \
		BUILDER=rpi-builder \
		STAGES="base keys watchdog ro"

rpi2:
	make _rpi \
		PLATFORM=rpi-2 \
		BUILDER=rpi2-builder \
		STAGES="base keys watchdog ro"

_rpi:
	sed -e "s|%%PLATFORM%%|$(PLATFORM)|g" builder/Dockerfile.in > builder/Dockerfile
	docker build $(RPI_OPTS) --rm --tag $(BUILDER) builder
	make rootfs/.`docker images -q $(BUILDER)`

#_rpi-no-cache:
#	make rpi RPI_OPTS=--no-cache

rootfs/.$(shell docker images -q $(BUILDER)):
	make clean
	@ echo "===== Building rootfs ====="
	mkdir -p rootfs
	docker run -v `pwd`/rootfs:/root/fs --privileged --rm -it $(BUILDER) build-rpi $(STAGES)
	docker run -v `pwd`/rootfs:/root/fs --rm -it $(BUILDER) \
		bash -c "echo > /root/fs/.`docker images -q $(BUILDER)`"
	@ echo "===== DONE ====="

clean:
	rm -f builder/Dockerfile
	docker run -v `pwd`/rootfs:/root/fs --rm -it mdevaev/archlinux \
		bash -c "rm -rf /root/fs/* /root/fs/.[!.]*"
	rm -rf rootfs

format:
	@ test `whoami` == root || (echo "Run as root"; exit 1)
	@ echo "===== Formatting $(CARD) ====="
	echo -e "o\nn\np\n1\n\n+128M\nt\nc\nn\np\n2\n\n\nw\n" | fdisk $(CARD) || true
	partprobe $(CARD)
	mkfs.vfat $(CARD_BOOT)
	yes | mkfs.ext4 $(CARD_ROOT)

install: format
	@ test `whoami` == root || (echo "Run as root"; exit 1)
	@ echo "===== Installing to $(CARD) ====="
	mkdir mnt mnt/boot mnt/root
	#
	mount $(CARD_BOOT) mnt/boot
	mount $(CARD_ROOT) mnt/root
	rsync -a --info=progress2 rootfs/boot/* mnt/boot
	rsync -a --info=progress2 rootfs/* mnt/root --exclude boot
	mkdir mnt/root/boot
	#
	umount mnt/boot mnt/root
	rmdir mnt/boot mnt/root mnt

scan:
	@ test `whoami` == root || (echo "Run as root"; exit 1)
	arp-scan --localnet | grep b8:27:eb:
