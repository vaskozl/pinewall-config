FROM docker.io/library/alpine:edge AS builder

# Run an APK update so we have a recent cache ready in the Docker image
# (if we don't do this then the "apk fetch" stages of the build that fetch
# packages like the Raspberry Pi bootloader will fail).
RUN apk update

# Install build deps
RUN apk add \
  alpine-conf \
  alpine-sdk \
  apk-tools \
  build-base \
  busybox \
  dosfstools \
  fakeroot \
  grub-efi \
  mtools \
  squashfs-tools \
  tzdata \
  xorriso \
  envsubst \
  bash \
  parted \
  e2fsprogs \
  e2fsprogs-extra \
  doas

RUN wget -O /etc/apk/keys/wolfi-signing.rsa.pub https://packages.wolfi.dev/os/wolfi-signing.rsa.pub

# Add unprivileged builder user and change ownership of build directory
# so we can launch the mkimage process unprivileged
RUN adduser builder --disabled-password
RUN addgroup builder abuild
RUN echo 'permit nopass :abuild' > /etc/doas.conf

# Become builder user and generate our build key
# Most examples pass the -i flag to abuild-keygen, but that just installs
# our generated keys into /etc/apk/keys. We don't need to do that since we're
# not actually going to be installing any packages we've built inside this container
# (or even building any packages in the first place really, I think this is just a pre-req
# to running abuild-based processes).
USER builder

RUN abuild-keygen -a -n

# Create build directory
RUN mkdir /tmp/abuild
WORKDIR /tmp/abuild

COPY aports /tmp/abuild/aports

# Add our custom profile into the abuild scripts directory
COPY mkimg.pinewall_rpi.sh /tmp/abuild/aports/scripts/
COPY update-kernel /usr/sbin/update-kernel
COPY init /tmp/custom-init

# Enter the script directory
WORKDIR /tmp/abuild/aports/scripts

# Create our output dir
RUN mkdir /tmp/images

# Add in all our configs
RUN mkdir -p /tmp/config/etc/apk
COPY config/etc/apk/world /tmp/config/etc/apk/world
COPY secrets.env /tmp/

# Build our image
RUN bash -x ./mkimage.sh \
  --tag edge \
  --outdir /tmp/images \
  --workdir /tmp/cache \
  --repository https://uk.alpinelinux.org/alpine/edge/main \
  --repository https://uk.alpinelinux.org/alpine/edge/community \
  --repository https://packages.wolfi.dev/os \
  --profile pinewall_rpi && \
  mkdir -p /tmp/pinewall && \
  doas tar xvf /tmp/images/alpine-*tar.gz --no-same-owner -C /tmp/pinewall && \
  rm /tmp/images/alpine-*.tar.gz && rm -rf /tmp/cache

USER root

COPY config/. /tmp/config

COPY genapkovl-pinewall.sh /tmp/abuild/aports/scripts/
RUN cd /tmp/pinewall && \
  sh -x /tmp/abuild/aports/scripts/genapkovl-pinewall.sh

RUN	export DESTDIR=/tmp/pinewall && \
    export OUTDIR=/tmp/images && \
    output_filename="mmcblk0-$(cat /tmp/config/etc/hostname).img.gz" && \
    sync "$DESTDIR" && \
    boot_size=$(du -L -m -s "$DESTDIR" | awk '{print $1 + 8}' ) && \
    ext4_size=100 && \
    imgfile="${OUTDIR}/${output_filename%.gz}" && \
    dd if=/dev/zero of="$imgfile" bs=1M count=$(( $boot_size + $ext4_size )) && \
    parted "$imgfile" --script -- \
      mklabel msdos \
      mkpart primary fat32 1MiB ${boot_size}MiB \
      set 1 boot on \
      set 1 lba on \
      mkpart primary ext4 ${boot_size}MiB 100% && \
    mkfs.fat -F 32 -s 4 -n WOLFI "$imgfile" --offset 2048 && \
    dd if=/dev/zero of="${imgfile}.ext4" bs=1M count=$(( $ext4_size )) && \
    mkfs.ext4 "$imgfile.ext4" && \
    tune2fs -c0 -i0 "$imgfile.ext4" && \
    mcopy -s -i "$imgfile@@1M" "$DESTDIR"/* "$DESTDIR"/.alpine-release :: && \
    dd if="${imgfile}.ext4" of="$imgfile" bs=1M seek="$boot_size" conv=notrunc && \
    rm "${imgfile}.ext4" && \
    echo "Compressing $imgfile..." && \
    parted "$imgfile" unit mib print && \
    echo "boot_size=$boot_size ext4_size=$ext4_size" && \
    gzip -f -9 "$imgfile"

# List the contents of our image directory
# (should show our built image if everything worked)
RUN ls -lah /tmp/images

# --------------------------------------------- #

# We don't set an entrypoint in this container as our preferred method for
# retrieving the built image from it is to use `podman create` to create an
# instance of the container, and then `podman cp` to copy /tmp/pinewall.img.gz
# to the host machine.
