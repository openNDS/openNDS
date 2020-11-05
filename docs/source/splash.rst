The Splash Page
###############

As you will see mentioned in the "How openNDS (NDS) Works" section, an initial port 80 request is generated on a client device, either by the user manually browsing to an http web page, or, more usually, automatically by the client device's built in Captive Portal Detection (CPD).

This request is intercepted by NDS and an html Splash Page is served to the user of the client device to enable them to authenticate and be granted Internet access.

Types of Splash Page
********************

This Splash page can be one of the following:

A Dynamic Web Page served by the built in openNDS web server
------------------------------------------------------------

  A script or executable file is called by openNDS. This script or executable will generate html code for the openNDS web server.

  In openNDS this is called "PreAuth", as openNDS itself serves the splash page as a PRElude to AUTHentication.

  Simple coding in the script enables a dialogue with the client user, for dissemination of information, user response and authentication.

  This is an implementation of Forward Authentication Services **(FAS)**, *without the resource utilisation of a separate web server*, particularly useful for legacy devices with limited flash and RAM capacity.

A Dynamic Web Page served by an independent web server
------------------------------------------------------

 This independent web server can be on the same device as openNDS, on the same Local Area Network as NDS, or on External Web Hosting Services.

 A script or executable file is called by openNDS on the independent web server.

 This has the advantage having the full flexibility of using readily available mainstream web servers, located anywhere, enabling full flexibility in design and implementation of the captive portal functionality, ranging from a self contained system through to a fully integrated multi site system with a common database.

The Pre-Installed Basic Splash Pages
************************************

 By default, the Splash pages consist of a simple click to continue dialogue followed by a Welcome or advertising page. A simple config option allows you to select instead a Name/EmailAddress login dialogue.


 In many instances, one or other of these simple methods will be all that is required, but the power of FAS, PreAuth and BinAuth can be used to create very sophisticated Captive Portal Systems.

The Legacy splash.html Static Web Page
**************************************

The legacy static splash.html page is now deprecated and disabled. It will be removed in later releases.
It can be re-enabled in this release allowing time for migration to the new openNDS API. This is achieved by setting the allow_legacy_splash option in the config file.

Displaying Remote Content
*************************

openNDS provides a simple means of displaying remote content
------------------------------------------------------------

 openNDS can display content from third party web hosting, on the client user login screen.

 This is ideal for serving information, banner advertising etc. when the openNDS device has very limited resources.

 An example is described in the **Displaying Remote Banner Images** section of the PreAuth chapter.

openNDS has built in Walled Garden support
------------------------------------------

 Sophisticated remote content can be served, with access controlled by the openNDS Walled Garden. Simple configuration options can enable such things as a Paypal payment system or access to Facebook resources.

 For details see the Walled Garden Section.
