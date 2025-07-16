profile_pinewall_rpi() {
  # Source the env vars from the "rpi" profile below (see mkimg.arm.sh)
  #profile_rpiimg
  profile_virt
  apkovl="genapkovl-pinewall.sh"

  # Force aarch64
  arch="aarch64"

  # We don't want the kernel addons from the Standard profile, which includes
  # xtables-addons. We don't want any *tables stuff since we're fully nftables.
  kernel_addons=""

  apks=$(cat /tmp/config/etc/apk/world)
}
