Access Control, Walled Garden and Block Lists
#############################################

Access Control For Authenticated Users
**************************************

* Access can be allowed by openNDS but the final decision will be passed on to the operating system firewall. (Note: passthrough is deprecated as in nftables "allow" is equivalent to the old "passthrough"
* All listed rules will be applied in the order present in the list.
* An ip address or an FQDN may be included in a list entry.
* If an FQDN resolves to multiple ip addresses, the rule will **NOT** be added. Rules for such FQDNs must be added elsewhere (eg the operating system firewall)

Allow Access for Authenticated Users (allow)
============================================

Any entries set here, or below in Block Access, are in addition to the default policy of "allow all"

Default:

No Entry, equivalent to

 ``list authenticated_users 'allow all'``

Example:

Grant access to https web sites, subject to the operating system's firewall rules

 ``list authenticated_users 'allow tcp port 443'``

Grant access to udp services at address 123.1.1.1, on port 5000.

 ``list authenticated_users 'allow udp port 5000 to 123.1.1.1'``

Block Access For Authenticated Users (Block Lists)
==================================================

Deny authenticated users access to external services

A Block List can be configured either:
    1. Manually for known ip addresses or fqdns with single ip addresses
    2. Autonomously from a list of FQDNs and ports

Manual Block List configuration
-------------------------------

This requires research to determine the ip addresses of the Block List site(s) and can be problematic as sites can use many dynamic ip addresses.

However, manual configuration does not require any additional dependencies (ie additional installed packages).

Manual configuration example:

``list authenticated_users 'block udp port 8020 to 112.122.123.124'``

An fqdn can be used in place of an ip address (but the fqdn must have only one possible ip address)

``list authenticated_users 'block tcp port 443 to mywebsite.com'``

Autonomous Blocklist configuration using a list of FQDNs and Ports
------------------------------------------------------------------

This has the advantage of discovering all ip addresses used by the Blocklist sites.

But it does require the dnsmasq-full package (and also the ipset package if dnsmasq does not support nftsets) to be installed.

Configuration is then a simple matter of adding two lists as follows:

``list blocklist_fqdn_list 'fqdn1 fqdn2 fqdn3 .... fqdnN'``

``list blocklist_port_list 'port1 port2 port3 .... portN'``

or

``list blocklist_fqdn_list 'fqdn1'``

``list blocklist_fqdn_list 'fqdn2'``

``list blocklist_fqdn_list '....... etc.``

``list blocklist_fqdn_list 'fqdnN'``

Similarly, ports can be listed on multiple lines

.. Note:: If blocklist_port_list is NOT specified, then blocklist access is denied for all protocols (tcp, udp, icmp) on ALL ports for each fqdn specified in blocklist_fqdn_list.

If blocklist_port_list IS specified, then:

    1. Specified port numbers apply to ALL FQDN's specified in blocklist_fqdn_list.
    2. Access is blocked only for specified ports in each blocklist fqdn.
    3. Blocklist only applies to authenticated users.


Autonomous configuration examples
---------------------------------

    1. To add Facebook to the blocklist, the list entries would be:
        ``list blocklist_fqdn_list 'facebook.com fbcdn.net'``

    2. To add YouTube to the blocklist, the list entries would be:
        ``list blocklist_fqdn_list 'youtube.com'``

    3. To deny access only to a port or list of ports, allowing other ports:
        ``list blocklist_port_list '443 80'``

Access Control For Preauthenticated Users:
******************************************

	*****IMPORTANT*****

    To support RFC8910 Captive Portal Identification

    AND to help prevent DNS tunnelling, DNS Hijacking and generally improve security,

 	*****DO NOT ALLOW ACCESS TO EXTERNAL DNS SERVICES*****

Walled Garden Access For Preauthenticated Users
***********************************************

You can allow preauthenticated users to access external services
This is commonly referred to as a Walled Garden.

A Walled Garden can be configured either:
 * Manually for known ip addresses

 * Autonomously from a list of FQDNs and ports


Manual Walled Garden configuration
==================================

Manual Walled Garden configuration requires research to determine the ip addresses of the Walled Garden site(s).

This can be problematic as sites can use many dynamic ip addresses.

However, manual configuration does not require any additional dependencies (ie additional installed packages).

Note that standard unencrypted HTTP port (TCP port 80) is used for captive portal detection (CPD) and access to external websites should use HTTPS (TCP port 443) for security.

It is however, still possible to allow TCP port 80 by using the Autonomous Walled Garden approach.

Manual configuration example:

``list preauthenticated_users 'allow udp port 8020 to 112.122.123.124'``

Autonomous Walled Garden configuration
======================================

Autonomous Walled Garden configuration is activated using a list of FQDNs and Ports.

This has the advantage of discovering all ip addresses used by the Walled Garden sites.

But it does require the dnsmasq-full package to be installed and on OpenWrt 22.03.x or earlier the ipset package is also required. This is achieved by running the following commands (on OpenWrt):

``opkg update``

``opkg install ipset`` (OpenWrt version 22.03.x or earlier)

``opkg remove dnsmasq``

``opkg install dnsmasq-full``

Configuration is then a simple matter of adding two lists as follows:
 
``list walledgarden_fqdn_list 'fqdn1 fqdn2 fqdn3 .... fqdnN'``

``list walledgarden_port_list 'port1 port2 port3 .... portN'``

Note: If walledgarden_port_list is NOT specified, then Walled Garden access is granted for all protocols (tcp, udp, icmp) on ALL ports for each fqdn specified in walledgarden_fqdn_list.

Note: If walledgarden_port_list IS specified, then:

 * Specified port numbers apply to ALL FQDN's specified in walledgarden_fqdn_list.
 * Only tcp protocol Walled Garden access is granted.


Add Facebook to the Walled Garden
=================================

To add Facebook to the Walled Garden, the list entries would be:

``list walledgarden_fqdn_list 'facebook.com fbcdn.net'``

``list walledgarden_port_list '443'``


Add Paypal to the Walled Garden
===============================

To add Paypal to the Walled Garden, the list entries would be:

``list walledgarden_fqdn_list 'paypal.com paypalobjects.com'``

``list walledgarden_port_list '443'``

User Access to Services On the Router
*************************************

Access is automatically granted to resources required for normal operation of the captive portal and all other access is blocked.

By default the user to router access rules are **not** passed through to the system firewall for additional processing.

Users to Router Passthrough
===========================

(Applies to OpenWrt only)

Default: 0 (disabled)

To enable passthrough, set to 1

``option users_to_router_passthrough '1'``

**WARNING**: Do not enable unless you know what you are doing.

*Enabling passthrough may well soft brick your router, particularly if openNDS is bound to a guest network.*

Access to the router.
=====================

Access falls into two categories:
 * Essential
 * Optional

Essential Access
================

Essential access for DNS and DHCP is granted by default.

If additional optional access is required, it is essential that you specifically allow ports for DNS and DHCP (unless you have a very specific reason for not doing so and know what you are doing. **Disabling these will soft brick your router!**):

``list users_to_router 'allow tcp port 53'``

``list users_to_router 'allow udp port 53'``

``list users_to_router 'allow udp port 67'``

Optional Access
===============

You may wish to allow access to specific services on the router.

For example - Allow ports for SSH/Telnet/HTTP/HTTPS:

``list users_to_router 'allow tcp port 22'``

``list users_to_router 'allow tcp port 23'``

``list users_to_router 'allow tcp port 80'``

``list users_to_router 'allow tcp port 443'``


Walled Garden and Block Lists
*****************************

From opennDS v10.2.0 onwards, it is possible to configure both Walled Garden (allowing specified FQDN access for Preauthenticated users) and Block Lists (blocking specified FQDN access for authenticated users). The following documentation applies to walled Garden, but configuring a Block List is very similar. (see Configuration Options in this documentation)

Manual Walled Garden
====================

Preauthenticated clients are, by default, blocked from all access to the Internet.

Access to certain web sites can be allowed. For example, clients will automatically be granted access to an external FAS server for the purpose of authentication.

Access to other web sites may be manually granted so clients can be served content such as news, information, advertising, etc. This is achieved in openNDS by allowing access to the IP address of the web sites as required.

A set of such web sites is referred to as a Walled Garden.

Note that standard unencrypted HTTP port (TCP port 80) is used for captive portal detection (CPD) and 
access to external websites should use HTTPS (TCP port 443) for security.
It is still possible to allow TCP port 80 by using Autonomous Walled Garden approach.

Autonomous Walled Garden
========================

Granting access by specifying the site IP address works well in the simplest of cases but the administrative overhead can rapidly become very difficult, for example with social media sites that load balance high volumes of traffic over many possible IP addresses.

In addition, the IP address of any web site may change.

Rather than using IP addresses, a much more efficient method of granting access would be by using the Fully Qualified Domain Name (FQDN) of each site and have a background process populate a database of allowed IP addresses.

openNDS supports Autonomous Walled Garden by means of a simple configuration option. This does have additional dependencies but these only apply if the Autonomous Walled Garden is enabled.

OpenWrt Walled Garden
=====================

The additional dependencies are the ipset (OpenWrt 22.03.x and earlier) and dnsmasq-full packages.
Install these by running the following commands:

.. code::

 opkg update
 opkg install ipset (not required for OpenWrt 23.05.x and onwards)
 opkg remove dnsmasq
 opkg install dnsmasq-full

Configure as follows:

.. code::

 uci add_list opennds.@opennds[0].walledgarden_fqdn_list='<fqdn1> <fqdn2> <fqdn3> [......] <fqdnN>'

where <fqdn1> to <fqdnN> are the fully qualified domain names of the URLs you want to use to populate the ipset.

eg. For Facebook use facebook.com and fbcdn.net as fqdn1 and fqdn2

In addition you can limit access to the Walled Garden to a list of IP ports:

.. code::

 uci add_list opennds.@opennds[0].walledgarden_port_list='<port1> <port2> <port3> [......] <portN>'

Restart openNDS to activate the Walled Garden.

To make these changes permanent (eg survive a reboot), run the command:

.. code::

 uci commit opennds

Generic Linux Walled Garden
===========================
On most generic Linux platforms the procedure is in principle the same as for OpenWrt.

The dnsmmasq-full package is a requirement, but this is generally the default.

You can check the compile time options of dnsmasq with the following command:

.. code::

 dnsmasq --version | grep -m1 'Compile time options:' | cut -d: -f2

If the returned string contains "no-nftset" then you will have to upgrade dnsmasq to the full version.

To enable Walled Garden, add the following to the /etc/config/opennds file

.. code::

 list walledgarden_port_list '<port1> <port2> <port3> [......] <portN>'


In addition you can specify a restricted set of ports for access to the walled garden by adding the line:

.. code::

 walledgarden_port_list <port1> <port2> <port3> [......] <portN>

Restart openNDS to activate the Walled Garden.

Warning When Port 80 is Enabled
===============================

Port 80 is used by all devices to detect Captive Portals.

If port 80 is enabled in the Walled Garden configuration (either implicitly by adding to the ports list, or explicitly by not defining a ports list) then any Captive Portal Detection attempted by a device using a Walled Garden FQDN will fail.

For example if the FQDN "apple.com" is defined in the Walled Garden list, then Apple devices will fail to trigger the Portal Splash Page sequence (login page) if port 80 is enabled.