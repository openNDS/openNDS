BinAuth Option
=================

Overview
********

**BinAuth provides a method of running a post authentication script** or extension program. BinAuth is ALWAYS local to NDS and as such will have access to all the resources of the local system.

**BinAuth works with, but does not require FAS** and in a simple system can be used to provide site-wide username/password access.

*BinAuth is available when FAS is used at all levels of fas_secure_enabled (0, 1, 2 and 3).*

**With FAS, a custom variable is forwarded to BinAuth** This can contain an embedded payload of custom data defined by the FAS. As FAS is typically remote from the NDS router, this provides a link to the local system.

**BinAuth has the means to set session timeout, data rate and data volume quotas** on a client by client basis.

**BinAuth is called by NDS at the following times:**

 * After the client CPD browser makes an authentication request to NDS
 * After the client device is granted Internet access by NDS
 * After the client is deauthenticated by request
 * After the client idle timeout interval has expired
 * After the client session timeout interval has expired
 * After a data upload or download quota has been exceeded
 * After the client is authenticated by ndsctl command
 * After the client is deauthenticated by ndsctl command
 * After NDS has received a shutdown command

BinAuth Command Line Arguments
******************************

When OpenNDS calls the configured BinAuth script, it sends a set of command line arguments depending on the reason for the call.

BinAuth Command Methods
-----------------------

The first argument, arg[1], is always the "method".

The method will be set to one of the following values:
 * "**auth_client**" This is a request for authentication by the client.
 * "**client_auth**" This is an acknowledgement of successful authentication by NDS.
 * "**client_deauth**" This is an acknowledgement that the client has been deauthenticated by NDS.
 * "**idle_deauth**" - NDS has deauthenticated the client because the idle timeout duration has been exceeded.
 * "**timeout_deauth**" - NDS has deauthenticated the client because the session length duration has been exceeded.
 * "**downquota_deauth**" - NDS has deauthenticated the client because the client's download quota has been exceeded
 * "**upquota_deauth**" - NDS has deauthenticated the client because the client's upload quota has been exceeded
 * "**ndsctl_auth**" - NDS has authorised the client because of an ndsctl command (most commonly sent by the NDS AuthMon daemon).
 * "**ndsctl_deauth**" - NDS has deauthenticated the client because of an ndsctl command.
 * "**shutdown_deauth**" - NDS has deauthenticated the client because it received a shutdown command.

Additional arguments depend on the method type:

Method auth_client
------------------
The first argument is auth_client and the following arguments are set to:

 * arg[2] = client_mac
 * arg[3] = username
 * arg[4] = password
 * arg[5] = url-escaped redir variable (the URL originally requested by the client.
 * arg[6] = url-escaped client user agent string
 * arg[7] = client_ip
 * arg[8] = client_token
 * arg[9] = url-escaped custom variable string

Method ndsctl_auth
------------------
The first argument is ndsctl_auth and the following arguments are set to:

 * arg[2] = client_mac
 * arg[3] = bytes_incoming (set to 0, reserved for future use)
 * arg[4] = bytes_outgoing (set to 0, reserved for future use)
 * arg[5] = session_start - the session start time 
 * arg[6] = session_end - the session end time
 * arg[7] = client_token
 * arg[8] = url-escaped custom variable string

All Other Methods
-----------------
When the first argument is other than auth_client or ndsctl_auth, the following arguments are set to:

 * arg[2] = client_mac
 * arg[3] = bytes_incoming (total incoming bytes for client)
 * arg[4] = bytes_outgoing (total incoming bytes for client)
 * arg[5] = session_start - the session start time 
 * arg[6] = session_end - the session end time
 * arg[7] = client_token

Using the Custom Variable string
--------------------------------
Method auth_client - arg[9] contains the url-escaped custom variable string. openNDS extracts this variable from the query string of the http auth_client call from a FAS or Templated splash page.

It is provided for general unspecified use and is url-escaped.
A typical example of its use is for a level 0, 1, or 2 FAS to communicate quota values for individual clients, or groups of clients.

Example BinAuth Scripts
***********************
Two example BinAuth scripts are included in the source files available for download at:
https://github.com/opennds/opennds/releases

Both of them are preinstalled and ready to be enabled in the config file.

In addition, the files can be extracted from the downloaded release archive file and reside in the folder:

`/opennds-[*version*]/forward_authentication_service/binauth`

Example 1 - Sitewide Username/Password
**************************************
This example is a script designed to be used with or without FAS and provides site wide Username/Password login for groups of users, in this case "staff", "guest" and "member" with corresponding sets of credentials. If used without FAS, a special html splash page must be installed, otherwise FAS must forward the required username and password variables.

Manual Installation (Example 1)
*******************************
**The binauth_sitewide example is pre-installed.** However, a manual installation is described here by way of example to aid developers in understanding the procedure required for installing their own scripts.
The binauth_sitewide script actually has three components, the binauth script itself, an associated html file and a user database file.

 * binauth_sitewide.sh
 * splash_sitewide.html
 * userlist.dat

The file binauth_sitewide.sh should be copied to a suitable location on the NDS router, eg `/usr/lib/opennds/`

The file splash_sitewide.html should be copied to `/etc/opennds/htdocs/`

The file userlist.dat should be copied to `/etc/opennds/`

Assuming FAS is not being used, NDS is then configured by setting the BinAuth and SplashPage options in the config file (/etc/config/opennds on Openwrt, or /etc/opennds/opennds.conf on other operating systems.

On OpenWrt this is most easily accomplished by issuing the following commands:

    `uci set opennds.@opennds[0].splashpage='splash_sitewide.html'`

    `uci set opennds.@opennds[0].binauth='/usr/lib/opennds/binauth_sitewide.sh'`

    `uci commit opennds`

The script file must be executable and is flagged as such in the source archive. If necessary set using the command:

    `chmod u+x /usr/lib/opennds/binauth_sitewide.sh`

This script is then activated with the command:

    `service opennds restart`


Example 2 - Local NDS Access Log
********************************

This example is a script designed to be used with or without FAS and provides local NDS logging. FAS is often remote from the NDS router and this script provides a simple method of interacting directly with the local NDS. FAS can send custom data to Binauth as a payload in the custom variable parameter that is relayed to BinAuth by NDS.

The log file is stored by default in the /tmp/ndslog/ directory.
This works for many operating systems including OpenWrt.

The location however must be changed on some operating systems, such as Debian and its variants (eg Raspbian). Here a default location of /run/ndslog/ works well.

The log location is simply changed by editing variables at the beginning of the script file.

Free space checking is done and if the log file becomes too large, logging ceases and an error is sent to syslog.

Log files do not persist through a reboot so it would be sensible to change the location of the log file to a USB stick for example.

Using Example 2
***************

**The binauth_log example is pre-installed.**

This script has a single component, the shell script.

 * binauth_log.sh

The file binauth_log.sh is preinstalled in the /usr/lib/opennds directory.

This is enabled by setting the BinAuth option in the config file (/etc/config/opennds on Openwrt, or /etc/opennds/opennds.conf on other operating systems.

This script is then activated with the command:

    `service opennds restart`
