#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=opennds
PKG_FIXUP:=autoreconf
PKG_VERSION:=6.0.1beta
PKG_RELEASE:=1

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
	DEPENDS:=+libpthread +iptables-mod-ipopt +libmicrohttpd-no-ssl
	TITLE:=Open public network gateway daemon
	URL:=https://github.com/opennds/opennds
	CONFLICTS:=nodogsplash nodogsplash2
endef

define Package/opennds/description
	openNDS is a Captive Portal that offers a simple way to
	provide restricted access to the Internet by showing a splash
	page to the user before Internet access is granted.
	It also incorporates an API that allows the creation of
	sophisticated authentication applications.
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
	$(CP) $(PKG_BUILD_DIR)/resources/splash.html $(1)/etc/opennds/htdocs/
	$(CP) $(PKG_BUILD_DIR)/resources/splash.css $(1)/etc/opennds/htdocs/
	$(CP) $(PKG_BUILD_DIR)/resources/status.html $(1)/etc/opennds/htdocs/
	$(CP) $(PKG_BUILD_DIR)/resources/splash.jpg $(1)/etc/opennds/htdocs/images/
	$(CP) $(PKG_BUILD_DIR)/openwrt/opennds/files/etc/config/opennds $(1)/etc/config/
	$(CP) $(PKG_BUILD_DIR)/openwrt/opennds/files/etc/init.d/opennds $(1)/etc/init.d/
	$(CP) $(PKG_BUILD_DIR)/openwrt/opennds/files/etc/uci-defaults/40_opennds $(1)/etc/uci-defaults/
	$(CP) $(PKG_BUILD_DIR)/openwrt/opennds/files/usr/lib/opennds/restart.sh $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/binauth/binauth_log.sh $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/binauth/binauth_sitewide.sh $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/binauth/userlist.dat $(1)/etc/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/binauth/splash_sitewide.html $(1)/etc/opennds/htdocs/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/PreAuth/login.sh $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/PreAuth/login-remote-image.sh $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/libs/get_client_interface.sh $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/libs/get_client_token.sh $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/libs/unescape.sh $(1)/usr/lib/opennds/
	$(CP) $(PKG_BUILD_DIR)/forward_authentication_service/libs/authmon.sh $(1)/usr/lib/opennds/
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
