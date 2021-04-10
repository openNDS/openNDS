#!/bin/sh
#Copyright (C) The openNDS Contributors 2004-2021
#Copyright (C) BlueWave Projects and Services 2015-2021
#This software is released under the GNU GPL license.
#
# Warning - shebang sh is for compatibliity with busybox ash (eg on OpenWrt)
# This is changed to bash automatically by Makefile for generic Linux
#

# In this example script we want to either ask the client user for
# their username and email address or to give them a click to continue button.
#
# Splash page modes are selected in the openNDS config using the login_option_enabled parameter.
#
# Mode 0. login_option_enabled set to 0 - Default if FAS Disabled.
# Mode 1. login_option_enabled set to 1 - generate a simple "click to continue" splash page (with Terms of Service).
# Mode 2. login_option_enabled set to 2 - generate a "username/email_address splash page (with Terms of Service).
# Mode > 2. Reserved for customisation and future enhancement.

# functions:

# Function to send commands to openNDS:
do_ndsctl () {
	local timeout=4

	for tic in $(seq $timeout); do
		ndsstatus="ready"
		ndsctlout=$(ndsctl $ndsctlcmd)

		for keyword in $ndsctlout; do

			if [ $keyword = "locked" ]; then
				ndsstatus="busy"
				sleep 1
				break
			fi

			if [ $keyword = "Failed" ]; then
				ndsstatus="failed"
				break
			fi

			if [ $keyword = "authenticated." ]; then
				ndsstatus="authenticated"
				break
			fi

		done

		if [ $tic = $timeout ] ; then
			busy_page
		fi

		if [ "$ndsstatus" = "authenticated" ]; then
			break
		fi

		if [ "$ndsstatus" = "failed" ]; then
			break
		fi

		if [ "$ndsstatus" = "ready" ]; then
			break
		fi
	done
}

get_theme_environment() {
	# Get the query-string, user_agent and mode
	# The query string is urlencoded AND base64 encoded
	query_enc=$1
	user_agent_enc="$2"
	mode="$3"

	if [ "$mode" = "0" ]; then
		themespecfile="theme_click-to-continue.sh"
	elif [ "$mode" = "1" ]; then
		themespecfile="theme_click-to-continue.sh"
	elif [ "$mode" = "2" ]; then
		themespecfile="theme_user-email-login.sh"
	elif [ "$mode" = "3" ]; then
		themespecfile="$4"
	else
		echo "<b>Invalid login mode #:$mode</b>"
		type footer &>/dev/null && footer || default_footer
		exit 0
	fi

	if [ ! -f "/usr/lib/opennds/$themespecfile" ]; then
		echo "<b>Missing ThemeSpec - mode #:$mode</b>"
		type footer &>/dev/null && footer || default_footer
		exit 0
	fi
	. /usr/lib/opennds/$themespecfile

	# The base64 encoded query string can be very long and exceed the maximum length for a script argument
	# This is true in OpenWrt and is likely to be the case in many other operating systems, particularly those that use Busybox ASH shell
	# To be safe we will fragment the querystring for b64 decoding

	# The b64encoded data begins at the 10th character, ie character number 9 (numbering starts at zero).
	#
	# some variables:
	fullfrag="="
	query=""
	i=9
	query_enc_type=${query_enc:0:9}

	if [ "$query_enc_type" != "%3ffas%3d" ]; then
		exit 1
	fi

	fas=${query_enc:9:1024}

	#fas is urlencoded, so we must urldecode
	fas=$(printf "${fas//%/\\x}")

	#But parts MAY be user entered so we must sanitize by html entity encoding
	htmlentityencode "$fas"
	fas=$entityencoded

	# strip off any fas variables this script might have added, ie username and email
	fas="${fas%%,*}"

	# Fragment and decode:
	while true; do
		# get a full fragment
		fullfrag=${query_enc:$i:336}

		if [ -z "$fullfrag" ]; then
			break
		fi

		#The fragments are urlencoded, so we must urldecode
		fullfrag=$(printf "${fullfrag//%/\\x}")

		#But parts MAY be user entered so we must sanitize by html entity encoding
		htmlentityencode "$fullfrag"
		fullfrag=$entityencoded

		# strip off any fas variables this script might have added, ie username and email
		b64frag="${fullfrag%%,*}"

		# Find the length of the stripped fragment
		fraglen=$((${#b64frag}))

		# Find the stripped off fas variables as we need them too
		fasvars="$fasvars""${fullfrag:$fraglen:1024}"

		#base64 decode the current fragment
		ndsctlcmd="b64decode $b64frag"
		do_ndsctl
		frag=$ndsctlout

		# parse variables in this fragment (each time round this loop we will add more parsed variables)
		query="$frag"
		queryvarlist=$ndsparamlist
		parse_variables
		# Increment the pointer by a factor of 4
		i=$((i+272))
	done

	# Arguments may be sent to us from NDS in a urlencoded form,
	# we can decode an argument as follows:
	# arg[N]=$(printf "${arg[N]_enc//%/\\x}")

	# The User Agent argument is sent urlencoded, so:
	user_agent=$(printf "${user_agent_enc//%/\\x}")

	# Now we need to parse any fas variables this script may have added. These are in the string $fasvars:
	queryvarlist=$fasvarlist
	query="$fasvars"
	parse_variables

	#Check if we parsed the client zone, if not, get it
	get_client_zone
}

parse_variables() {
	# Parse for variables in $query from the list in $queryvarlist:

	for var in $queryvarlist; do
		evalstr=$(echo "$query" | awk -F"$var=" '{print $2}' | awk -F', ' '{print $1}')
		evalstr=$(printf "${evalstr//%/\\x}")

		# sanitise $evalstr to prevent code injection
		htmlentityencode "$evalstr"
		evalstr=$entityencoded

		if [ -z "$evalstr" ]; then
			continue
		fi

		eval $var=$(echo "\"$evalstr\"")
	done
}

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

		read_terms
		footer
	fi
}


htmlentityencode() {
	entitylist="
		s/\"/\&quot;/g
		s/>/\&gt;/g
		s/</\&lt;/g
		s/%/\&#37;/g
		s/'/\&#39;/g
		s/\`/\&#96;/g
	"
	local buffer="$1"

	for entity in $entitylist; do
		entityencoded=$(echo "$buffer" | sed "$entity")
		buffer=$entityencoded
	done

	entityencoded=$(echo "$buffer" | awk '{ gsub(/\$/, "\\&#36;"); print }')
}


htmlentitydecode() {
	entitylist="
		s/\&quot;/\"/g
		s/\&gt;/>/g
		s/\&lt;/</g
		s/\&#37;/%/g
		s/\&#39;/'/g
		s/\&#96;/\`/g
	"
	local buffer="$1"

	for entity in $entitylist; do
		entitydecoded=$(echo "$buffer" | sed "$entity")
		buffer=$entitydecoded
	done

	entitydecoded=$(echo "$buffer" | awk '{ gsub(/\\&#36;/, "\$"); print }')
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

auth_log () {
	# We are ready to authenticate the client

	rhid=$(printf "$hid$key" | sha256sum | awk -F' ' '{printf $1}')
	ndsctlcmd="auth $rhid $quotas $binauth_custom"

	do_ndsctl
	authstat=$ndsctlout
	# TODO: We can do additional error checking here - do we need to?
	# busy and failure are already checked by do_ndsctl
	# $authstat contains the response from do_ndsctl

	mountcheck=$(df | grep "$mountpoint")
	clientinfo="status=$authstat, mac=$clientmac, ip=$clientip, zone=$client_zone, ua=$user_agent"

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

		if [ ! -z "$mountcheck" ]; then
			filesize=$(ls -s -1 $logfile | awk -F' ' '{print $1}')
			available=$(df | grep "$mountpoint" | eval "$awkcmd")
			sizeratio=$(($available/$filesize))

			if [ $sizeratio -ge $min_freespace_to_log_ratio ]; then
				echo "$datetime, $userinfo, $clientinfo" >> $logfile
			else
				echo "PreAuth - log file too big, please archive contents" | logger -p "daemon.err" -s -t "opennds[$ndspid]: "
			fi
		else
			echo "Log location is NOT a mountpoint - logs would fill storage space - logging disabled" | logger -p "daemon.err" -s -t "opennds[$ndspid]: "
		fi
	fi
}

default_header() {
# Define a common header html for every page served
	echo "<!DOCTYPE html>
		<html>
		<head>
		<meta http-equiv=\"Cache-Control\" content=\"no-cache, no-store, must-revalidate\">
		<meta http-equiv=\"Pragma\" content=\"no-cache\">
		<meta http-equiv=\"Expires\" content=\"0\">
		<meta charset=\"utf-8\">
		<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
		<link rel=\"shortcut icon\" href=\"/images/splash.jpg\" type=\"image/x-icon\">
		<link rel=\"stylesheet\" type=\"text/css\" href=\"/splash.css\">
		<title>$gatewayname</title>
		</head>
		<body>
		<div class=\"offset\">
		<med-blue>
			$gatewayname <br>
		</med-blue>
		<div class=\"insert\" style=\"max-width:100%;\">
	"
}

default_footer() {
	# Define a common footer html for every page served (with openNDS version on the thankyou page)
	year=$(date +'%Y')
	echo "
		<hr>
		<div style=\"font-size:0.5em;\">
			<img style=\"height:30px; width:60px; float:left;\" src=\"$imagepath\" alt=\"Splash Page: For access to the Internet.\">
			&copy; The openNDS Project 2015 - $year<br>
			openNDS $version
			<br><br>
		</div>
		</div>
		</div>
		</body>
		</html>
	"

	exit 0
}

busy_page() {
	type header &>/dev/null && header || default_header
	echo "
		<p>
			<big-red>
				Sorry: The Portal is Busy
			</big-red>
		</p>
		<hr>
		<p>
			<italic-black>
				Please Try Again Later
			</italic-black>
		</p>
	"

	type footer &>/dev/null && footer || default_footer
	exit 0
}

serve_error_message () {
	echo "<br><b style=\"color:red;\">Error: $1 </b><br>"
	default_footer
	exit 0
}

#### end of functions ####


#########################################
#					#
#  Start - Main entry point		#
#					#
#  This script starts executing here	#
#					#
#  Any parameters set here will be	#
#  overridden if set			#
#  in the themespec file		#
#					#
#########################################

#  setup required parameters:		#

# Preshared key
#########################################
# Default value is 1234567890 when faskey is not set
# Change to match faskey if faskey is set
key="1234567890"

# Quotas and Data Rates
#########################################
# Set length of session in minutes (eg 24 hours is 1440 minutes - if set to 0 then defaults to global sessiontimeout value):
# eg for 100 mins:
# session_length="100"
#
# eg for 20 hours:
# session_length=$((20*60))
#
# eg for 20 hours and 30 minutes:
# session_length=$((20*60+30))
session_length=$((24*60+30))

# Set Rate and Quota values for the client
# The session length, rate and quota values could be determined by this script, on a per client basis.
# rates are in kb/s, quotas are in kB. - if set to 0 then defaults to global value).
upload_rate="0"
download_rate="0"
upload_quota="0"
download_quota="0"

quotas="$session_length $upload_rate $download_rate $upload_quota $download_quota"
#########################################

# The list of Parameters sent from openNDS:
# Note you can add custom parameters to the config file and to read them you must also add them here.
# Custom parameters are "Portal" information and are the same for all clients eg "admin_email" and "location" 
ndsparamlist="clientip clientmac gatewayname version hid gatewayaddress gatewaymac authdir originurl clientif admin_email location"

# The list of FAS Variables used in the Login Dialogue generated by this script.
# These FAS variables received from the login form presented to the client.
# For the default login.sh operating in mode 1, we will have "username" and "emailaddress"
fasvarlist="username emailaddress terms landing status continue binauth_custom"

# You can choose to send a custom data string to BinAuth. Set the variable $binauth_custom to the desired value.
# Note1: As this script runs on the openNDS router and creates its own log file, there is little point also enabling Binauth.
#	BinAuth is intended more for use with EXTERNAL FAS servers that don't have direct access to the local router.
#	Nevertheless it can be enabled at the same time as this script if so desired.
# Note2: Spaces will be translated to underscore characters.
# Note3: You must escape any quotes.
binauth_custom="This is sample text with the intention of sending it to \"BinAuth\" for post authentication processing."

# Set the Logfile location, using the tmpfs "temporary" directory to prevent flash wear.
# or override to a custom location in the ThemeSpec file (eg USB stick)
configure_log_location


############################################################################
### We are now ready to generate the html for the Portal "Splash" pages: ###
############################################################################

# Get the arguments sent from openNDS and parse/decode them, setting portal ThemeSpec as required
get_theme_environment $1 $2 $3 $4

# Set the default image to be displayed
if [ -z "$imagepath" ]; then
	imagepath="http://$gatewayaddress/images/splash.jpg"
fi

# Output the page common header
type header &>/dev/null && header || default_header

# Check if Terms of Service is requested
if [ "$terms" = "yes" ]; then
	display_terms
fi

# Check if landing page is requested
if [ "$landing" = "yes" ]; then
	landing_page
fi

# Check if the client is already logged in (have probably tapped "back" on their browser)
# Make this a friendly message explaining they are good to go
check_authenticated

# Generate the dynamic portal splash page sequence
type generate_splash_sequence &>/dev/null && generate_splash_sequence || serve_error_message "Invalid ThemeSpec"


# Hints:
# The output of this script will be served by openNDS built in web server (MHD) and
# ultimately displayed on the client device screen via the CPD process on that device.
#
# It should be noted when designing a custom splash page that for security reasons
# most client device CPD implementations MAY do one or all of the following:
#
#	1.Immediately close the browser when the client has authenticated.
#	2.Prohibit the use of href links.
#	3.Prohibit downloading of external files (including .css and .js, even if they are allowed in NDS firewall settings).
#	4.Prohibit the execution of javascript.
#
