## 0. The openNDS project

openNDS is a Captive Portal that offers a simple way to provide restricted access to the Internet by showing a splash page to the user before Internet access is granted.

It also incorporates an API that allows the creation of sophisticated authentication applications.

It was derived originally from the codebase of the NoDogSplash project.

openNDS is released under the GNU General Public License.

The following describes what openNDS does, how to get it and run it, and
how to customize its behaviour for your application.

## 1. Overview

**openNDS** is a high performance, small footprint Captive Portal, offering by default a simple splash page restricted Internet connection, yet incorporates an API that allows the creation of sophisticated authentication applications.

**Captive Portal Detection (CPD)**

 All modern mobile devices, most desktop operating systems and most browsers now have a CPD process that automatically issues a port 80 request on connection to a network. openNDS detects this and serves a special "**splash**" web page to the connecting client device.

**Provide simple and immediate public Internet access**

 openNDS provides two pre-installed methods.

 * **Click to Continue**. A simple static web page with template variables (*default*). This provides basic notification and a simple click/tap to continue button.
 * **Username/email-address login**. A simple dynamic set of web pages that provide username/email-address login, a welcome page and logs access by client users. (*Installed by default and enabled by a single entry in the configuration file*)

Customising the page seen by users is a simple matter of editing the respective html or script files.

**Write Your Own Captive Portal.**

 openNDS can be used as the "Engine" behind the most sophisticated Captive Portal systems using the tools provided.

 * **Forward Authentication Service (FAS)**. FAS provides pre-authentication user validation in the form of a set of dynamic web pages, typically served by a web service independent of openNDS, located remotely on the Internet, on the local area network or on the openNDS router.
 * **PreAuth**. A special case of FAS that runs locally on the openNDS router with dynamic html served by openNDS itself. This requires none of the overheads of a full FAS implementation and is ideal for openNDS routers with limited RAM and Flash memory.
 * **BinAuth**. A method of running a post authentication script or extension program.


## 2. Documentation

For full documentation please look at https://openndsdocs.rtfd.io/

You can select either *Stable* or *Latest* documentation.

---


