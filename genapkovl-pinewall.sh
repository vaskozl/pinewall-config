#!/usr/bin/doas sh
set -xeu

cleanup() {
  rm -rf "$tmp"
}

rc_add() {
  mkdir -p "$tmp"/etc/runlevels/"$2"
  ln -sf /etc/init.d/"$1" "$tmp"/etc/runlevels/"$2"/"$1"
}

tmp="$(mktemp -d)"
trap cleanup EXIT

cp -rp /tmp/config/. "$tmp"/
chown -R root:root "$tmp"
chown -R 5000:500 "$tmp"/home


# Seed our custom users based on the user config files
# in the running container
cp /etc/group "$tmp"/etc/
cp /etc/passwd "$tmp"/etc/
cp /etc/shadow "$tmp"/etc/

# Add a new iperf user and group without a password
echo "iperf:x:520:" >> "$tmp"/etc/group
echo "iperf:x:520:520:iperf user:/home/iperf:/sbin/nologin" >> "$tmp"/etc/passwd
echo "iperf:!::0:::::" >> "$tmp"/etc/shadow

# Add a pinewall user with default password of "pinewall"
echo "pinewall:x:5000:" >> "$tmp"/etc/group
echo "pinewall:x:5000:5000:Pinewall MGMT user:/home/pinewall:/bin/ash" >> "$tmp"/etc/passwd

. /tmp/secrets.env
echo "$SHADOW_USER" >> "$tmp"/etc/shadow
envsubst < /tmp/config/etc/wireguard/wg0.conf > "$tmp"/etc/wireguard/wg0.conf

# Except where commented, these runlevels come from the defaults that can
# be found after a basic Alpine Standard install to HDD with the defaults.

rc_add bootmisc boot
rc_add hostname boot
#rc_add hwclock boot      # Pi does not have a hardware clock
rc_add swclock boot       # Need to enable software clock for the Pi instead
#rc_add loadkmap boot     # Might not be needed unless we specify a keymap
rc_add modules boot
rc_add networking boot
rc_add nftables boot      # Moved into boot runlevel so that the firewall comes up ASAP
rc_add rngd boot          # Add rng service for Pi type devices without much entropy available
#rc_add swap boot         # Won't work unless we have swap which we won't if we're running live
rc_add sysctl boot
rc_add syslog boot
rc_add urandom boot

# Most of our services want to go here in the default runlevel
#rc_add acpid default
rc_add avahi-daemon default
rc_add bird default  # BGP
rc_add ntpd default
rc_add crond default  # Previously disabled but I've re-enabled it since logrotate requires it
rc_add sshd default
rc_add iperf3 default
rc_add irqbalance default
rc_add ulogd default
rc_add dnsmasq default
rc_add node-exporter default

rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

rc_add devfs sysinit
rc_add dmesg sysinit
rc_add hwdrivers sysinit
rc_add mdev sysinit
# modloop isn't present for the sysinit runlevel on an installed
# system, but experimentation and documentation online suggests this
# is needed for the live system
rc_add modloop sysinit

# Wrap up our custom /etc and /home into an APK overlay file
tar -c -C "$tmp" etc home | gzip -9n > pinewall.apkovl.tar.gz
