The Client Status/Error511 Page
###############################

If the client is redirected by the CPI (RFC 8910) process, this page is displayed.

This page is also accessible by any connected client at the default url:

http://status.client

Default "Quick Status" and optional "Advanced Status" options can be selected.

If the client has been authenticated in the normal way by the client CPD process, a page is served displaying the Gatewayname and the Network Zone the client device is currently using.

A list of allowed quotas and current usage is displayed along with "Refresh" and "Logout" buttons.

If the client has not been authenticated, or has been deauthenticated due to timeout or quota usage, then a "*Error 511 Network Authentication Required*" page is displayed with "Refresh" and "Portal Login" buttons.

The "Portal Login" button allows the client to immediately attempt to login without waiting for the client CPD to trigger.

The URL used to access this page can be changed by setting the config option gatewayfqdn.

For best results it is recommended that gatewayfqdn is set to two words separated by a single period eg in OpenWrt:

	``option gatewayfqdn 'my.status'``

 **Warning** - if set, services on port 80 of the gateway will no longer be accessible (eg Luci AdminUI)

 By default, the Error511/Status page will be found at ``http://status.client/`` by a redirection of port 80 to ``http://gatewayaddress:gatewayport/``

 ***Disable GatewayFQDN*** by setting the option to 'disable'
 ie:

 ``option gatewayfqdn 'disable'``

An alternate Useful Example:

``option gatewayfqdn 'login.page'``

Custom Status Page
******************
The default  client status page is generated dynamically by the script /usr/lib/opennds/client_params.sh

An alternate Status page script can be used by setting the configuration option "statuspath" in the config file. Ensure the alternate script file is flagged as executable.