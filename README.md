## 0. The openNDS project

openNDS is a Captive Portal solution that offers an instant way to provide restricted access to the Internet.

With little or no configuration, a dynamically generated and adaptive splash page sequence is automatically served. Internet access is granted by either a click to continue button, or after credential verification.

The package incorporates the FAS API allowing many flexible customisation options. The creation of sophisticated third party authentication applications is fully supported.

Internet hosted **https portals** can be implemented with no security errors, to inspire maximum user confidence.

## 1. Overview

**openNDS** is a high performance, small footprint Captive Portal, offering by default a simple restricted Internet connection, yet incorporates a comprehensive API that allows the creation of sophisticated authentication applications.

## 2. Captive Portal Detection (CPD) and Captive Portal Identification (CPI)

**2.1 CPD**

Captive Portal Detection (CPD) is a client driven process available on all modern mobile devices, most desktop operating systems and most browsers. The CPD process automatically issues a port 80 request on connection to a network as a means of probing for a captive state.

Sometimes known as a "canary test", this process, driven by the client, has evolved over a number of years to be a reliable de-facto standard.
openNDS detects this probing and serves a special "**splash**" web page sequence to the connecting client device.

**2.2 CPI  - RFC 8910 and RFC 8908**

Captive Portal Identification (CPI) is a Gateway driven process as defined in standards RFC8910 (Captive-Portal Identification in DHCP and Router Advertisements) and RFC8908 (Captive Portal API).

A gateway router informs a connecting client that it is in a captive state by providing a url at which a client can access for authentication.

A client may access this url to be served the same portal "**splash**" page sequence as it would have in the traditional CPD method.

Alternatively, a client may use this url to access the RFC8908 Captive Portal API, ultimately being served a splash page sequence for authentication.

From openNDS v9.5.0, The CPI method is supported in both forms and enabled by default. It can be disabled as a config option.

**Note:** Very few client devices support CPI at the time of writing (November 2021)

## 3. Zero Configuration Click to Continue Default

Immediately after installing, a simple three stage dynamic html splash page sequence is served to connecting clients. Client logins are recorded in a log.

 * The first page asks the user to accept the portal Terms of Service.
 * The second page welcomes the user.
 * Depending on the client device CPD implementation, a third page may be displayed. It confirms the user has access to the Internet.

## 4. Username/Email-address Login Default. (*Enabled in the configuration file*)

Very similar to the Click to Continue default, this option has an initial "login page" that presents a form to the user where they must enter a name and email address.

## 5. Customisation

Many methods of customising openNDS exist:

 * **simple changes to content** using basic html and css edits.
 * **theme specifications** allowing full control of look and feel with the option of configuration defined form fields generating dynamic html.
 * **full third party development** where openNDS is used as the "Engine" behind the most sophisticated Captive Portal systems.

## 6. The Portal

The portal component of openNDS is its **Forward Authentication Service (FAS)**.

FAS provides user validation/authentication in the form of a set of dynamic web pages.

These web pages may be served by openNDS itself, or served by a third party web server. The third party web server may be located remotely on the Internet, on the local area network or on the openNDS router.

The default "Click to continue" and "Username/Email-address Login" options are examples where openNDS serves the splash page sequence itself.

## 7. Documentation

For full documentation please see https://opennds.rtfd.io/

You can select either *Stable*, *Latest* or the historical documentation of *older versions*.

---


