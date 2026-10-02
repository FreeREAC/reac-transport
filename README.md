# reac-transport

Declarative **REAC-over-OpenWrt transport**: carry a Roland **REAC**
(EtherType `0x8819`) audio stream across an OpenWrt network as a tagged VLAN
trunk on one LAN, or tunnelled over Wi-Fi / L3 with gretap.

Part of [FreeREAC](https://github.com/FreeREAC) — *REAC Exposed Audio
Communications*.

## What it does

REAC is a Layer-2 stream on its own EtherType (`0x8819`) — no IP, nothing to
route. The master broadcasts its output frames to `ff:ff:ff:ff:ff:ff`; each box
unicasts its inputs back to the master's MAC. Both directions have to cross the
fabric, so a filter written for broadcast alone does not describe this traffic.
To move the stream around a building you need it on a defined segment. This
package sets that up as native OpenWrt config:

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
[reac-repacer](https://github.com/FreeREAC/reac-repacer) to de-jitter the stream —
and read [the return-path drop](#the-return-path-drop-needs-the-re-pacer) below,
which assumes it.

## Sizing a segment

A REAC frame is **`52 + n*36` bytes** for an n-channel segment: 12 time samples of
3 bytes per channel, plus 52 bytes of Ethernet header, counter, type, metadata and
end marker. The geometry is **rate-invariant** — the sample rate rides the *packet
rate*, not the frame size, and `rate = pps * 12` (48 kHz = 4000 frames/s, 96 kHz =
8000). So counting frames per second on the trunk tells you which rate a segment
runs, without decoding a byte. The rate belongs to that segment's master;
reac-pw masters at 96 kHz by default, so assume 8000 frames/s unless the master
says otherwise.

At the 40-channel per-connection maximum:

| where | bytes |
| --- | --- |
| REAC frame on the segment | 1492 |
| + 802.1q tag on the trunk | 1496 |
| + gretap encapsulation (+4 GRE, +20 IPv4, inner Ethernet carried whole) | 1520-byte IP packet / 1534 on the underlay |

That is what the shipped MTUs are for: 1500 on `reactap` and each `reactap.X`,
which carries the 1496-byte tagged frame without fragmenting (40 channels is the
cap, so 1496 is the worst case), and 1700 on `br-lan` so the encapsulated frame
crosses the underlay intact — GRE plus the tagged inner frame is 1500 bytes of IP
payload exactly, with nothing left over. A REAC frame that
fragments is a lost frame — there is no retransmission and no jitter buffer.

Bandwidth, counting the 24 bytes of preamble, SFD, FCS and inter-frame gap that
every frame costs on the wire:

- 40 ch @ 96 kHz = (1492 + 24) × 8000 × 8 = **97.0 Mbit/s per segment**. That
  fills a 100BASE-TX access port. A gigabit trunk holds about ten segments;
  **eight** is the number to plan on.
- Through the tunnel each frame carries the tag and the encapsulation too, so
  budget **~100 Mbit/s per zone** on the underlay. Three zones trunked over one
  gretap ≈ **300 Mbit/s sustained at 24000 frames/s** — that, not a nominal PHY
  rate, is the number a Wi-Fi link is chosen against.
- 48 kHz halves the packet rate and so the bitrate; the frame is the same size.

## One master per segment

RX is a copy, and binding an interface is not mastering it: as many passive
listeners as you like can sit on this fabric. What must be unique is the
**master** — a second master on a segment blocks establishment. reac-pw enforces
that with an abstract-namespace AF_UNIX lock, `\0reac-pw/segment/<netns-inode>/<ifindex>`,
which is keyed **per interface**. A trunk defeats it: two hosts, or one host with
two interfaces bridged onto the same VLAN, are two ifindexes and one REAC segment.
Uniqueness of the master has to come from how you wire the zones; the lock cannot
see across the fabric this package builds.

## The return-path drop needs the re-pacer

`/etc/nftables.d/10-reac.nft` drops the bridged tunnel→stagebox direction
(`reactap.X` → `lanX`), because the re-pacer re-delivers exactly that direction
de-jittered and the box must not receive both copies.

**The rule is unconditional.** Install reac-transport with no re-pacer running and
the stagebox receives nothing from the master and never locks. Either run
[reac-repacer](https://github.com/FreeREAC/reac-repacer) alongside it, or drop the
matching line for any zone you trunk raw. The package's `DEPENDS` does not pull
the re-pacer in — the two are deployed independently.

## Is this still the transport of record?

Yes, for what it actually covers — which is narrower than "the transport".

- The **VLAN trunk** is the transport of record for putting REAC zones on defined
  segments of one OpenWrt box. It is the only piece that makes zones A/B/C
  separable on shared hardware.
- The **gretap tunnel** is the transport of record only where the path is not a
  single broadcast domain: a Wi-Fi / WDS hop, or an L3 leg. On a wired gigabit
  path there is nothing to tunnel — trunk the VLAN and leave gretap out.
- Where master and boxes share one physical segment — a console running reac-pw
  with the boxes on its own NIC — **no fabric is needed at all**. The cable is the
  segment, and this package is for the case where the box is on the far side of
  something.

## Install

    apk add ./reac-transport-*.apk

To build the apk from source, see [BUILDING.md](BUILDING.md).

The uci-defaults shims run at install (and on first boot): they merge the gretap
peer, the VLAN sub-interfaces and the bridge/firewall wiring into the box's
config, then reload the network. Inspect or tune the result in
`/etc/config/network` and `/etc/nftables.d/10-reac.nft`.

Then confirm the tunnel came up bound to the endpoints it was given:

    ip -d link show reactap && ip -d link show reactap.11 && bridge vlan show

netifd's gretap proto handler has been seen to bring the interface up as
`remote any local any` on some OpenWrt releases, which then fails with "Address
not available" and leaves a fabric that carries nothing. Whether the handler
behaves on the release you build against is **unverified here**; the command above
settles it on the box in one line, and a manual `ip link add reactap type gretap
remote <peer> local <self>` is the fallback if it does not.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
