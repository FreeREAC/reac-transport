# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Pau Aliagas <linuxnow@gmail.com>

# OpenWrt feed recipe for reac-rig: the DECLARATIVE REAC-over-WDS fabric.
#
# This package owns the *integration* layer that makes the rig survive a
# `service network restart` (the historical fragility): the gretap tunnel,
# its three 8021q VLAN sub-interfaces, their br-lan membership and the L2
# return-path nft drop are all expressed natively (netifd UCI + fw4), so a
# network reload rebuilds them instead of wiping them. It also ships a
# no-topology procd service that launches the reac-repacer daemon once the
# fabric is up — the daemon never touches topology any more.
#
# Fingerprint-free: NO rig IPs / SSIDs / keys / peer addresses live in this
# package. The gretap local/remote addresses and the AP/STA role are computed
# ON THE DEVICE at install time by the uci-defaults shims, from the box's own
# network.lan.ipaddr and wireless mode.
#
# Copy this directory into an OpenWrt feed (or package/) and build with the
# SDK. On OpenWrt 25.12 the SDK emits .apk packages.
include $(TOPDIR)/rules.mk

PKG_NAME:=reac-rig
PKG_VERSION:=0.1.1
PKG_RELEASE:=1
PKG_MAINTAINER:=Pau Aliagas <linuxnow@gmail.com>
PKG_LICENSE:=GPL-3.0-or-later

include $(INCLUDE_DIR)/package.mk

define Package/reac-rig
  SECTION:=sound
  CATEGORY:=Sound
  TITLE:=REAC-over-WDS declarative fabric + re-pacer launcher
  URL:=https://github.com/linuxnow/reac-aes67
  # gre = the netifd proto handler (/lib/netifd/proto/gre.sh) that makes
  #       `proto 'gretap'` work; the load-bearing new dependency.
  # kmod-gre = the ip_gre module; kmod-8021q = vlandev (8021q config device).
  # firewall4 pulls fw4 so /etc/nftables.d/*.nft is auto-sourced on reload.
  # reac-repacer = the de-jitter daemon this rig launches.
  DEPENDS:=+reac-repacer +kmod-gre +gre +kmod-8021q +nftables +firewall4
endef

define Package/reac-rig/description
  Declarative REAC-over-WDS fabric for the GL-MT6000 pair. Provides the gretap
  tunnel, its 8021q VLAN sub-interfaces and br-lan membership as native netifd
  UCI, an fw4-sourced bridge nft drop for the tunnel->stagebox return path, and
  a no-topology procd service that launches the reac-repacer once the fabric is
  up. Replaces the old imperative rc.local / reacN-restore.sh / hotplug-rerun
  plumbing, so the fabric survives `service network restart` instead of being
  wiped. Rig-specific addresses and the AP/STA role are filled on-device at
  install time from the box's own LAN IP and wireless mode, so the package
  ships free of any rig fingerprints.
endef

# conffiles: preserve operator edits across upgrade. The network UCI and the
# gretap peer/role are merged into the live /etc/config/* by the uci-defaults
# shims (NOT shipped as whole files), so only the two genuinely package-owned
# config files are listed here.
define Package/reac-rig/conffiles
/etc/config/reac-rig
/etc/nftables.d/10-reac.nft
endef

# Pure integration package: no source to compile. (rules.mk still needs a
# Build/Compile target; make it a no-op.)
define Build/Compile
endef

define Package/reac-rig/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/reac-rig $(1)/etc/config/reac-rig
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/reac-rig $(1)/etc/init.d/reac-rig
	$(INSTALL_DIR) $(1)/etc/nftables.d
	$(INSTALL_CONF) ./files/etc/nftables.d/10-reac.nft $(1)/etc/nftables.d/10-reac.nft
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/97-reac-role        $(1)/etc/uci-defaults/97-reac-role
	$(INSTALL_BIN) ./files/etc/uci-defaults/98-reac-network     $(1)/etc/uci-defaults/98-reac-network
	$(INSTALL_BIN) ./files/etc/uci-defaults/99-reac-gretap-peer $(1)/etc/uci-defaults/99-reac-gretap-peer
endef

# Enable + start the service on install. uci-defaults run before this on first
# boot, so the fabric + reac-rig.repacer config exist by the time it starts.
define Package/reac-rig/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
# reac-rig is THE launcher. Make sure the standalone reac-repacer init does not
# also start the daemon — a double-launch fights over the same raw DSA ports.
/etc/init.d/reac-repacer disable 2>/dev/null
/etc/init.d/reac-repacer stop 2>/dev/null
/etc/init.d/reac-rig enable
/etc/init.d/reac-rig start
exit 0
endef

define Package/reac-rig/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/reac-rig stop
/etc/init.d/reac-rig disable
exit 0
endef

$(eval $(call BuildPackage,reac-rig))
