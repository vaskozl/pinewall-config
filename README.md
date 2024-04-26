<img src="logo.png" align="left" width="100px" height="100px"/>

#### pinewall-config - Immutable Home router declared in Git

> For more information about the why and what, [check Alex Haydock's original project template](https://github.com/alexhaydock/pinewall).


* `config/etc/apk/world` defines the packages
* the files in etc are the config files that get overlayed over the apk defaults
* genapkovl-pinewall.sh defines the services
* interfaces are in `config/etc/network/interfaces`
* `config/etc/nftables.d/rules.nft` sets up NAT and firewall rules

To build a bootable for a Raspberry PI:
```
docker build -t pinewall .
docker create --name pinewall pinewall
docker cp pinewall:/tmp/images/. .
docker rm pinewall
```
For other architectures set `profile_standard` and `arch` in mkimg.pinewall_rpi.sh

## Contents

* `nftables` pure firewall and NAT
* `bird` for BGP with Kubernetes
* `dnsmasq` for DHCP and DNS forwarding
* `iperf3` local "speedtest" server
