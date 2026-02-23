# pinewall-config

> Inspired by [Alex Haydock's original Alpine project](https://github.com/alexhaydock/pinewall)

An immutable, declarative home router configuration built with bootc and Chainguard's [wolfi linux](https://github.com/wolfi-dev/os). All software in the base image provided here is packaged, installed declaratively and compatible with security scanners.

## Config & Container

The config itself is built in the CI of my packages repo. You can find the [melange apk spec here](https://github.com/vaskozl/wolfi-packages/blob/main/pinewall-config.yaml).

The container which includes the config and all other depedencies is in my containers repo, the [apko container spec can be found here](https://github.com/vaskozl/containers/blob/main/pinewall-config.yaml).

## Image Generation

Right now the images built by `apko` are not directly compatible with `bootc` as such I use an empty `Dockerfile` to "fix" the image with podman.

```bash
just build
just image
cp bootable.img /dev/sdX  # Replace with your device
sync
```

The `just image` command also installs Raspberry Pi 4 UEFI in the aarch64 firmware by default.

## Customizing for Your Network

The configuration files in this repository are tailored to a specific network. Follow this guide to adapt them for your setup.

### 1. Network Topology

**Define your network layout** in `vendor/etc/systemd/network/`:

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

**Edit `vendor/etc/nftables.d/rules.nft`** to match your network:

Update the interface and network definitions at the top of the file to match your setup:

```nft
define DEV_PRIVATE = eth0         # Your LAN interface
define DEV_WORLD = enp1s0u2           # Your WAN interface
define NET_PRIVATE = 192.168.0.0/16   # Your private network range
```

The ruleset includes examples for VLANs, port forwarding, and device-specific rules. Customize the chains and rules based on your security requirements.

### 3. DHCP and DNS

**Edit `vendor/etc/dnsmasq.conf`**:

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
**Edit `vendor/etc/ethers`** to assign fixed IPs by MAC address:

```
aa:bb:cc:dd:ee:ff hostname.home.local
```

**Edit `vendor/etc/hosts`** for DNS resolution:

```
192.168.1.100 hostname
```

### 4. DNS Blocking

**Edit `vendor/etc/blocky.yaml`** to configure ad/tracker blocking:

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

### 5. System Tweaks

**Edit `vendor/etc/sysctl.d/99-router.conf`** for kernel parameters:

- Already configured for IPv4/IPv6 forwarding
- Conntrack tuning for high-traffic networks
- Adjust `nf_conntrack_max` if you have many concurrent connections

### 6. Services

**Edit `vendor/etc/systemd/system-preset/10-enable-services.preset`** to control which services start on boot:

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

While I build containers in packages in seperate repos, you can also do it in a single repo with a local repository.
Check out [Alex Haydock's Justfile](https://github.com/alexhaydock/pinewall/blob/master/justfile) which does exactly that.

## Testing in a VM

Test your configuration before deploying to hardware:

```bash
just vfkit  # macOS with vfkit
```

Or use your preferred VM tool with the `bootable.img` as the boot disk.

## Troubleshooting

- Check logs: `journalctl -f` after booting
- Verify services: `systemctl status dnsmasq nftables blocky`
- List firewall rules: `nft list ruleset`
- DHCP leases: `cat /var/lib/misc/dnsmasq.leases`
