#!/bin/sh
#Copyright (C) The openNDS Contributors 2004-2020
#Copyright (C) BlueWave Projects and Services 2015-2020
#This software is released under the GNU GPL license.
#
# Warning - shebang sh is for compatibliity with busybox ash (eg on OpenWrt)
# This is changed to bash automatically by Makefile for generic Linux
#

# In this example script we want to either ask the client user for
# their username and email address or to give them a click to continue button.
# An option to display a remote image is also supported.
#
# Splash page modes are selected in the openNDS config using the login_option_enabled parameter.
#
# Mode 0. login_option_enabled set to 0 - generate a simple "click to continue" splash page (with Terms of Service).

# Mode 1. login_option_enabled set to 1 - generate a "username/email_address splash page (with Terms of Service).

# Some programming hints are included at the end of this file.


# functions:
wait_for_ndsctl () {
	local lockfile="/tmp/ndsctl.lock"
	local timeout=10
	for tic in $(seq $timeout); do

		if [ ! -f "$lockfile" ]; then
			break
		fi

		sleep 1

		if [ $tic == $timeout ] ; then
			break
		fi

	done
}


get_arguments() {
	# Get the query-string, user_agent and mode
	query_enc=$1
	frag="="
	query=""
	i=9
	query_enc_type=${query_enc:0:9}
	fas=${query_enc:9:1024}
	while true; do
		frag=${query_enc:$i:336}

		if [ -z "$frag" ]; then
			break
		fi
		frag=$(printf "${frag//%/\\x}")
echo "b64frag=$frag<br><br>"
		wait_for_ndsctl
		frag=$(ndsctl b64decode $frag)
echo "frag=$frag<br><br>"
		query="$frag"
		parse_variables
		i=$((i+272))
	done

	user_agent_enc="$2"
	mode="$3"

	# Arguments may be sent to us from NDS in a urlencoded form,
	# we can decode an argument as follows:
	# arg[N]=$(printf "${arg[N]_enc//%/\\x}")

	# The User Agent argument is sent urlencoded, so:
	user_agent=$(printf "${user_agent_enc//%/\\x}")

	# Parse for the variables returned by NDS in the querystring argument:
	#parse_variables

	#Check if we parsed the client zone, if not, get it
	get_client_zone

	# URL decode and htmlentity encode vars that need it:
	gatewayname=$(printf "${gatewayname//%/\\x}")

	htmlentityencode "$gatewayname"
	gatewaynamehtml=$entityencoded

	username=$(printf "${username//%/\\x}")
	htmlentityencode "$username"
	usernamehtml=$entityencoded

	emailaddr=$(printf "${emailaddr//%/\\x}")

	#requested might have trailing comma space separated, user defined parameters - so remove them as well as decoding
	requested=$(printf "${redir//%/\\x}" | awk -F ', ' '{print $1}')

	if [ "$status" = "authenticated" ]; then
		gatewaynamehtml="Welcome"
	fi
}

parse_variables() {
	# Parse for the variables returned by NDS:
	queryvarlist="clientip clientmac gatewayname hid gatewayaddress gatewaymac authdir originurl clientif admin_email location"
	for var in $queryvarlist; do
		evalstr=$(echo "$query" | awk -F"$var=" '{print $2}' | awk -F', ' '{print $1}')
echo "$var=$evalstr!!<br>"
		if [ -z "$evalstr" ]; then
			continue
		fi

		eval $var=$(echo "\"$evalstr\"")
	done

echo "$clientip!!<br>$clientmac!!<br>$gatewayname!!<br>$hid!!<br>$gatewayaddress!!<br>$gatewaymac!!<br>$authdir!!<br>$originurl!!<br>$clientif!!<br>$admin_email!!<br>$location"

}

#parse_variables() {
#	# Parse for the variables returned by NDS:
#	queryvarlist="clientip gatewayname hid status redir username emailaddr client_zone terms continue"
#	for var in $queryvarlist; do
#		parsestr=$(echo "$query_enc" | awk -F "%20$var%3d" '{print $2}' | awk -F "%3d" '{print $1}')
#		evalstr=$(echo "$parsestr" | awk -F "%2c%20" '{
#			if (NF>2) {
#				for(i=1;i<NF;i++) {
#					if (i==1) {
#						printf("%s", $(i))
#					} else {
#						printf("%%2c%%20%s", $(i))
#					}
#				}
#			} else {
#				printf("%s", $(1))
#			}
#		}')
#		eval $var=$(echo "\"$evalstr\"")
#	done
#}

configure_log_location() {
	# Generate the Logfile location; use the tmpfs "temporary" directory to prevent flash wear.
	# Alternately you may choose to manually override the settings generated here.
	# For example mount a USB storage device and manually set logdir and logname instead of this code
	#
	# DEFAULT Location depends upon OS distro in use:
	tempdir="/tmp /run /var"
	mountpoint=""
	logdir="/tmp/ndslog/"
	logname="ndslog.log"

	for var in $tempdir; do
		_mountpoint=$(df | awk -F ' ' '$1=="tmpfs" && $6=="'$var'" {print $6}')
		if [ "$_mountpoint" = "$var" ]; then
			mountpoint="$var"
			logdir="$mountpoint/ndslog/"
			break
		fi
	done

	#For syslog
	ndspid=$(pgrep '/usr/bin/opennds')
}


read_terms() {
	#terms of service button
	echo "
		<form action=\"/opennds_preauth/\" method=\"get\">
			<input type=\"hidden\" name=\"fas\" value=\"$fas\">
			<input type=\"hidden\" name=\"terms\" value=\"yes\">
			<input type=\"submit\" value=\"Read Terms of Service   \" >
		</form>
	"
}

check_authenticated() {
	if [ "$status" = "authenticated" ]; then
		echo "
			<p>
				<big-red>
					You are already logged in and have access to the Internet.
				</big-red>
			</p>
			<hr>
			<p>
				<italic-black>
					You can use your Browser, Email and other network Apps as you normally would.
				</italic-black>
			</p>
		"
		footer
		exit 0
	fi
}

name_email_login() {
	# For this simple example, we check that both the username and email address fields have been filled in.
	# If not then serve the initial page, again if necessary.
	# We are not doing any specific validation in this example, but here is the place to do it if you need to.
	#
	# Note if only one of username or email address fields is entered then that value will be preserved
	# and displayed on the page when it is re-served.
	#
	# Note also $clientip, $gatewayname and $requested (redir) must always be preserved
	#

	if [ ! -z "$username" ] && [ ! -z "$emailaddr" ]; then
		thankyou_page
		footer
		exit 0
	fi

	login_form

	footer
	exit 0
}

click_to_continue() {
	# Note $clientip, $gatewayname and $requested (redir) must always be preserved
	#


	if [ "$continue" = "clicked" ]; then
		thankyou_page
		footer
		exit 0
	fi

	continue_form

	footer
	exit 0
}

header() {
# Define a common header html for every page served
	header="<!DOCTYPE html>
		<html>
		<head>
		<meta http-equiv=\"Cache-Control\" content=\"no-cache, no-store, must-revalidate\">
		<meta http-equiv=\"Pragma\" content=\"no-cache\">
		<meta http-equiv=\"Expires\" content=\"0\">
		<meta charset=\"utf-8\">
		<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
		<link rel=\"shortcut icon\" href=\"/images/splash.jpg\" type=\"image/x-icon\">
		<link rel=\"stylesheet\" type=\"text/css\" href=\"/splash.css\">
		<title>$gatewaynamehtml</title>
		</head>
		<body>
		<div class=\"offset\">
		<med-blue>
			$gatewaynamehtml <br>
			$client_zone
		</med-blue><br>
		<div class=\"insert\" style=\"max-width:100%;\">
	"
	echo "$header"
}

footer() {
	# Define a common footer html for every page served (with openNDS version on the thankyou page)

	footer="
		<img style=\"height:30px; width:60px; float:left;\" src=\"/images/splash.jpg\" alt=\"Splash Page: For access to the Internet.\">

		<copy-right>
			<br><br>
			openNDS $version
		</copy-right>
		</div>
		</div>
		</body>
		</html>
	"
	echo "$footer"
}

login_form() {
	# Define a login form
	login_form="
		<big-red>Welcome!</big-red><br>
		<italic-black>
			To access the Internet you must enter your full name and email address then Accept the Terms of Service to proceed.
		</italic-black>
		<hr>
		<form action=\"/opennds_preauth/\" method=\"get\">
			<input type=\"hidden\" name=\"fas\" value=\"$fas\">
			<input type=\"text\" name=\"username\" value=\"$usernamehtml\" autocomplete=\"on\" ><br>Name<br><br>
			<input type=\"email\" name=\"emailaddr\" value=\"$emailaddr\" autocomplete=\"on\" ><br>Email<br><br>
			<input type=\"submit\" value=\"Accept Terms of Service\" >
		</form>
		<br>
	"
	echo "$login_form"
	read_terms
	echo "<hr>"
}

continue_form() {
	# Define a click to Continue form
	continue_form="
		<big-red>Welcome!</big-red><br>
		<med-blue>You are connected to $client_zone</med-blue><br>
		<italic-black>
			To access the Internet you must Accept the Terms of Service.
		</italic-black>
		<hr>
		<form action=\"/opennds_preauth/\" method=\"get\">
			<input type=\"hidden\" name=\"fas\" value=\"$fas\">
			<input type=\"hidden\" name=\"continue\" value=\"clicked\">
			<input type=\"submit\" value=\"Accept Terms of Service\" >
		</form>
		<br>
	"
	echo "$continue_form"
	read_terms
	echo "<hr>"
}

display_terms() {
	# This is the all important "Terms of service"
	# Edit this long winded generic version to suit your requirements.
	####
	# WARNING #
	# It is your responsibility to ensure these "Terms of Service" are compliant with the REGULATIONS and LAWS of your Country or State.
	# In most locations, a Privacy Statement is an essential part of the Terms of Service.
	####

	#Privacy
	echo "
		<b style=\"color:red;\">Privacy.</b><br>
		<b>
			By logging in to the system, you grant your permission for this system to store any data you provide for
			the purposes of logging in, along with the networking parameters of your device that the system requires to function.<br>
			All information is stored for your convenience and for the protection of both yourself and us.<br>
			All information collected by this system is stored in a secure manner and is not accessible by third parties.<br>
			In return, we grant you FREE Internet access.
		</b><hr>
	"

	# Terms of Service
	echo "
		<b style=\"color:red;\">Terms of Service for this Hotspot.</b> <br>

		<b>Access is granted on a basis of trust that you will NOT misuse or abuse that access in any way.</b><hr>

		<b>Please scroll down to read the Terms of Service in full or click the Continue button to return to the Acceptance Page</b>

		<form>
			<input type=\"button\" VALUE=\"Continue\" onClick=\"history.go(-1);return true;\">
		</form>
	"

	# Proper Use
	echo "
		<hr>
		<b>Proper Use</b>

		<p>
			This Hotspot provides a wireless network that allows you to connect to the Internet. <br>
			<b>Use of this Internet connection is provided in return for your FULL acceptance of these Terms Of Service.</b>
		</p>

		<p>
			<b>You agree</b> that you are responsible for providing security measures that are suited for your intended use of the Service.
			For example, you shall take full responsibility for taking adequate measures to safeguard your data from loss.
		</p>

		<p>
			While the Hotspot uses commercially reasonable efforts to provide a secure service,
			the effectiveness of those efforts cannot be guaranteed.
		</p>

		<p>
			<b>You may</b> use the technology provided to you by this Hotspot for the sole purpose
			of using the Service as described here.
			You must immediately notify the Owner of any unauthorized use of the Service or any other security breach.<br><br>
			We will give you an IP address each time you access the Hotspot, and it may change.
			<br>
			<b>You shall not</b> program any other IP or MAC address into your device that accesses the Hotspot.
			You may not use the Service for any other reason, including reselling any aspect of the Service.
			Other examples of improper activities include, without limitation:
		</p>

			<ol>
				<li>
					downloading or uploading such large volumes of data that the performance of the Service becomes
					noticeably degraded for other users for a significant period;
				</li>

				<li>
					attempting to break security, access, tamper with or use any unauthorized areas of the Service;
				</li>

				<li>
					removing any copyright, trademark or other proprietary rights notices contained in or on the Service;
				</li>

				<li>
					attempting to collect or maintain any information about other users of the Service
					(including usernames and/or email addresses) or other third parties for unauthorized purposes;
				</li>

				<li>
					logging onto the Service under false or fraudulent pretenses;
				</li>

				<li>
					creating or transmitting unwanted electronic communications such as SPAM or chain letters to other users
					or otherwise interfering with other user's enjoyment of the service;
				</li>

				<li>
					transmitting any viruses, worms, defects, Trojan Horses or other items of a destructive nature; or
				</li>

				<li>
					using the Service for any unlawful, harassing, abusive, criminal or fraudulent purpose.
				</li>
			</ol>
	"

	# Content Disclaimer
	echo "
		<hr>
		<b>Content Disclaimer</b>

		<p>
			The Hotspot Owners do not control and are not responsible for data, content, services, or products
			that are accessed or downloaded through the Service.
			The Owners may, but are not obliged to, block data transmissions to protect the Owner and the Public.
		</p>

		The Owners, their suppliers and their licensors expressly disclaim to the fullest extent permitted by law,
		all express, implied, and statutary warranties, including, without limitation, the warranties of merchantability
		or fitness for a particular purpose.
		<br><br>
		The Owners, their suppliers and their licensors expressly disclaim to the fullest extent permitted by law
		any liability for infringement of proprietory rights and/or infringement of Copyright by any user of the system.
		Login details and device identities may be stored and be used as evidence in a Court of Law against such users.
		<br>
	"

	# Limitation of Liability
	echo "

		<hr><b>Limitation of Liability</b>

		<p>
			Under no circumstances shall the Owners, their suppliers or their licensors be liable to any user or
			any third party on account of that party's use or misuse of or reliance on the Service.
		</p>

		<hr><b>Changes to Terms of Service and Termination</b>

		<p>
			We may modify or terminate the Service and these Terms of Service and any accompanying policies,
			for any reason, and without notice, including the right to terminate with or without notice,
			without liability to you, any user or any third party. Please review these Terms of Service
			from time to time so that you will be apprised of any changes.
		</p>

		<p>
			We reserve the right to terminate your use of the Service, for any reason, and without notice.
			Upon any such termination, any and all rights granted to you by this Hotspot Owner shall terminate.
		</p>
	"

	# Indemnity
	echo "
		<hr><b>Indemnity</b>

		<p>
			<b>You agree</b> to hold harmless and indemnify the Owners of this Hotspot,
			their suppliers and licensors from and against any third party claim arising from
			or in any way related to your use of the Service, including any liability or expense arising from all claims,
			losses, damages (actual and consequential), suits, judgments, litigation costs and legal fees, of every kind and nature.
		</p>

		<hr>
		<form>
			<input type=\"button\" VALUE=\"Continue\" onClick=\"history.go(-1);return true;\">
		</form>
		<hr>
	"
	footer
	exit 0
}


thankyou_page () {
	# If we got here, we have both the username and emailaddr fields as completed on the login page on the client,
	# or Continue has been clicked on the "Click to Continue" page
	# so we will now call ndsctl to get client data we need to authenticate and add to our log.

	# Variables returned from ndsctl are listed in $varlist.

	# We at least need the client token to authenticate.
	# In this example we will also log the client mac address.

	# varlist is a list of variables we might be interested in
	varlist="version mac ip clientif session_start session_end last_active token state
		upload_rate_limit download_rate_limit upload_quota download_quota
		upload_this_session upload_session_avg download_this_session download_session_avg"

	clientinfo=$(ndsctl json $clientip)

	if [ "$clientinfo" = "ndsctl is locked by another process" ]; then
		echo "
			<big-red>
				Sorry
			</big-red>
			<italic-black>
				The portal is busy, please try again.
			</italic-black>
			<hr>
		"

		if [ $mode -eq 0 ]; then
			continue_form
		elif [ $mode -eq 1 ]; then
			login_form
		fi

		footer
		exit 0
	else
		# Populate varlist with client data:
		for var in $varlist; do
			eval $var=$(echo "$clientinfo" | grep $var | awk -F'"' '{print $4}')
		done
	fi

	# For openNDS auth we need from varlist:
	tok=$token
	clientmac=$mac

	# You can choose to send a custom data string to BinAuth. Set the variable $custom to the desired value
	# OR uncomment the text input in the displayed form to get input from the client
	# Max length 256 characters

	custom=""

	# We now output the "Thankyou page" with a "Continue" button.

	# This is the place to include information or advertising on this page,
	# as this page will stay open until the client user taps or clicks "Continue"

	# Be aware that many devices will close the login browser as soon as
	# the client user continues, so now is the time to deliver your message.

	echo "
		<big-red>
			Thankyou for using this service
		</big-red>
		<br>
		<b>
			Welcome $usernamehtml
		</b>
	"

	# Add your message here:
	# You could retrieve text or images from a remote server using wget or curl
	# as this router has Internet access whilst the client device does not (yet).
	echo "
		<br>
		<italic-black>
			Your News or Advertising could be here, contact the owners of this Hotspot to find out how!
		</italic-black>
	"

	# Now display the next form
	echo "
		<form action=\"/opennds_auth/\" method=\"get\">
			<input type=\"hidden\" name=\"tok\" value=\"$tok\">
			<input type=\"hidden\" name=\"redir\" value=\"$requested\"><br>
	"

	# Uncomment the next line to request a custom string input from the client and forward it to BinAuth
	#echo "<input type=\"text\" name=\"custom\" value=\"$custom\" required><br>Custom Data<br><br>"

	# or uncomment the next line to forward a pre defined variable %custom to BinAuth
	#echo "<input type=\"hidden\" name=\"custom\" value=\"$custom\""

	# Now finish outputting the form html
	echo "
			<input type=\"submit\" value=\"Continue\" >
		</form>
		<hr>
	"

	# In this example we have decided to log all clients who are granted access
	write_log

}

htmlentityencode() {
	entitylist="s/\"/\&quot;/ s/>/\&gt;/ s/</\&lt;/"
	local buffer="$1"
	for entity in $entitylist; do
		entityencoded=$(echo "$buffer" | sed "$entity")
		buffer=$entityencoded
	done
}

htmlentitydecode() {
	entitylist="s/\&quot;/\"/ s/\&gt;/>/ s/\&lt;/</"
	local buffer="$1"
	for entity in $entitylist; do
		entitydecoded=$(echo "$buffer" | sed "$entity")
		buffer=$entitydecoded
	done
}

get_client_zone () {
	# Gets the client zone, (if we don't already have it) ie the connection the client is using, such as:
	# local interface (br-lan, wlan0, wlan0-1 etc.,
	# or remote mesh node mac address
	# This zone name is only displayed here but could be used to customise the login form for each zone

	if [ -z "$client_zone" ]; then
		client_mac=$(ip -4 neigh |grep "$clientip" | awk '{print $5}')
		client_if_string=$(/usr/lib/opennds/get_client_interface.sh $client_mac)
		failcheck=$(echo "$client_if_string" | grep "get_client_interface")

		if [ -z $failcheck ]; then
			client_if=$(echo "$client_if_string" | awk '{printf $1}')
			client_meshnode=$(echo "$client_if_string" | awk '{printf $2}' | awk -F ':' '{print $1$2$3$4$5$6}')
			local_mesh_if=$(echo "$client_if_string" | awk '{printf $3}')

			if [ ! -z "$client_meshnode" ]; then
				client_zone="MeshZone:$client_meshnode"
			else
				client_zone="LocalZone:$client_if"
			fi
		else
			client_zone=""
		fi
	else
		client_zone=$(printf "${client_zone//%/\\x}")
	fi
}

write_log () {

	if [ ! -z "$logname" ]; then

		if [ ! -d "$logdir" ]; then
			mkdir -p "$logdir"
		fi

		logfile="$logdir""$logname"
		awkcmd="awk ""'\$6==""\"$mountpoint\"""{print \$4}'"
		min_freespace_to_log_ratio=10
		datetime=$(date)

		if [ ! -f "$logfile" ]; then
			echo "$datetime, New log file created" > $logfile
		fi

		filesize=$(ls -s -1 $logfile | awk -F' ' '{print $1}')
		available=$(df | grep "$mountpoint" | eval "$awkcmd")
		sizeratio=$(($available/$filesize))

		if [ $sizeratio -ge $min_freespace_to_log_ratio ]; then
			userinfo="username=$username, emailAddress=$emailaddr"
			clientinfo="macaddress=$clientmac, clientzone=$client_zone, useragent=$user_agent"
			echo "$datetime, $userinfo, $clientinfo" >> $logfile
		else
			echo "PreAuth - log file too big, please archive contents" | logger -p "daemon.err" -s -t "opennds[$ndspid]: "
		fi
	fi
}
#### end of functions ####


##################################
#### Start - Main entry point ####
##################################

# Customise the Logfile location, use the tmpfs "temporary" directory to prevent flash wear.
configure_log_location

# Get the query string arguments and parse/decode them
get_arguments $1 $2 $3

### We are now ready to generate the html for the Portal "Splash" pages: ###

# Output the page common header
header

# Check if Terms of Service is requested
if [ "$terms" = "yes" ]; then
	display_terms
fi

# Check if the client is already logged in (have probably tapped "back" on their browser)
# Make this a friendly message explaining they are good to go
check_authenticated

# Check login mode and serve appropriate form
if [ $mode -eq 0 ]; then
	click_to_continue

elif [ $mode -eq 1 ]; then
	name_email_login

else
	echo "<b>Invalid login mode #:$mode</b>"
	footer
fi


#########################################################################################
# That's it, we generated the dynamic html and sent it to MHD to be served to the client.
#########################################################################################

# Hints:
#
# We could ask for anything we like and add our own variables to the html forms
# we generate.
#
# If we can if desired show a sequence of forms or information pages.
#
# To return to this script and show additional pages, the form action must be set to:
#	<form action=\"/opennds_preauth/\" method=\"get\">
# Note: quotes ( " ) must be escaped with the "\" character.
#
# Any variables we need to preserve and pass back to ourselves or NDS must be added
# to the form as hidden:
#	<input type=\"hidden\" name=......
# Such variables will appear in the query string when NDS re-calls this script.
# We can then parse for them again.
#
# When the logic of this script decides we should allow the client to access the Internet
# we inform NDS with a final page displaying a continue button with the form action set to:
#	"<form action=\"/opennds_auth/\" method=\"get\">"
#
# We must also send NDS the client token as a hidden variable.
#
# Note that the output of this script will be served by openNDS built in web server and
# ultimately displayed on the client device screen via the CPD process on that device.
#
# It should be noted when designing a custom splash page that for security reasons
# most client device CPD implementations MAY:
#
#	1.Immediately close the browser when the client has authenticated.
#	2.Prohibit the use of href links.
#	3.Prohibit downloading of external files (including .css and .js, even if they are allowed in NDS firewall settings).
#	4.Prohibit the execution of javascript.
#
