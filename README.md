## 0. The openNDS project

openNDS is a Captive Portal solution that offers an instant way to provide restricted access to the Internet.

With little or no configuration, a dynamically generated and adaptive splash page sequence is automatically served.

Internet access is granted by either a click to continue button, or after credential verification.

The package incorporates the FAS API allowing many flexible customisation options.

The creation of sophisticated third party authentication applications is fully supported.

Internet hosted https portals can be utilised to inspire maximum user confidence.

## 1. Overview

**openNDS** is a high performance, small footprint Captive Portal, offering by default a simple restricted Internet connection, yet incorporates an API that allows the creation of sophisticated authentication applications.

**Captive Portal Detection (CPD)**

 All modern mobile devices, most desktop operating systems and most browsers now have a CPD process that automatically issues a port 80 request on connection to a network. openNDS detects this and serves a special "**splash**" web page to the connecting client device.

**Provide simple and immediate public Internet access**

 openNDS provides two pre-installed methods.

 * **Click to Continue**. (*default*) A simple dynamic set of web pages that provide "Click to Continue" login, a welcome page and logging of acceptance by client users.

 * **Username/email-address login**. (*Selectable in the configuration file*) A simple dynamic set of web pages that provide username/email-address login, a welcome page and logging of acceptance by client users.

Customising the page seen by users is a simple matter of editing the relevant script file.

**Write Your Own Captive Portal.**

 openNDS can be used as the "Engine" behind the most sophisticated Captive Portal systems using the tools provided.

 * **Forward Authentication Service (FAS)**. FAS provides pre-authentication user validation in the form of a set of dynamic web pages, typically served by a web service independent of openNDS, located remotely on the Internet, on the local area network or on the openNDS router.
 * **PreAuth**. A special case of FAS that runs locally on the openNDS router with dynamic html served by openNDS itself. This requires none of the overheads of a full FAS implementation and is ideal for openNDS routers with limited RAM and Flash memory.
 * **BinAuth**. A method of running a post authentication script or extension program.


## 2. Documentation

For full documentation please look at https://opennds.rtfd.io/

You can select either *Stable* or *Latest* documentation.

---


