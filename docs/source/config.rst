Configuration Options - General
###############################

Configuration is split into topic pages: this page (general and gateway settings), :doc:`config_clients`, :doc:`traffic`, :doc:`config_fas`, :doc:`config_access` and :doc:`customparams`.

Enable openNDS
**************

Set to 0 to disable opennds

``option enabled 1``

Use deprecated generic configuration file
******************************************

Use of this setting is no longer supported and if present is ignored.

``option config '/etc/opennds/opennds.conf'``

Enable debug output (0-3)
*************************

Default: 1

Level0
======
Silent (only initial startup, LOG_ERR and LOG_EMERG messages will be seen, otherwise there will be no logging.)

Level 1
=======
LOG_ERR, LOG_EMERG, LOG_WARNING and LOG_NOTICE (this is the default level).

Level 2
=======
debuglevel 1  + LOG_INFO

Level 3
=======
debuglevel 2 + LOG_DEBUG

``option debuglevel '1'``

Firewall Restart hook
*********************

Specific to OpenWrt only, Firewall 4 (FW4) informs openNDS when it is restarting.

If enabled (Set to 1), openNDS reinserts any nftables it may need in the FW4 ruleset.

Default: 1

``option fwhook_enabled '1'``

Ndsctl Socket Access
********************

Set the socket name to use for ndsctl socket access, relative to the tmpfs mountpoint.

Any directory/folder specified must exist.
Default: ndsctl.sock (Do not add a leading "/")

Full default socket path would be /tmp/ndsctl.sock in OpenWrt
In the following example, the socket path would be /tmp/sockets/ndsctl.sock

Example:

``option ndsctlsocket 'sockets/ndsctl.sock'``

Local Log Mountpoint
********************

Default: router's volatile tmpfs storage eg on OpenWrt '/tmp'

Local logging can be directed to any storage accessible to the router eg USB drive, SSD etc

**WARNING** - you should not use the router's built in flash storage as this would cause
excessive wear and in a live system will result quite quickly in flash failure making the router useless.

Example:

``option log_mountpoint '/logs'``

Maximum number of Local Log Entries
***********************************

Set the maximum number of local log entries to be kept.
Default 100

Minimum value 0 (no limit)

Maximum value - limited only by free storage space on the logging mountpoint

If set to '0' there is no limit

This is the maximum number of local log entries allowed before log rotation begins

Both ThemeSpec and BinAuth log locally if they are enabled

**WARNING** - local logging is by default written to the tmpfs volatile storage

If this option were to be set too high the router could run out of tmpfs storage and/or free RAM

Non-volatile storage, such as a USB storage device may be defined using the log_mountpoint option

Example:

``option max_log_entries '1000'``

Login Option
************

Default: 1

Integer value sent to PreAuth script as login mode

openNDS comes preconfigured for three basic modes of operation

Mode 0
======
If FAS is not enabled, then this functions as mode 1

If FAS is configured, FAS is used.

Mode 1
======
Default Dynamic Click to Continue

The pre-installed dynamic login page is enabled by setting option login_option_enabled = '1'

It generates a Click to Continue page followed by an info/advertising page.

User clicks on “Continue” are recorded in the log file /[tmpfs_dir]/ndslog/ndslog.log

Mode 2
======
Username/Emailaddress Dynamic Login

The pre-installed dynamic login page is enabled by setting option login_option_enabled = '2'

It generates a login page asking for username and email address followed by an info/advertising page.

User logins are recorded in the log file /[tmpfs_dir]/ndslog/ndslog.log

Mode 3
======
Use Theme defined in ThemeSpec path (option themespec_path)

`option login_option_enabled '1'`

Allow Preemptive Authentication
*******************************

Default: 1 - Enabled

Disable by setting to 0

This allows the ndsctl utility to preemptively authorise **connected** clients that have not entered the preauthenticated state.

This is useful for example with IoT devices that do not have CPD (captive portal detection)

or for a FAS to manage inter-captive-portal roaming by making use of a centralised database of client validations.

Example:

``option allow_preemptive_authentication '0'``

ThemeSpec Path
**************

Default: None

Required when when login_option_enabled is set to '3'

Note: /usr/lib/opennds/theme_click-to-continue-basic.sh is used for login_option_enabled '1'

and:  /usr/lib/opennds/theme_user-email-login-basic.sh is used for login_option_enabled '2'

Sets the ThemeSpec file path to be used when login_option_enabled '3'

The ThemeSpec script makes use of lists of custom parameters, custom variables, custom image urls and custom files and is used to generate the dynamic splash page sequence.

The ThemeSpec file will normally reside in /usr/lib/opennds/ but can be anywhere accessible to openNDS.

The file must be flagged as executable and have the correct shebang for the default shell.

``option themespec_path '/usr/lib/opennds/<filename>'``

DHCP Leases File
****************

Default: Try /tmp/dhcp.leases, /var/lib/misc/dnsmasq.lease or /var/db/dnsmasq.leases

The file containing the list of active DHCP leases.

Example:

``option dhcp_leases_file '/tmp/dhcp.leases.special'``

Set refresh interval for downloads
**********************************

Set refresh interval for downloaded remote files (in minutes)

Default 0

A setting of 0 (zero) means refresh is disabled.

This is useful for providing automated refreshing of informational or advertising content. Should the remote resources become unavailable, current versions will continue to be used.

Example, set to twelve hours (720 minutes):

``option remotes_refresh_interval '720'``

Use outdated libmicrohttpd (MHD)
********************************

Default 0 (Disabled)

**Warning**: enabling this *may* cause instability or in the worst case total failure - it would be better to upgrade MHD.

**Use at your own risk.**

Older versions of MHD use an older version of the MHD API and may not run correctly or fail.

Older versions of MHD convert & and + characters to spaces when present in form data. This can make a PreAuth or BinAuth impossible to use for a client if form data contains either of these characters eg. in username or password.

*There may well be other issues with older versions.*

MHD versions earlier than 0.9.71 are detected.

If this option is set to 0 (default), NDS will terminate if MHD is earlier than 0.9.71

If this option is set to 1, NDS will attempt to start and log an error.

``option use_outdated_mhd '1'``

Maximum Page Size to be served by MHD
*************************************

Default 10240 bytes

Minimum value 1024 bytes

Maximum - limited only by free RAM in the router

This sets the maximum number of bytes that will be served per page by the MHD web server.

Setting this option is useful:

	1. To reduce memory requirements on a resource constrained router
	2. To allow large pages to be served where memory usage is not a concern

Example:

``option max_page_size '4096'``

Set the MHD WebRoot
*******************

Default: /etc/opennds/htdocs

The local path where the system css file, and other static page content resides.

ie. Serve the file splash.css from this directory

Example:

``option webroot '/etc/opennds/htdocs'``

Set the GatewayInterface
************************

Default: br-lan

Use this option to set the device opennds will bind to.

The value may be an interface section in /etc/config/network or a device name such as br-lan.

The selected interface must be allocated an IPv4 address.

In OpenWrt this is normally br-lan, in generic Linux it might be wlan0

``option gatewayinterface 'br-lan'``

Set the GatewayPort
*******************

Default: 2050

openNDS's own http server (MHD) uses the gateway address as its IP address.

This option sets the port it listens to.

Example:

``option gatewayport '2080'``

Set the GatewayName
*******************

Default: openNDS

gatewayname is used as an identifier for the instance of openNDS

It is displayed on the default splash page sequence for ThemeSpec and the example php scripts.

It is particularly useful in the case of a single remote FAS server that serves multiple openNDS sites, allowing the FAS to customise its response for each site.

Note: The single quote (or apostrophe) character ('), cannot be used in the gatewayname.

If it is required, use the htmlentity &#39; instead.

For example:

``option gatewayname 'Bill's WiFi'`` is invalid.

Instead use:

``option gatewayname 'Bill&#39;s WiFi'``

Example:

``option gatewayname 'OpenWrt openNDS'``

Serial Number Suffix Enable
***************************

Appends a serial number suffix to the gatewayname string.

openNDS constructs a serial number based on the router mac address and adds it to the gatewayname

Default: 1 (enabled)

To disable, set to 0

Example:

``option enable_serial_number_suffix '0'``

Set GatewayFQDN
***************

Default: status.client

This is the simulated FQDN used by a client to access the Client Status Page

If not set, the Status page can be accessed at: http://gatewayaddress:gatewayport/

Warning - if set, services on port 80 of the gateway will no longer be accessible (eg Luci AdminUI)

By default, the Error511/Status page will be found at http://status.client/ by a redirection of port 80 to http://gatewayaddress:gatewayport/

Disable GatewayFQDN by setting the option to 'disable'

ie:

``option gatewayfqdn 'disable'``

Alternate Useful Example:

``option gatewayfqdn 'login.page'``

Set StatusPath
**************

Default: /usr/lib/opennds/client_params.sh

This is the script used to generate the GatewayFQDN client status page.

Example:

.. warning::
 A package upgrade replaces files under /usr/lib/opennds. Copy this script to a path outside /usr/lib/opennds and set statuspath to that copy. You may then safely edit that copy.

``option statuspath '/mycustomscripts/custom_client_params.sh'``

Set MaxClients
**************

Default 250

The maximum number of clients allowed to connect.

**This should be less than or equal to the number of allowed DHCP leases.** set for the router's dhcp server.

Example:

``option maxclients '500'``

Set Fast Client Scan
********************

Default 1 (enabled)

Enables fast client scanning to find the interface used by the client.

Fast scanning skips search for actual wireless interface used.

Any scan delay effects the display rewrite speed of the splash page sequence.

Useful when a large mesh or other extended network is in use.

Otherwise the Client Scan could, for large networks, take many seconds to complete.

For example, to enable:
``option fast_client_scan '0'``

Packet Marking Compatibility
****************************

openNDS uses specific HEXADECIMAL values to mark packets used by nftables as a bitwise mask.

This mask can conflict with the requirements of other packages.

However the defaults are fully compatible with the defaults used in mwan3 and sqm

Any values set here are interpreted as in hex format.

Option: fw_mark_authenticated
=============================

Default: 30000 (0011|0000|0000|0000|0000 binary)

Option: fw_mark_trusted
=======================

Default: 20000 (0010|0000|0000|0000|0000 binary)

Option: fw_mark_blocked (deprecated)
====================================

Default: 10000 (0001|0000|0000|0000|0000 binary)

Examples:

``option fw_mark_authenticated '30000'``

``option fw_mark_trusted '20000'``

``option fw_mark_blocked '10000'``



