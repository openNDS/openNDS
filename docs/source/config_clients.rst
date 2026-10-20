Configuration Options - Clients and Timeouts
############################################

Client timeouts in minutes
**************************

Preauthidletimeout
==================

Default 30

This is the time in minutes after which a client is disconnected if not authenticated.

ie the client has not attempted to authenticate for this period.

Example:

``option preauthidletimeout '60'``

Authidletimeout
===============

Default 120

This is the time in minutes after which an idle client is disconnected
ie the client has not used the network access for this period

Example:

``option authidletimeout '60'``

Session Timeout
===============

Default 1440 minutes (24 hours).

This is the interval after which clients are forced out (a value of 0 means never).

Clients will be deauthenticated at the end of this period.

Example: Set to 20 hours (1200 minutes).

``option sessiontimeout '1200'``

Set the Checkinterval
*********************

The interval in seconds at which openNDS checks client timeouts, quota usage and runs watchdog checks.

Default: 15 seconds (one quarter of a minute).

Example: Set to 30 seconds.

``option checkinterval '30'``

Trusted Clients
***************

A list of the MAC addresses of trusted client devices.

Trusted clients are granted immediate and unconditional access and do not require authentication.

Trusted client data usage is not recorded and no quotas or timeouts are applied.

See "Pre-emptive Clients" for conditional access for "trusted" clients.

.. note::
 Be aware that most mobile devices randomise their mac address for each wireless network encountered.

Example:

``list trustedmac '00:00:C0:01:D0:0D'``

``list trustedmac '00:00:C0:01:D0:1D'``

Pre-emptive Clients
*******************

A list of the MAC addresses and access conditions of pre-emptively authenticated client devices.

Unlike Trusted Clients, Pre-emptive clients have their data usage monitored. Quotas and timeouts are applied.

Pre-emptive clients are logged both locally and in remote fas servers in the same way as normal validated clients.

Pre-emptive Authentication must be enabled (default). See "allow_preemptive_authentication".

  Default: Not Set

.. note::
 Be aware that most mobile devices randomise their mac address for each wireless network encountered.

List parameters will be mac, sessiontimeout, uploadrate, downloadrate, uploadquota, downloadquota and custom. The ";" character is used as a parameter separator.

List parameters set to "0" or omitted are set to the global or default value.

Pre-emptive clients are logged both locally and in remote fas servers in the same way as normal validated clients.

Examples:

``list preemptivemac 'mac=00:00:C0:01:D0:01;sessiontimeout=1200;uploadrate=200;downloadrate=0;uploadquota=0;downloadquota=0;custom=custom string for preemptivemac1'``

``list preemptivemac 'mac=00:00:D0:01:D0:02;sessiontimeout=1000;uploadrate=200;downloadrate=800;uploadquota=0;downloadquota=0;custom=custom string for preemptivemac2'``

``list preemptivemac 'mac=00:00:E0:01:D0:03;sessiontimeout=4200;uploadrate=100;downloadrate=0;uploadquota=0;downloadquota=0;custom=custom_string_for_preemptivemac3'``


Dhcp option 114 Enable - RFC8910
********************************

Sends "default_url" (dhcp option 114) with all replies to dhcp requests

Required for RFC8910 Captive Portal Identification

Default 1 (enabled)

To disable, set to 0

Example:

``option dhcp_default_url_enable '0'``
