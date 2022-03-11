#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=opennds
PKG_FIXUP:=autoreconf
PKG_VERSION:=9.6.0
PKG_RELEASE:=2

PKG_SOURCE_URL:=https://codeload.github.com/opennds/opennds/tar.gz/v$(PKG_VERSION)?
PKG_SOURCE:=opennds-$(PKG_VERSION).tar.gz
PKG_HASH:= #shasum -a 256 of tar.gz of source files goes here
PKG_BUILD_DIR:=$(BUILD_DIR)/openNDS-$(PKG_VERSION)

PKG_MAINTAINER:=Rob White <rob@blue-wave.net>
PKG_BUILD_PARALLEL:=1
PKG_LICENSE:=GPL-2.0+

include $(INCLUDE_DIR)/package.mk

define Package/opennds
	SUBMENU:=Captive Portals
	SECTION:=net
	CATEGORY:=Network
	# For post OpenWrt 21.02.xx nft support:
	DEPENDS:=+iptables-nft +kmod-ipt-conntrack +kmod-ipt-nat +libmicrohttpd-no-ssl
	# For OpenWrt 21.02.xx and earlier, ipt support:
	#DEPENDS:=+libpthread +iptables-mod-ipopt +libmicrohttpd-no-ssl
	TITLE:=Open public network gateway daemon
	URL:=https://github.com/opennds/opennds
	CONFLICTS:=nodogsplash nodogsplash2
endef

define Package/opennds/description
	openNDS is a Captive Portal solution that offers an instant way to provide restricted access to the Internet.
	With little or no configuration, a dynamically generated and adaptive splash page sequence is automatically served.
	Both client driven Captive Portal Detection (CPD) and gateway driven Captive Portal Identification (CPI - RFC 8910 and RFC 8908) are supported.
	Internet access is granted by either a click to continue button, or after credential verification as a result of filling in a login form.
	The package incorporates the FAS API allowing many flexible customisation options.
	The creation of sophisticated third party authentication applications is fully supported.
	Internet hosted https portals can be implemented with no security errors, to inspire maximum user confidence.
endef

define Package/opennds/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/opennds $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ndsctl $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/etc/opennds/htdocs/images
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_DIR) $(1)/usr/lib/opennds
	$(CP) $(PKG_BUILD_DIR)/resources/splash.css $(1)/etc/opennds/htdocs/
	$(CP) $(PKG_BUILD_DIR)/resources/splash.jpg $(1)/etc/opennds/htdocs/images/
	$(CP) $(PKG_BUILD_DIR)/linux_openwrt/opennds/files/etc/config/opennds $(1)/etc/config/
	$(CP) $(PKG_BUILD_DIR)/linux_openwrt/opennds/files/etc/config/opennds $(1)/etc/opennds/config.uci
	$(CP) $(PKG_BUILD_DIR)/linux_openwrt/opennds/files/etc/init.d/opennds $(1)/etc/init.d/
	$(CP) $(PKG_BUILD_DIR)/linux_openwrt/opennds/files/etc/uci-defaults/40_opennds $(1)/etc/uci-defaults/
	$(CP) $(PKG_BUILD_DIR)/linux_openwrt/opennds/files/usr/lib/opennds/restart.sh $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/binauth/binauth_log.sh $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/libs/libopennds.sh $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/PreAuth/theme_click-to-continue-basic.sh $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/PreAuth/theme_click-to-continue-custom-placeholders.sh $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/PreAuth/theme_user-email-login-basic.sh $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/PreAuth/theme_user-email-login-custom-placeholders.sh $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/libs/get_client_interface.sh $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/libs/client_params.sh $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/libs/unescape.sh $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/libs/authmon.sh $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/libs/dnsconfig.sh $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/libs/post-request.php $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/fas-aes/fas-aes.php $(1)/etc/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/fas-hid/fas-hid.php $(1)/etc/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/fas-aes/fas-aes-https.php $(1)/etc/opennds/
endef

define Package/opennds/postrm
#!/bin/sh
uci delete firewall.opennds
uci commit firewall
endef

define Package/opennds/conffiles
/etc/config/opennds
endef

$(eval $(call BuildPackage,opennds))
