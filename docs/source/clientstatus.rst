The Client Status Page
#######################

From version 8.0.0 onwards, openNDS has a Client Status Page.

This page is accessible by any connected client by accessing the default url:

http://status.client

If the client has been authenticated in the normal way by the client CPD process, a page displaying the Gatewayname and the Network Zone the client device is currently using. A list of allowed quotas and current usage is displayed along with "Refresh" and "Logout" buttons.

If the client has not been authenticated, or has been deauthenticated due to timeout or quota usage, then a "Network Authentication Required" page is displayed with "Refresh" and "Portal Login"

The "Portal Login" button allows the client to immediately attempt to login without waiting for the client CPD to trigger.

The URL used to access this page can be changed by setting the config option gatewayfqdn

For best results it is recommended that gatewayfqdn is set to two words separated by a single period eg in OpenWrt:

	`option gatewayfqdn 'my.status'`
