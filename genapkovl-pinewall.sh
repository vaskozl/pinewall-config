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


for user in iperf avahi bird dnsmasq blocky;do
  addgroup -S $user 2>/dev/null
  adduser -S -D -H -h /dev/null -s /sbin/nologin -G $user -g $user $user 2>/dev/null
done

# Seed our custom users based on the user config files
# in the running container
cp /etc/group "$tmp"/etc/
cp /etc/passwd "$tmp"/etc/
cp /etc/shadow "$tmp"/etc/

# Add a pinewall user with default password of "pinewall"
echo "pinewall:x:5000:" >> "$tmp"/etc/group
echo "pinewall:x:5000:5000:Pinewall MGMT user:/home/pinewall:/bin/ash" >> "$tmp"/etc/passwd

. /tmp/secrets.env
echo "$SHADOW_USER" >> "$tmp"/etc/shadow

# Wrap up our custom /etc and /home into an APK overlay file
tar -c -C "$tmp" etc home var | gzip -9n > pinewall.apkovl.tar.gz
