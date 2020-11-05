Frequently Asked Questions
###########################

What's the difference between NoDogSplash (all versions), openNDS v5, v6,v7?
****************************************************************************

**NoDogSplash** and openNDS are derived from the same code base. You cannot upgrade from NoDogSplash to openNDS, instead you must first uninstall NodogSplash before installing openNDS.

NoDogSplash is optimised for running on devices with very limited resources and supports only a single *static* templated html splash page.

**openNDS** supports dynamic html splash page generation (at default, still with minimal resource utilisation) and an API to support the coding of sophisticated Captive Portal solutions.

**openNDS v5** This was the first release of openNDS after forking from NoDogsplash. The following enhancements are included:

 * **openNDS API (FAS)**

   A forwarding authentication service. FAS supports development of "Credential Verification" running on any dynamic web serving platform, on the same device as openNDS, on another device on the local network, or on an Internet hosted web server.

 * **PreAuth**

   An implementation of FAS running on the same device as openNDS and using openNDS's own web server to generate dynamic web pages. Any scripting language or even a compiled application program can be used. This has the advantage of not requiring the resources of a separate web server.

 * **BinAuth**

   Enabling an external script to be called for doing post authentication processing such as setting session durations or writing local logs.

 * **Enforce HTTPS option**

   This option enables *https* access to a remote, Internet based FAS server, ensuring the client device does not receive any security warnings or errors. Access to the FAS server using **https** protocol is enforced.

 * **Data volume and Rate Quotas**

   This option enables built in *Data Volume* and *Data Rate* quota support. Data volume and data rate quotas can be set globally in the config file. The global values can be overridden on a client by client basis as required.

 * **Introduction of library scripts**

   Numerous library scripts are introduced to simplify development of applications.


**openNDS v6** This is the first version of openNDS to use the updated libmicrohttpd API introduced with v0.9.71

**openNDS v7** This version contains several major enhancements, including:


 * **Autonomous Walled Garden Support**

   A simple openNDS configuration option enables Autonomous Walled Garden operation based on a list of target FQDNs

 * **Custom Parameter Support**

   A list of static Custom Parameters can be set as a configuration option. Once set, these parameters are fixed and will be sent to remote FAS servers.

   This functionality was added specifically to support remote configuration tools such as Opensync, but can be generally useful for passing local fixed information to a remote FAS.

   It is important that this is NOT confused with the dynamic Custom Variables that can be defined as a part of a FAS/Client dialogue.

Can I upgrade from NoDogSplash to openNDS?
******************************************

No.

You must first uninstall NoDogSplash before installing openNDS.

Can I upgrade from v5 to v6
***************************

Yes, but you will also need to upgrade libmicrohttpd to version v0.9.71 or higher.

Can I upgrade from v6 to v7?
****************************

You can, if:

* You don't use RedirectURL (this has been deprecated for some time as it mostly did not work with client CPD implementations. It has now been removed. A reliable replacement is a FAS Welcome Page.
* You don't use the Templated html splash page (splash.html). Templated splash is now deprecated and disabled. It can be re-enabled by setting the allow_legacy_splash option to allow time for migration. Support will be removed entirely in a later version.

How do I manage client data usage?
**********************************

openNDS (NDS) has built in *Data Volume* and *Data Rate* quota support.

 Data volume and data rate quotas can be set globally in the config file.

 The global values can be overridden on a client by client basis as required.

Can I use Traffic Shaping with openNDS?
***************************************

SQM Scripts (Smart Queue Management), is fully compatible with openNDS and if configured to operate on the openNDS interface (br-lan by default) will provide efficient IP connection based traffic control to ensure fair usage of available bandwidth.

This can be installed as a package on OpenWrt.
For other distributions of Linux it is available at:
https://github.com/tohojo/sqm-scripts

Is an *https splash page* supported?
************************************
**Yes**. FAS Secure Level 3 enforces https protocol for the splash login page on an external FAS server.

Is *https capture* supported?
*****************************
**No**. Because all connections would have a critical certificate failure.

 HTTPS web sites are now more or less a standard and to maintain security and user confidence it is essential that captive portals **DO NOT** attempt to capture port 443.

 All modern client devices have the built in, industry standard, *Captive Portal Detection (CPD) service*. This is responsible for triggering the captive portal splash/login page and is specifically intended to make attempted https capture unnecessary.

What is CPD / Captive Portal Detection?
***************************************
CPD (Captive Portal Detection) has evolved as an enhancement to the network manager component included with major Operating Systems (Linux, Android, iOS/macOS, Windows).

 Using a pre-defined port 80 web page (which one gets used depends on the vendor) the network manager will detect the presence of a captive portal hotspot and notify the user. In addition, most major browsers now support CPD.
