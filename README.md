# pinewall-config

**Immutable Wolfi Bootc Home Router Declared in Git**

> Inspired by [Alex Haydock's original Alpine project](https://github.com/alexhaydock/pinewall)

An immutable, declarative home router configuration built with bootc and Chainguard's [wolfi linux](https://github.com/wolfi-dev/os). All software in the base image provided here is packaged, installed declaratively and compatible with security scanners.

## Features

- **nftables** - Modern firewall and NAT with VLAN support
- **dnsmasq** - DHCP server with static leases and DNS forwarding
- **blocky** - DNS-based ad blocking with configurable blocklists
- **BIRD** - BGP routing for Kubernetes integration
- **Tailscale** - Secure mesh networking
- **systemd-networkd** - Declarative network configuration with VLANs
- **iperf3** - Local network performance testing

## Quick Start

Build and deploy the bootable image:

```bash
just build
just image
cp bootable.img /dev/sdX  # Replace with your device
sync
```

The image includes Raspberry Pi 4 UEFI firmware by default.

## Architecture

Packages are defined declaratively with `apko` in the [base image](https://github.com/vaskozl/containers/blob/main/router.yaml), which extends a [bootc base image](https://github.com/vaskozl/containers/blob/main/bootc.yaml).

Configuration files in `config/etc/` overlay the default package configurations, providing a fully customizable router setup that's version-controlled and reproducible.

---

## Customizing for Your Network

The configuration files in this repository are tailored to a specific network. Follow this guide to adapt them for your setup.

### 1. Network Topology

**Define your network layout** in `config/etc/systemd/network/`:

#### WAN Interface (`10-enp1s0u2.network`)
The external/internet-facing interface typically uses DHCP:

```ini
[Match]
Name=enp1s0u2  # Change to your WAN interface name

[Network]
DHCP=yes
```

#### LAN Interface (`10-eth0.network`)
The internal network interface with your primary subnet:

```ini
[Match]
Name=eth0  # Change to your LAN interface name

[Network]
Address=192.168.1.1/24  # Your primary LAN subnet
```

#### VLANs (`20-*.netdev` and `20-*.network`)
Create isolated networks (guest Wi-Fi, IoT devices, etc.):

- `20-guest.netdev` - Guest network on VLAN 51
- `20-iot.netdev` - IoT devices on VLAN 107

Customize the VLAN IDs and subnets for your needs.

### 2. Firewall Rules

**Edit `config/etc/nftables.d/rules.nft`** to match your network:

Update the interface and network definitions at the top of the file to match your setup:

```nft
define DEV_PRIVATE = eth0         # Your LAN interface
define DEV_WORLD = enp1s0u2           # Your WAN interface
define NET_PRIVATE = 192.168.0.0/16   # Your private network range
```

The ruleset includes examples for VLANs, port forwarding, and device-specific rules. Customize the chains and rules based on your security requirements.

### 3. DHCP and DNS

**Edit `config/etc/dnsmasq.conf`**:

#### DHCP Ranges
Configure IP ranges for each network:

```conf
dhcp-range=eth0,192.168.1.64,192.168.1.253,12h
dhcp-range=iot,192.168.107.64,192.168.107.253,12h
dhcp-range=guest,192.168.51.64,192.168.51.253,12h
```

#### DNS Domain
Set your internal domain:

```conf
domain=home.local              # Change to your domain
expand-hosts                   # Append domain to /etc/hosts entries
```

#### Custom DNS Servers
Forward specific domains to custom servers:

```conf
server=/mydomain.local/192.168.1.10
```

#### Static DHCP Leases
**Edit `config/etc/ethers`** to assign fixed IPs by MAC address:

```
aa:bb:cc:dd:ee:ff hostname.home.local
```

**Edit `config/etc/hosts`** for DNS resolution:

```
192.168.1.100 hostname
```

### 4. DNS Blocking

**Edit `config/etc/blocky.yaml`** to configure ad/tracker blocking:

```yaml
blocking:
  denylists:
    hagezi:
      - https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/pro.txt
  clientGroupsBlock:
    default:
      - hagezi
```

Choose your preferred blocklists or disable blocking entirely by removing the `blocking` section.

### 5. User Accounts

**Create `secrets.env`** with your user password hash:

```bash
# Generate password hash
openssl passwd -6 'yourpassword'

# Add to secrets.env
SHADOW_USER='pinewall:$6$your_hash_here:19000:0:99999:7:::'
```

The default user is `pinewall` with sudo access configured in `config/etc/sudoers.d/pinewall`.

### 6. SSH Access

**Add your public key** to `config/home/pinewall/.ssh/authorized_keys`:

```
ssh-rsa AAAAB3NzaC1yc2E... your@email.com
```

### 7. System Tweaks

**Edit `config/etc/sysctl.d/99-router.conf`** for kernel parameters:

- Already configured for IPv4/IPv6 forwarding
- Conntrack tuning for high-traffic networks
- Adjust `nf_conntrack_max` if you have many concurrent connections

### 8. Services

**Edit `config/etc/systemd/system-preset/10-enable-services.preset`** to control which services start on boot:

```conf
enable bird.service
enable blocky.service
enable dnsmasq.service
enable nftables.service
enable tailscaled.service
```

Comment out services you don't need.

---

## Building Your Custom Router

1. Fork or clone this repository
2. Modify the configuration files
3. Create `secrets.env` with your password hash
4. Build and create a bootstrap image:
   ```bash
   just build
   just image
   ```
5. Write to disk, e.g.: `dd if=bootable.img of=/dev/sdX bs=4M status=progress && sync`
6. Boot your router from the disk

## Testing in a VM

Test your configuration before deploying to hardware:

```bash
just vfkit  # macOS with vfkit
```

Or use your preferred VM tool with the `bootable.img` as the boot disk.

## Updating

Edit the Justfile to push your images to a custom registry. Following that you make use `just push` to push your very own
custom bootc images.

You can `bootc switch` to your image:

```bash
# One-time: switch to your custom image
bootc switch ghcr.io/yourusername/pinewall-bootc

# Future updates: make changes, rebuild, push, then:
bootc update
systemctl reboot
```

The immutable design means every deployment is reproducible from git history.

## Advanced Customization

### Custom Base Image

Modify the base image to add/remove packages by editing the upstream [router.yaml](https://github.com/vaskozl/containers/blob/main/router.yaml) or fork and reference your own in the `Dockerfile`.

### Additional Services

Add custom systemd services to `config/etc/systemd/system/` and enable them in the preset files.

### Network Interfaces

For additional interfaces, create corresponding `*.network` files in `config/etc/systemd/network/`.

---

## Troubleshooting

- Check logs: `journalctl -f` after booting
- Verify services: `systemctl status dnsmasq nftables blocky`
- Test firewall: `nft list ruleset`
- DNS resolution: `dig @localhost example.com`
- DHCP leases: `cat /var/lib/misc/dnsmasq.leases`
