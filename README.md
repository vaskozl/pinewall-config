#### pinewall-config - Immutable Wolfi Bootc Home router declared in Git

> Inspired by  [Alex Haydock's original alpine project](https://github.com/alexhaydock/pinewall).

* Packages are defined declarativily with `apko` in the [base image](https://github.com/vaskozl/containers/blob/main/router.yaml) which is itself based on [bootc](https://github.com/vaskozl/containers/blob/main/bootc.yaml) base image.
* The files in etc are the config files that get overlayed over the apk defaults

To build a bootable image:

```
just build
just image

cp bootable.img /dev/diskX
sync
```

## Contents

* `nftables` pure firewall and NAT
* `tailscale` for BGP with Kubernetes
* `dnsmasq` for DHCP and DNS forwarding
* `iperf3` local "speedtest" server
* ...
