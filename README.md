## 0. The openNDS project

openNDS is a Captive Portal solution that offers an instant way to provide restricted access to the Internet.

With little or no configuration, a dynamically generated and adaptive splash page sequence is automatically served. Internet access is granted by either a click to continue button, or after credential verification.

The package incorporates the FAS API allowing many flexible customisation options. The creation of sophisticated third party authentication applications is fully supported.

Internet hosted **https portals** can be utilised to inspire maximum user confidence.

## 1. Overview

**openNDS** is a high performance, small footprint Captive Portal, offering by default a simple restricted Internet connection, yet incorporates an API that allows the creation of sophisticated authentication applications.

## 2. Captive Portal Detection (CPD)

 All modern mobile devices, most desktop operating systems and most browsers now have a CPD process that automatically issues a port 80 request on connection to a network. openNDS detects this and serves a special "**splash**" web page sequence to the connecting client device.

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


