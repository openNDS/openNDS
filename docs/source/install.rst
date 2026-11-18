Installing openNDS
##################

Prerequisites
*************

openNDS is designed to run on a device configured as an IPv4 router and will have at least two network interfaces:

 **A WAN interface** (Wide Area Network). This interface must be connected to an Internet feed:

 * Either an ISP CPE (Internet Service Provider Customer Premises Equipment)
 * Or another router, such as the venue ADSL router.
 * It must be configured as a DHCP client, obtaining its IPv4 address and DNS server from the connected network.

 **A LAN interface** (Local Area Network). This interface MUST be configured to:

 * Provide the Default IPv4 gateway in a private IPv4 subnet that is different to any private subnets between it and the ISP CPE
 * Provide DHCP services to connected clients
 * Provide DNS services to connected clients
 * Provide Network Address Translation (NAT) for all outgoing traffic directed to the WAN interface.

If an improper routing configuration is detected, openNDS will shut down.

Installing on OpenWrt
*********************

* Have a router working with OpenWrt. At the time of writing, the current version of openNDS has been tested with OpenWrt 22.03.x, 23.05.x and Master Snapshot.

* openNDS v10.0.0 or higher, will not work on versions of OpenWrt less than 22.03.x

* Make sure your router is working correctly before you try to install  openNDS. In particular, make sure your DHCP daemon is serving addresses on the interface that openNDS will manage.

  The default interface is br-lan but can be changed to any LAN interface by editing the /etc/config/opennds file.

* To install openNDS on 23.3.x or higher, you may use the OpenWrt Luci web interface or alternatively, ssh to your router and run the command:

    ``opkg update``

  followed by

    ``opkg install opennds``

* After install, openNDS is dormant until auto_run is set. It sets up no firewall rules, so it cannot cut off access to the router. The system log lists the candidate gateway interfaces.

* Edit /etc/config/opennds and set the gatewayinterface option to the bridge that you want openNDS to manage (the default is br-lan), then set ``option auto_run '1'``.

* openNDS will then start within about 15 seconds, and automatically on reboot. It can also be started and stopped manually.

* To start openNDS, run the following, or just reboot the router:

    ``service opennds start``

* To test the installation, connect a client device to the interface on your router that is managed by openNDS (for example, connect to the router's wireless lan).

 Most client device operating systems and browsers support Captive Portal Detection (CPD) and the operating system or browser on that device will attempt to contact a pre defined port 80 web page.

 CPD will trigger openNDS to serve the default splash page where you can click or tap Continue to access the Internet.

 See the Authentication section for details of setting up a proper authentication process.

 If your client device does not display the splash page it most likely does not support CPD.

 You should then manually trigger openNDS by trying to access a port 80 web site (for example, http://gnome.org is a good choice).

* To stop openNDS:

    ``service opennds stop``

* To uninstall openNDS:

    ``opkg remove opennds``

Upgrading to v11.1.0 or later
*****************************

openNDS v11.1.0 adds the option auto_run, with a default of 0. After an upgrade from an earlier version, an existing configuration that does not set it leaves openNDS dormant.

To run as before, add ``option auto_run '1'`` to /etc/config/opennds, then restart openNDS or wait about 15 seconds.

Generic Linux
*************

openNDS and libmicrohttps-ssl can be compiled in place for most distributions of Linux.

To compile libmicrohttpd and openNDS, see the chapter "How to Compile and install openNDS".
