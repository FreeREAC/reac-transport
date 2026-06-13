# reac-transport

Declarative **REAC-over-OpenWrt transport**: carry a Roland **REAC**
(EtherType `0x8819`) audio stream across an OpenWrt network as a tagged VLAN
trunk on one LAN, or tunnelled over Wi-Fi / L3 with gretap.

Part of [FreeREAC](https://github.com/FreeREAC) — *REAC Exposed Audio
Communications*.

## What it does

REAC is a flat Layer-2 broadcast (EtherType `0x8819`). To move it around a
building you need it on a defined segment. This package sets that up as native
OpenWrt config:

- **gretap tunnel** (`reactap`) — a Layer-2 tunnel over the Wi-Fi / WDS or any IP
  underlay, so REAC crosses a link that isn't a single broadcast domain.
- **802.1q VLAN sub-interfaces** (`.11` / `.12` / `.13`) on the tunnel and the
  bridge — one VLAN per REAC zone (A / B / C), trunked together.
- an **fw4-sourced nftables drop** on the bridge for the tunnel→stagebox return
  path, so the segment stays clean.

Everything is netifd (UCI) + firewall4, so a `service network reload` rebuilds the
fabric instead of wiping it. The gretap local/peer addresses are computed
on-device at install from the box's own `network.lan.ipaddr`, so the package
ships free of any site fingerprint.

Same L2 segment → VLAN-trunk REAC. Across Wi-Fi / L3 → gretap-tunnel it. When the
path is jittery (Wi-Fi), pair it with
[reac-repacer](https://github.com/FreeREAC/reac-repacer) to de-jitter the stream.

## Build

    ./scripts/build.sh                          # latest stable OpenWrt, mediatek/filogic
    OPENWRT_RELEASE=24.10.2 ./scripts/build.sh  # pin a release

The apk lands in `.build/out/`.

## Install

    apk add ./reac-transport-*.apk

The uci-defaults shims run at install (and on first boot): they merge the gretap
peer, the VLAN sub-interfaces and the bridge/firewall wiring into the box's
config, then reload the network. Inspect or tune the result in
`/etc/config/network` and `/etc/nftables.d/10-reac.nft`.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
