<?php
/* (c) Blue Wave Projects and Services 2015-2021. This software is released under the GNU GPL license.
 This is a FAS script providing an example of remote Forward Authentication for openNDS (NDS) on an http web server supporting PHP.
 The following NDS configurations must be set:
 1. fasport: Set to the port number the remote webserver is using (typically port 80)
 2. faspath: This is the path from the FAS Web Root to the location of this FAS script (not from the file system root).
	eg. /nds/fas-aes-https.php
 3. fasremoteip: The remote IPv4 address of the remote server eg. 46.32.240.41
 4. fasremotefqdn: The fully qualified domain name of the remote web server.
	This is required in the case of a shared web server (ie. a server that hosts multiple domains on a single IP),
	but is optional for a dedicated web server (ie. a server that hosts only a single domain on a single IP).
	eg. onboard-wifi.net
 5. faskey: Matching $key as set in this script (see below this introduction).
	This is a key phrase for NDS to encrypt the query string sent to FAS.
	It can be any combination of A-Z, a-z and 0-9, up to 16 characters with no white space.
	eg 1234567890
 6. fas_secure_enabled:  set to level 3
	The NDS parameters: clientip, clientmac, gatewayname, client token, gatewayaddress, authdir and originurl
	are encrypted using fas_key and passed to FAS in the query string.
	The query string will also contain a randomly generated initialization vector to be used by the FAS for decryption.
	The "php-cli" package and the "php-openssl" module must both be installed for fas_secure level 2.
 openNDS does not have "php-cli" and "php-openssl" as dependencies, but will exit gracefully at runtime if this package and module
 are not installed when fas_secure_enabled is set to level 3.
 The FAS must use the initialisation vector passed with the query string and the pre shared faskey to decrypt the required information.
 The remote web server (that runs this script) must have the "php-openssl" module installed (standard for most hosting services).
 This script requires the client user to enter their Fullname and email address. This information is stored in a log file kept
 in the same folder as this script.
 This script requests the client CPD to display the NDS avatar image directly from Github.
 This script displays an example Terms of Service. You should modify this for your local legal juristiction.
 The script is provided as a fully functional alternative to the basic NDS splash page.
 In its present trivial form it does not do any verification, but serves as an example for customisation projects.
 The script retreives the clientif string sent from NDS and displays it on the login form.
 "clientif" is of the form [client_local_interface] [remote_meshnode_mac] [local_mesh_if]
 The returned values can be used to dynamically modify the login form presented to the client,
 depending on the interface the client is connected to.
 eg. The login form can be different for an ethernet connection, a private wifi, a public wifi or a remote mesh network zone.
*/

// Allow immediate flush to browser
if (ob_get_level()){ob_end_clean();}

//force redirect to secure page
if(empty($_SERVER['HTTPS']) || $_SERVER['HTTPS'] == "off"){
    $redirect = 'https://' . $_SERVER['HTTP_HOST'] . $_SERVER['REQUEST_URI'];
    header('HTTP/1.1 301 Moved Permanently');
    header('Location: ' . $redirect);
    exit();
}

// setup some defaults
date_default_timezone_set("UTC");
$client_zone=$fullname=$email=$invalid="";
$cipher="AES-256-CBC";
$me=$_SERVER['SCRIPT_NAME'];

if (file_exists("/etc/config/opennds")) {
	$logpath="/tmp/";
} elseif (file_exists("/etc/opennds/opennds.conf")) {
	$logpath="/run/";
} else {
	$logpath="";
}

###############################################################################
#
# Set the pre-shared key. This MUST be the same as faskey in the openNDS config
#
$key="1234567890";
#
###############################################################################

#############################################################################################################
#
# Configure Quotas - Time, Data and Data Rate
#
#############################################################################################################
# Set the session length(minutes), upload/download quotas(kBytes), upload/download rates(kbits/s)
# and custom string to be sent to the BinAuth script.
# Upload and download quotas are in kilobytes.
# If a client exceeds its upload or download quota it will be deauthenticated on the next cycle of the client checkinterval.
# (see openNDS config for checkinterval)

# Client Upload and Download Rates are the average rates a client achieves since authentication 
# If a client exceeds its set upload or download rate it will be deauthenticated on the next cycle of the client checkinterval.

# The following variables are set on a client by client basis. If a more sophisticated client credential verification was implemented,
# these variables could be set dynamically.
#
# In addition, choice of the values of these variables can be determined, based on the interface used by the client
# (as identified by the clientif parsed variable). For example, a system with two wireless interfaces such as "members" and "guests". 

# A value of 0 means no limit
$sessionlength=0; // minutes (1440 minutes = 24 hours)
$uploadrate=0; // kbits/sec (500 kilobits/sec = 0.5 Megabits/sec)
$downloadrate=0; // kbits/sec (1000 kilobits/sec = 1.0 Megabits/sec)
$uploadquota=0; // kBytes (500000 kiloBytes = 500 MegaBytes)
$downloadquota=0; // kBytes (1000000 kiloBytes = 1 GigaByte)

#############################################################################################################
#
# Custom string to be sent to Binauth
#
# Define a custom string that will be sent to BunAuth for additional local post authentication processing.
# Binauth is most useful for writing a local log on the openNDS router
$custom="Optional Custom data for BinAuth";

#############################################################################################################
#
# Send The Auth List when requested by openNDS
#
# When a client was verified, their parameters were added to the "auth list"
# The auth list is sent to NDS when it authmon requests it.
#
# auth_get:
#
# value "list" sends the list and deletes each client entry that it finds
#
# value "view" just sends the list, this is the default value for authmon and allows upstream processing here
#
#############################################################################################################

if (isset($_POST["auth_get"])) {

$acklist=base64_decode($_POST["payload"]);

if (isset($_POST["gatewayhash"])) {
	$gatewayhash=$_POST["gatewayhash"];
} else {
	# invalid call, so:
	exit(0);
}

if (! file_exists("$logpath"."$gatewayhash")) {
	# no clients waiting, so:
	exit(0);
}

if ($_POST["auth_get"] == "clear") {
	$auth_list=scandir("$logpath"."$gatewayhash");
	array_shift($auth_list);
	array_shift($auth_list);

	foreach ($auth_list as $client) {
		unlink("$logpath"."$gatewayhash/$client");
	}
	# Stale entries cleared, so:
	exit(0);
}

# Set default empty authlist:
$authlist="*";

if ($_POST["auth_get"] == "list") {
	$auth_list=scandir("$logpath"."$gatewayhash");
	array_shift($auth_list);
	array_shift($auth_list);

	foreach ($auth_list as $client) {
		$clientauth=file("$logpath"."$gatewayhash/$client");
		$authlist=$authlist." ".rawurlencode(trim($clientauth[0]));
		unlink("$logpath"."$gatewayhash/$client");
	}
	echo trim("$authlist");

} else if ($_POST["auth_get"] == "view") {

	if ($acklist != "none") {
		$acklist_r=explode("\n",$acklist);

		foreach ($acklist_r as $client) {
			$client=ltrim($client, "* ");

			if ($client != "") {
				if (file_exists("$logpath"."$gatewayhash/$client")) {
					unlink("$logpath"."$gatewayhash/$client");
				}
			}
		}
		echo "ack";
	} else {
		$auth_list=scandir("$logpath"."$gatewayhash");
		array_shift($auth_list);
		array_shift($auth_list);

		foreach ($auth_list as $client) {
			$clientauth=file("$logpath"."$gatewayhash/$client");
			$authlist=$authlist." ".rawurlencode(trim($clientauth[0]));
		}
	echo trim("$authlist");
	}
}
exit(0);
}



?>