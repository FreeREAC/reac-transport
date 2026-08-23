# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Pau Aliagas <linuxnow@gmail.com>

# OpenWrt feed recipe for reac-transport: carry REAC across an OpenWrt network.
#
# Declarative transport for Roland REAC (EtherType 0x8819): a gretap tunnel + its
# 8021q VLAN sub-interfaces + br-lan membership + an fw4-sourced L2 return-path
# drop, all expressed natively (netifd UCI + fw4) so a `service network reload`
# rebuilds them instead of wiping them. Same L2 segment -> VLAN-trunk REAC; across
# L3 / Wi-Fi -> gretap-tunnel it. The de-jitter daemon (reac-repacer) is a separate
# package layered on top.
#
# Fingerprint-free: no rig IPs / SSIDs / keys live here. The gretap local/peer
# addresses are computed on-device at install from the box's own network.lan.ipaddr.
include $(TOPDIR)/rules.mk

PKG_NAME:=reac-transport
PKG_VERSION:=0.1.0
PKG_RELEASE:=1
PKG_MAINTAINER:=Pau Aliagas <linuxnow@gmail.com>
PKG_LICENSE:=GPL-3.0-or-later

include $(INCLUDE_DIR)/package.mk

define Package/reac-transport
  SECTION:=sound
  CATEGORY:=Sound
  TITLE:=REAC transport over OpenWrt (VLAN trunk + gretap tunnel)
  URL:=https://github.com/FreeREAC/reac-transport
  # gre = the netifd proto handler that makes `proto 'gretap'` work; kmod-gre = the
  # ip_gre module. 8021q is built into modern OpenWrt kernels (no kmod-8021q
  # package). firewall4 auto-sources /etc/nftables.d/*.nft on reload.
  DEPENDS:=+kmod-gre +gre +nftables +firewall4
endef

define Package/reac-transport/description
  Declarative REAC transport for OpenWrt: a gretap tunnel, its 8021q VLAN
  sub-interfaces and br-lan membership as native netifd UCI, plus an fw4-sourced
  bridge nft drop for the tunnel->stagebox return path. The gretap peer and the
  VLAN/bridge wiring are merged on-device at install from the box's own LAN IP, so
  the package ships free of any site fingerprints. The bridge drop assumes a
  re-pacer owns the tunnel->stagebox direction: pair it with reac-repacer on a
  jittery link (Wi-Fi), or drop that rule for a zone you trunk raw.
endef

# Package-owned config (preserved across upgrade).
define Package/reac-transport/conffiles
/etc/nftables.d/10-reac.nft
endef

# Pure integration package: no source to compile.
define Build/Compile
endef

define Package/reac-transport/install
	$(INSTALL_DIR) $(1)/etc/nftables.d
	$(INSTALL_CONF) ./files/etc/nftables.d/10-reac.nft $(1)/etc/nftables.d/10-reac.nft
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/98-reac-network     $(1)/etc/uci-defaults/98-reac-network
	$(INSTALL_BIN) ./files/etc/uci-defaults/99-reac-gretap-peer $(1)/etc/uci-defaults/99-reac-gretap-peer
endef

# On first boot the uci-defaults run automatically. For a live `apk add`, run them
# now and reload the network so the gretap + VLAN fabric comes up immediately.
define Package/reac-transport/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
for f in /etc/uci-defaults/98-reac-network /etc/uci-defaults/99-reac-gretap-peer; do
	[ -x "$$f" ] && sh "$$f"
done
/etc/init.d/network reload 2>/dev/null
exit 0
endef

$(eval $(call BuildPackage,reac-transport))
