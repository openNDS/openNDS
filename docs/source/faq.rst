Frequently Asked Questions
###########################

What's the difference between v0.9, v1, v2, v3, v4 and v5?
**********************************************************

**v0.9 and v1** are the same codebase with the same feature set.
If the documentation says something about v1, this is usually also valid
for v0.9.

**v2** was developed before version v1 was released. In v2 the http code was replaced by libmicrohttpd and the template engine was rewritten. Many features became defunct because of this procedure.

**v3** cleans up the source code and adds three major new features,

 * **FAS**

   A forwarding authentication service. FAS supports development of "Credential Verification" running on any dynamic web serving platform, on the same device as openNDS, on another device on the local network, or on an Internet hosted web server.

 * **PreAuth**

   An implementation of FAS running on the same device as openNDS and using openNDS's own web server to generate dynamic web pages. Any scripting language or even a compiled application program can be used. This has the advantage of not requiring the resources of a separate web server.

 * **BinAuth**

   Enabling an external script to be called for simple username/password authentication as well as doing post authentication processing such as setting session durations. This is similar to the old binvoucher feature, but more flexible.

 In addition, in v3, the ClientTimeout setting was split into PreauthIdleTimeout and AuthIdleTimeout and for the ClientForceTimeout setting, SessionTimeout is now used instead.

**v4** continues to add enhancements towards improving NDS as a Captive Portal Engine that can be used in the development of custom solutions.

 Three major new features are introduced.

 * **FAS FQDN**

   Enabling simple configuration for a FAS running on a remote shared web hosting server.

 * **FAS secure level 1**

   From v4.3.0 onwards,  FAS secure level 1 supports token hashing. This enhances security and mitigates issues accessing ndsctl remotely to obtain the client token. This is particularly useful on legacy router devices with small flash and ram capacity.


 * **FAS secure level 2**

   Enabling aes256cbc encryption of NDS data transferred to remote FAS, thus preventing knowledgable client users from bypassing verification. Access to the FAS server using **http** protocol is enforced.

**v5** represents the first version of openNDS after forking from NoDogSplash. This split of codebase allows openNDS to continue development as a powerful Captive Portal engine with API to enable sophisticated applications to be developed.

  *NoDogSplash will continue as an optimised, simplistic Captive Portal solution for use on IoT or legacy devices with severe restrictions on available resources.*

 Version 5 introduces many enhancements including major additional functionality:

 * **FAS secure level 3**

   Enabling *https* access to a remote, Internet based FAS server, ensuring the client device does not receive any security warnings or errors. Access to the FAS server using **https** protocol is enforced.

   Level 3 otherwise functions in the same way as level 2 with aes256cbc encryption of NDS data.

 * **Data volume and Rate Quotas**

   Enabling built in *Data Volume* and *Data Rate* quota support. Data volume and data rate quotas can be set globally in the config file. The global values can be overridden on a client by client basis as required.

 * **Introduction of library scripts**

   Numerous library scripts are introduced to simplify development of applications.

Can I update from v0.9 to v1?
*****************************

Updating to v1.0.0 and v1.0.1, this is a very smooth update with full compatibility.

Updating to 1.0.2 requires iptables v1.4.21 or above.

Can I update from v0.9/v1 to v2.0.0?
************************************

You can, if:

* You don't use BinVoucher
* You have iptables v1.4.21 or above


Can I update from v0.9/v1/v2 to v3.0.0?
***************************************

You can, if:

* You don't use BinVoucher
* You have iptables v1.4.21 or above
* You use the new options contained in the version 3 configuration file

Can I update from v0.9/v1/v2/v3 to v4?
**************************************

You can, if:

* You don't use BinVoucher
* You have iptables v1.4.21 or above
* You use the new options contained in the version 4 configuration file

Can I update from v0.9/v1/v2/v3/v4 to v5?
*****************************************

**No.** Nodogsplash must be uninstalled before installing openNDS.

* Previous implementations of FAS/PreAuth and BinAuth should function without modification.

* v4 NoDogSplash config files will be compatible but must be renamed.

* MHD (libmicrohttpd) versions earlier than 0.9.69 are detected, a warning is given and openNDS terminates. A new config option is provided to force openNDS to use an earlier version and can be enabled at the discretion and risk of the installer.

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

 All modern client devices have the built in, industry standard, *Captive Portal Detection (CPD) service*. This is responsible for triggering the captive portal splash/login page.

What is CPD / Captive Portal Detection?
***************************************
CPD (Captive Portal Detection) has evolved as an enhancement to the network manager component included with major Operating Systems (Linux, Android, iOS/macOS, Windows).

 Using a pre-defined port 80 web page (which one gets used depends on the vendor) the network manager will detect the presence of a captive portal hotspot and notify the user. In addition, most major browsers now support CPD.
