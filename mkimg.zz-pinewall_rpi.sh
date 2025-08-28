profile_pinewall_rpi() {
  # Source the env vars from the "rpi" profile below (see mkimg.arm.sh)
  profile_rpiimg
  #profile_virt
  apkovl="genapkovl-pinewall.sh"

  # Force aarch64
  arch="aarch64"

  # We don't want the kernel addons from the Standard profile, which includes
  # xtables-addons. We don't want any *tables stuff since we're fully nftables.
  kernel_addons=""
  kernel_cmdline="console=tty1 net.ifnames=0 cgroup_enable=memory genet.eee=N"

  apks=$(cat /tmp/config/etc/apk/world)
}

# Override build_apks to use the wolfi repos
build_apks() {
    local _apksdir="$DESTDIR/apks"
    local _archdir="$_apksdir/$ARCH"
    mkdir -p "$_archdir"

    wget -O "$APKROOT"/etc/apk/keys/wolfi-signing.rsa.pub https://packages.wolfi.dev/os/wolfi-signing.rsa.pub
    wget -O "$APKROOT"/etc/apk/keys/melange.rsa.pub https://apks.sko.ai/melange.rsa.pub
    echo "https://packages.wolfi.dev/os" > "$APKROOT"/etc/apk/repositories
    echo "https://apks.sko.ai" >> "$APKROOT"/etc/apk/repositories

    apk update --root "$APKROOT" update
    apk fetch --root "$APKROOT" --link --recursive --output "$_archdir" $apks
    if ! ls "$_archdir"/*.apk >& /dev/null; then
        return 1
    fi

    apk index \
        --allow-untrusted \
        --root "$APKROOT" \
        --description "$RELEASE" \
        --rewrite-arch "$ARCH" \
        --index "$_archdir"/APKINDEX.tar.gz \
        --output "$_archdir"/APKINDEX.tar.gz \
        "$_archdir"/*.apk
    abuild-sign "$_archdir"/APKINDEX.tar.gz
    touch "$_apksdir/.boot_repository"

    echo "https://uk.alpinelinux.org/alpine/edge/main" > "$APKROOT"/etc/apk/repositories
}
