Library Utilities
=================

Overview
********

A number of library utilities are included. These may be used by NDS itself, FAS and Preauth. These may in the future, be enhanced, have additional functionality added.

By default, library utilities will be installed in the folder

``/usr/lib/opennds/``

List of Library Utilities
*************************

get_client_token.sh
###################
This utility allows the unique token of a client to be determined from the client ip address.

It can be used in PreAuth and local FAS scripts.

  Usage: get_client_token.sh [clientip]

  Returns: [client token]

  Where:
    [client token] is the unique client token string.

get_client_interface.sh
#######################
This utility allows the interface a client is using to be determined from the client mac address.

It can be used in PreAuth and local FAS scripts.

It is used by NDS when fas secure levels 1 and 2 are set along with faskey also being set.

Its output is sent to FAS in the encrypted query string as the variable "clientif"

  Usage: get_client_interface.sh [clientmac]

  Returns: [local_interface] [meshnode_mac] [local_mesh_interface]

  Where:

    [local_interface] is the local interface the client is using.

    [meshnode_mac] is the mac address of the 802.11s meshnode the client is using (null if mesh not present).

    [local_mesh_interface] is the local 802.11s interface the client is using (null if mesh not present).

unescape.sh
###########
This utility allows an input string to be unescaped. It currently only supports url-decoding.

It can be used by NDS as the unescape callback for libmicrohttpd.

To enable, set the unescape_callback_enabled option to "1"

To disable, set the unescape_callback_enabled option to "0"

The default is disabled (use internal MHD unescape)

eg In the OpenWrt configuration file

	``option unescape_callback_enabled '0'``

  Usage: unescape.sh [-option] [escapedstring]

  Returns: [unescapedstring]

  Where:

    [-option] is unescape type, currently -url only

libopennds.sh
#############
This utility controls many of the functions required for PreAuth/ThemeSpec scripts.

  Usage: libopennds arg1 arg2 ... argN

    **arg1**: "clean", removes custom files, images and client data

    *returns*: tmpfsmountpoint (the mountpoint of the tmpfs volatile storage of the router.

    **arg1**: "tmpfs", finds the tmpfs mountpoint

    *returns*: tmpfsmountpoint (the mountpoint of the tmpfs volatile storage of the router.

    **arg1**: "mhdcheck", checks if MHD is running (used by MHD watchdog)
    *returns*: "1" if MHD is running, "2" if MHD is not running

    **arg1**: "?fas=<b64string>", generates ThemeSpec html using b64encoded data sent from openNDS

        **arg2**: urlencoded_useragent_string

        **arg3**: mode (1, 2 or 3) (this is the mode specified in option login_option in the config file.

        **arg4**: themespecpath (if mode = 3


    *returns*: html for the specified ThemeSpec.
