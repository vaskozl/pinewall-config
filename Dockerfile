# syntax=docker/dockerfile:1.4
FROM ghcr.io/vaskozl/router:latest

# Necessary for general behavior expected by image-based systems
RUN <<EOF
    rm -rf /boot /home /root /usr/local /srv
    mkdir -p /var /sysroot /boot /usr/lib/ostree /etc/default
    echo "HOME=/var/home" | tee -a "/etc/default/useradd"
    ln -s var/opt /opt
    ln -s var/roothome /root
    ln -s var/home /home
    ln -s sysroot/ostree /ostree
EOF

COPY config/. /

RUN --mount=type=secret,id=env <<EOF
    for user in iperf avahi bird dnsmasq blocky; do
        addgroup -S $user 2>/dev/null
        adduser -S -D -H -h /dev/null -s /sbin/nologin -G $user -g $user $user 2>/dev/null
    done

    # Add a pinewall user with default password of "pinewall"
    echo "pinewall:x:5000:" >> /etc/group
    echo "pinewall:x:5000:5000:Pinewall MGMT user:/home/pinewall:/bin/bash" >> /etc/passwd

    . /run/secrets/env
    echo "$SHADOW_USER" >> "$tmp"/etc/shadow
EOF
