#!/bin/sh
set -e


# =====
[ -n "$SITE_FS" ] || die "Empty \$SITE_FS"
[ -n "$FS" ] || die "Empty \$FS"
[ -n "$QEMU_ARM_STATIC" ] || die "Empty \$QEMU_ARM_STATIC"


# =====
install_binfmt_arm() {
	local binfmt_dir="/proc/sys/fs/binfmt_misc"
	local binfmt_arm="$binfmt_dir/arm"

	say " >>> Configuring ARM-binfmt..."
	mount binfmt_misc -t binfmt_misc "$binfmt_dir"
	if [ -e "$binfmt_arm" ]; then
		local real_qemu_arm_static=`grep interpreter "$binfmt_arm" | awk '{print $2}'`
		if [ "$QEMU_ARM_STATIC" != "$real_qemu_arm_static" ]; then
			die -e " ARM-binfmt is enabled but path is inconsistent\n"\
				"  > $binfmt_arm: $real_qemu_arm_static\n"\
				"  > expected: $QEMU_ARM_STATIC\n"\
				" Run \"echo -1 > $binfmt_arm\" to disable ARM globally (include host system)"
		else
			say " >>> ARM-binfmt is OK"
		fi
	else
		say -e " >>> Enabling ARM-binfmt..."
		echo ":arm:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:$QEMU_ARM_STATIC:" > "$binfmt_dir/register"
	fi
}

make_fs() {
	say " >>> Syncing $SITE_FS --> $FS"
	rm -rf "$FS"/*
	rsync -a --info=progress2 "$SITE_FS"/* "$FS"
}

patch_resolv_conf() {
	mv "$FS/etc/resolv.conf" "$FS/etc/resolv.conf.bak"
	cat /etc/resolv.conf > "$FS/etc/resolv.conf"
}

unpatch_resolv_conf() {
	rm "$FS/etc/resolv.conf"
	mv "$FS/etc/resolv.conf.bak" "$FS/etc/resolv.conf"
}


# =====
install_binfmt_arm
make_fs
patch_resolv_conf
say " >>> Running build-scripts..."
for item in $@; do
	say " ~~~ $item stage"
	pushd "/root/scripts/$item"
	./run.sh
	popd
done
unpatch_resolv_conf
say " >>> Build complete"
