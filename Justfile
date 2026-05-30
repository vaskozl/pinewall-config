IMG := "bootable.img"
PODMAN_OPTS := "--rm --privileged --pid=host \
        -it \
        -v /sys/fs/selinux:/sys/fs/selinux:Z \
        -v /etc/containers:/etc/containers \
        -v /var/lib/containers:/var/lib/containers \
        -v /dev:/dev \
        -v $PWD:/data \
        --security-opt label=type:unconfined_t"

build:
    podman build \
        -t ghcr.io/vaskozl/pinewall-config:latest .

run *ARGS:
    podman run {{PODMAN_OPTS}} \
        ghcr.io/vaskozl/pinewall-config:latest {{ARGS}}

bootc *ARGS:
    just run bootc {{ARGS}}

image:
    #!/usr/bin/env bash
    if [ ! -e "./{{IMG}}" ] ; then
        just run fallocate -l 4G /data/{{IMG}}
    fi
    just bootc install to-disk --composefs-backend --via-loopback /data/bootable.img --filesystem ext4 --wipe --bootloader systemd
    just add-rpi-uefi

add-rpi-uefi:
    podman run {{PODMAN_OPTS}} \
    ghcr.io/vaskozl/pinewall-config:latest \
    sh -c 'set -eux; LOOPDEV=$(losetup --find --partscan --show /data/{{IMG}}); echo "Loop device: $LOOPDEV"; mkdir -p /mnt/boot; mount "${LOOPDEV}p1" /mnt/boot; cd /mnt/boot; curl -L -o RPi4_UEFI.zip https://github.com/pftf/RPi4/releases/download/v1.50/RPi4_UEFI_Firmware_v1.50.zip; unzip -o RPi4_UEFI.zip; rm RPi4_UEFI.zip; [ -f "/data/RPI_EFI.fd" ] && cp /data/RPI_EFI.fd /mnt/boot; sync; cd /; umount /mnt/boot; losetup -d "$LOOPDEV";'

vfkit:
    vfkit \
    --cpus 2 --memory 2048 \
    --bootloader efi,variable-store=efi-variable-store,create \
    --device virtio-blk,path={{IMG}} \
    --device virtio-serial,stdio \
    --device virtio-net,nat

sync:
    #!/usr/bin/env bash
    set -euo pipefail

    host="${1:-pinewall}"

    # walk files safely (handles spaces/newlines) and copy each file from remote host
    # skipping the specific problematic file
    find vendor -type f -print0 | while IFS= read -r -d '' f; do
    if [ "$f" = "vendor/etc/systemd/network/30-wireguard.netdev" ]; then
        continue
    fi

    # strip leading "vendor/" for remote path
    remote_path="/${f#vendor/}"

    # make sure local directory exists before copying
    mkdir -p "$(dirname "./$f")"

    echo "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r ${host}:${remote_path} ./${f}"
    scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r "${host}:${remote_path}" "./${f}" || true
    done
