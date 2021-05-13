TODO List
#########

Features should be aimed at providing tools to allow openNDS to be used as flexible Captive Portal engine, rather than building in specific solutions.

Here is a list of things that should be done soon:

* Use uci style config file for all OSes then remove opennds.conf
* Add refresh interval for download of external files in ThemeSpec. This will enable automatic update of informational content, banner advertising etc.
* Consider providing an openNDS-mini package for OpenWrt - for legacy devices with very restricted resources.

Here is a list of possible things TO DO

* Extend Status processing to display a page when a user's authentication is rejected, e.g. because the user exceeded a quota or is blocked etc.
* ip version 6 is not currently supported by NDS. It is not essential or advantageous to have in the short term but should be added at some time in the future.
* Automatic Offline mode/ Built in DNS forwarder. Some thought and discussion has been put into this and it is quite possible to achieve.
