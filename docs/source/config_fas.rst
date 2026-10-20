Configuration Options - BinAuth and FAS
#######################################

Enable BinAuth Support.
***********************

Default: Enabled

BinAuth enables POST AUTHENTICATION PROCESSING and and is useful in particular when a FAS is configured remotely.

The default binauth script is used to generate a client authentication database that is used for pre-emptive re-authentication.

The BinAuth program or script is triggered by several possible methods and is called with several arguments on both authentication and deauthentication.

Possible methods
================

Authentication:

	"auth_client": Request for authentication received from the captive portal splash page.

	"client_auth": Acknowledgement that Client was authenticated via this script.

	"ndsctl_auth": Client was authenticated by ndsctl auth command.

Deauthentication:

	"client_deauth": Client deauthenticated by the client via captive portal splash page.

	"idle_deauth": Client was deauthenticated because of inactivity.

	"timeout_deauth": Client was deauthenticated because the session timed out.

	"ndsctl_deauth": Client was deauthenticated by ndsctl deauth command.

	"uprate_deauth": Client was deauthenticated because its average upload rate exceeded the allowed value.

	"downrate_deauth": Client was deauthenticated because its average download rate exceeded the allowed value.

	"upquota_deauth": Client was deauthenticated because its upload quota exceeded the allowed value.

	"downquota_deauth": Client was deauthenticated because its download quota exceeded the allowed value.

	"shutdown_deauth": Client was deauthenticated by openNDS terminating.

A fully functional BinAuth script is pre-installed and provides local logging of client activity.

This is enabled by the following option:

``option binauth '/usr/lib/opennds/binauth_log.sh'``

Set CustomBinAuth
*****************

Default: /usr/lib/opennds/custombinauth.sh

The default BinAuth script calls this custom script so that you can add your own local policy.

.. warning::
 A package upgrade replaces files under /usr/lib/opennds. Do not edit /usr/lib/opennds/custombinauth.sh in place. Copy it to a path outside /usr/lib/opennds, edit the copy and set custombinauth to that copy.

Example:

``option custombinauth '/mycustomscripts/custombinauth.sh'``

Set reauth_interval
*******************

Set the interval in seconds after which a deauthed client can log back in again.

Default: Not set, meaning a deauthed client can log back in immediately.

If set to 0, this is the equivalent of not set.

Example, disallow re-authentication for 10 minutes (600 seconds):

``option reauth_interval '600'``

Set Fasport
***********

Default: Not set.

This is the Forwarding Authentication Service (FAS) port number.

Redirection is changed to the IP port of a FAS (provided by the system administrator).

.. note::
 If FAS is running locally (ie fasremoteip is NOT set), port 80 cannot be used.

Typical Remote Shared Hosting Example:

``option fasport '80'``

Typical Locally Hosted example (ie fasremoteip not set):

``option fasport '2090'``

Set Fasremotefqdn
*****************

Default: Not set.

If set, this is the remote fully qualified domain name (FQDN) of the FAS.

The protocol must NOT be prepended to the FQDN (ie http:// or https://).

To prevent CPD or browser security errors NDS prepends the required http:// or https:// before redirection, depending upon the fas_secure_enabled option.

If set, DNS MUST resolve fasremotefqdn to be the same ip address as fasremoteip.

Remote Shared Hosting
=====================

Typical Remote Shared Hosting Example (replace this with your own FAS FQDN):

``option fasremotefqdn 'onboard-wifi.net'``

CDN (Content Delivery Network) hosted server
============================================

For a CDN (Content Delivery Network) hosted server, the configuration is the same as for Remote Shared Hosting but fasremotefqdn must also be added to the Walled Garden list of FQDNs

Set the Fasremoteip
*******************

Default: GatewayAddress (the IP of NDS)

If set, this is the remote ip address of the FAS.

Typical Remote Shared Hosting Example (replace this with your own remote FAS IP):

``option fasremoteip '46.32.240.41'``

Set the Faspath
***************

Default: /

This is the path from the FAS Web Root to the FAS login page (not the file system root).

In the following examples, replace with your own values for faspath:

	Typical Remote Shared Hosting Example (if fasremotefqdn is not specified):

		``option faspath '/remote_host_fqdn/fas/fas-hid.php'``

	Typical Remote Shared Hosting Example (ie BOTH fasremoteip AND fasremotefqdn set):

		``option faspath '/fas/fas-hid.php'``

	Typical Locally Hosted Example (ie fasremoteip not set):

		``option faspath '/fas/fas-hid.php'``

Set the Faskey
**************

Default: A system generated sha256 string

A key phrase for NDS to encrypt the query string sent to FAS.

Can be any text string with no white space.

Hint and Example: Choose a secret string and use sha256sum utility to generate a hash.

eg. Use the command - `echo "mysecretopenNDSfaskey" | sha256sum`

Option faskey must be pre-shared with FAS. (It is automatically pre-shared with Themespec files)

``option faskey '328411b33fe55127421fa394995711658526ed47d0affad3fe56a0b3930c8689'``

Set Security Level: fas_secure_enabled
**************************************

Default: 1

Level set to "0"
================
	* The FAS is enforced by NDS to use http protocol.

	* The client token is sent to the FAS in clear text in the query string of the redirect along with authaction and redir.

	Note: This level is insecure and can be easily bypassed

Level set to "1"
================
	* The FAS is enforced by NDS to use http protocol.
	* The client token will be hashed and sent to the FAS along with other relevant information in a base 64 encoded string

	FAS must return the sha256sum of the concatenation of hid (the hashed original token), and faskey to be used by openNDS for client authentication.

Level set to "2"
================
	* The FAS is enforced by NDS to use http protocol.

	* The parameters clientip, clientmac, gatewayname, hid(the hashed original token), gatewayaddress, authdir, originurl and clientif

	* are encrypted using faskey and passed to FAS in the query string.

	* The query string will also contain a randomly generated initialization vector to be used by the FAS for decryption.

	* The cipher used is "AES-256-CBC".

	* The "php-cli" package and the "php-openssl" module must both be installed for fas_secure level 2 and 3. openNDS does not depend on this package and module, but will exit gracefully not installed when this level is set.

	* The FAS must use the query string passed initialisation vector and the pre shared fas_key to decrypt the query string.

An example FAS level 2 php script (fas-aes.php) is included in the /etc/opennds directory and also supplied in the source code.

Level set to "3"
================
	* The FAS is enforced by NDS to use https protocol.

	* Level 3 is the same as level 2 except the use of https protocol is enforced for FAS.

	* In addition, the "authmon" daemon is loaded.

	* Level 3 allows the external FAS, after client verification, to effectively traverse inbound firewalls and address translation to achieve NDS authentication without generating browser security warnings or errors.

An example FAS level 3 php script (fas-aes-https.php) is included in the /etc/opennds directory and also supplied in the source code.

Note: Option faskey must be pre shared with the FAS script in use (including any ThemeSpec local file) if fas secure is set to levels 1, 2 and 3.

Example:

``option fas_secure_enabled '3'``

Set NAT Traversal Poll Interval
*******************************

Sets the polling interval for NAT Traversal in seconds

Default 10 seconds

Allowed values between 1 and 60 seconds inclusive

Defaults to 10 seconds if set outside this range

Effective only when option fas_secure_enabled is set to 3

Example:

``option nat_traversal_poll_interval '5'``
