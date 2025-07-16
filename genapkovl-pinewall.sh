#!/usr/bin/doas sh
set -xeu

cleanup() {
  rm -rf "$tmp"
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
envsubst < /tmp/config/etc/systemd/network/30-wireguard.netdev > "$tmp"/etc/systemd/network/30-wireguard.netdev

# Wrap up our custom /etc and /home into an APK overlay file
tar -c -C "$tmp" etc home var | gzip -9n > pinewall.apkovl.tar.gz
