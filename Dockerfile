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

# Clone the aports repo for our specific branch
# If building from Alpine Edge, we need to use the master branch
RUN git clone --depth 1 --branch master https://gitlab.alpinelinux.org/alpine/aports.git

# Add our custom profile into the abuild scripts directory
COPY mkimg.zz-pinewall_rpi.sh /tmp/abuild/aports/scripts/
COPY genapkovl-pinewall.sh /tmp/abuild/aports/scripts/

# Build our own init into initramfs
COPY init /tmp/custom-init
RUN doas sed -i 's!MKINITFS_ARGS=!MKINITFS_ARGS=" -i /tmp/custom-init"!' /usr/sbin/update-kernel
RUN cat /usr/sbin/update-kernel

# Enter the script directory
WORKDIR /tmp/abuild/aports/scripts

# Create our output dir
RUN mkdir /tmp/images

# Add in all our configs
COPY config/. /tmp/config
COPY secrets.env /tmp/

# Build our image
RUN bash -x ./mkimage.sh \
  --tag edge \
  --outdir /tmp/images \
  --workdir /tmp/cache \
  --repository https://uk.alpinelinux.org/alpine/edge/main \
  --profile pinewall_rpi

# List the contents of our image directory
# (should show our built image if everything worked)
RUN ls -lah /tmp/images

# --------------------------------------------- #

# We don't set an entrypoint in this container as our preferred method for
# retrieving the built image from it is to use `podman create` to create an
# instance of the container, and then `podman cp` to copy /tmp/pinewall.img.gz
# to the host machine.
