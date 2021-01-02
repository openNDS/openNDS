#!/bin/sh
#Copyright (C) BlueWave Projects and Services 2015-2021
#This software is released under the GNU GPL license.
#
clientip=$1

get_client_zone () {
	# Gets the client zone, (if we don't already have it) ie the connection the client is using, such as:
	# local interface (br-lan, wlan0, wlan0-1 etc.,
	# or remote mesh node mac address

	failcheck=$(echo "$clientif" | grep "get_client_interface")

	if [ -z $failcheck ]; then
		client_if=$(echo "$clientif" | awk '{printf $1}')
		client_meshnode=$(echo "$clientif" | awk '{printf $2}' | awk -F ':' '{print $1$2$3$4$5$6}')
		local_mesh_if=$(echo "$clientif" | awk '{printf $3}')

		if [ ! -z "$client_meshnode" ]; then
			client_zone="MeshZone:$client_meshnode"
		else
			client_zone="LocalZone:$client_if"
		fi
	else
		client_zone=""
	fi
}

htmlentityencode() {
	entitylist="s/\"/\&quot;/ s/>/\&gt;/ s/</\&lt;/"
	local buffer="$1"
	for entity in $entitylist; do
		entityencoded=$(echo "$buffer" | sed "$entity")
		buffer=$entityencoded
	done
}

parse_parameters() {
	param_str=$(ndsctl json $clientip)

	for param in gatewayname mac version ip clientif session_start session_end last_active token state upload_rate_limit \
		download_rate_limit upload_quota download_quota upload_this_session download_this_session  \
		upload_session_avg  download_session_avg
	do
		val=$(echo "$param_str" | grep "$param" | awk -F'"' '{printf "%s", $4}')
		eval $param=$(echo "\"$val\"")
	done

	# url decode and html entity encode gatewayname
	gatewayname_dec=$(printf "${gatewayname//%/\\x}")
	htmlentityencode "$gatewayname_dec"
	gatewaynamehtml=$entityencoded

	# Get client_zone from clientif
	get_client_zone

	# Get human readable times:
	sessionstart=$(date -d @$session_start)
	sessionend=$(date -d @$session_end)
	lastactive=$(date -d @$last_active)
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
		<title>$gatewaynamehtml Client Session Status</title>
		</head>
		<body>
		<div class=\"offset\">
		<med-blue>
			$gatewaynamehtml <br>
			Client Session Status<br>
			$client_zone
		</med-blue><br>
		<div class=\"insert\" style=\"max-width:100%;\">
	"
	echo "$header"
}

footer() {
	# Define a common footer html for every page served
	year=$(date +'%Y')
	echo "
		<hr>
		<div style=\"font-size:0.5em;\">
			<img style=\"height:30px; width:60px; float:left;\" src=\"/images/splash.jpg\" alt=\"Splash Page: For access to the Internet.\">
			&copy; The openNDS Project 2015 - $year<br>
			openNDS $version
			<br><br>
		</div>
		</div>
		</div>
		</body>
		</html>
	"
}

body() {
	echo "
		<b>IP address:</b> $ip<br>
		<b>MAC address:</b> $mac<br>
		<b>Interfaces being used by this client:</b> $clientif<br>
		<b>Session Start:</b> $sessionstart<br>
		<b>Session End:</b> $sessionend<br>
		<b>Last Active:</b> $lastactive<br>
		<b>Upload Rate Limit:</b> $upload_rate_limit Kb/s<br>
		<b>Download Rate Limit:</b> $download_rate_limit Kb/s<br>
		<b>Upload Quota:</b> $upload_quota KBytes<br>
		<b>Download Quota:</b> $download_quota KBytes<br>
		<b>Uploaded This Session:</b> $upload_this_session KBytes<br>
		<b>Downloaded This Session:</b> $download_this_session KBytes<br>
		<b>Average Upload Rate This Session:</b> $upload_session_avg Kb/s<br>
		<b>Average Download Rate This Session:</b> $download_session_avg Kb/s<br>
		<hr>
		<form>
			<input type=\"button\" VALUE=\"Refresh\" onClick=\"history.go(0);return true;\">
		</form>
		<hr>
		<form action=\"/opennds_deny/\" method=\"get\">
			<input type=\"submit\" value=\"Logout\" >
		</form>
		<hr>
	"
}

# Start generating the html:
parse_parameters
header
body
footer

