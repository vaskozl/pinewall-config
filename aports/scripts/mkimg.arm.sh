build_rpi_blobs() {
	for i in raspberrypi-bootloader-common raspberrypi-bootloader; do
		apk fetch --root "$APKROOT" --quiet --stdout "$i" | tar -C "${DESTDIR}" -zx --strip=1 boot/ || return 1
	done
}

rpi_gen_cmdline() {
	echo "modules=loop,squashfs,sd-mod,usb-storage ${kernel_cmdline}"
}

rpi_gen_config() {
	local arm_64bit=0
	case "$ARCH" in
		aarch64) arm_64bit=1;;
	esac
	cat <<-EOF
		# do not modify this file as it will be overwritten on upgrade.
		# create and/or modify usercfg.txt instead.
		# https://www.raspberrypi.com/documentation/computers/config_txt.html

		kernel=boot/vmlinuz-rpi
		initramfs boot/initramfs-rpi
		arm_64bit=$arm_64bit
		include usercfg.txt
	EOF
}

build_rpi_config() {
	rpi_gen_cmdline > "${DESTDIR}"/cmdline.txt
	rpi_gen_config > "${DESTDIR}"/config.txt
}

section_rpi_config() {
	[ "$hostname" = "rpi" ] || return 0
	build_section rpi_config $( (rpi_gen_cmdline ; rpi_gen_config) | checksum )
	build_section rpi_blobs
}

profile_rpi() {
	profile_base
	title="Raspberry Pi"
	desc="First generation Pis including Zero/W (armhf).
		Pi 2 to Pi 3+ generations (armv7).
		Pi 3 to Pi 5 generations (aarch64)."
	image_ext="tar.gz"
	arch="aarch64 armhf armv7"
	kernel_flavors="rpi"
	kernel_cmdline="console=tty1 net.ifnames=0"
	initfs_features="base squashfs mmc usb kms dhcp https"
	hostname="rpi"
	grub_mod=
}

create_image_imggz() {
	sync "$DESTDIR"
	local image_size=$(du -L -k -s "$DESTDIR" | awk '{print $1 + 8192}' )
	local imgfile="${OUTDIR}/${output_filename%.gz}"
	dd if=/dev/zero of="$imgfile" bs=1M count=$(( image_size / 1024 ))
	mformat -i "$imgfile" -N 0 ::
	mcopy -s -i "$imgfile" "$DESTDIR"/* "$DESTDIR"/.alpine-release ::
	echo "Compressing $imgfile..."
	pigz -v -f -9 "$imgfile" || gzip -f -9 "$imgfile"
}

create_image_imggz_new() {
    sync "$DESTDIR"

    # Calculate the size of the boot partition dynamically
	local boot_size=$(du -L -k -s "$DESTDIR" | awk '{print int($1 / 1024 + 0.5) + 8}')
    local image_size=$((boot_size + ext4_size))  # Total size with some buffer

    local imgfile="${OUTDIR}/${output_filename%.gz}"

    # Create a raw image file
    dd if=/dev/zero of="$imgfile" bs=1M count=$image_size

	# Create partitions
	parted --script "$imgfile" \
		mklabel msdos \
		mkpart primary fat32 1MiB ${boot_size}MiB \
		set 1 boot on \
		set 1 lba on

	# Format the partitions
	# Calculate offsets for mkfs
	boot_offset=$((1 * 2048))  # 1MiB offset

	# Format the boot partition
	mkfs.vfat -F 32 -n BOOT "$imgfile" --offset $boot_offset

	# Copy files to the boot partition
	mcopy -s -i "$imgfile@@1M" "$DESTDIR"/* "$DESTDIR"/.alpine-release ::

    # Compress the image
    echo "Compressing $imgfile..."
    pigz -v -f -9 "$imgfile" || gzip -f -9 "$imgfile"
}

profile_rpiimg() {
	profile_rpi
	title="Raspberry Pi Disk Image"
	image_name="alpine-rpi"
	image_ext="img.gz"
}

