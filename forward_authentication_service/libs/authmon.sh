#!/bin/sh
#Copyright (C) BlueWave Projects and Services 2015-2021
#This software is released under the GNU GPL license.

#wait a while for openNDS to get started
sleep 5

#get arguments and set variables
url=$1
gatewayhash=$2
phpcli=$3
loopinterval=10
postrequest="/usr/lib/opennds/post-request.php"

#action can be "list" (list and delete from FAS auth log) or "view" (view and leave in FAS auth log)
#
# Default set to "view" to facilitate upstream auth_ack processing
action="view"

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

# Construct our user agent string:
ndsctlcmd="status 2>/dev/null"
do_ndsctl
version=$(echo "$ndsctlout" | grep Version | awk '{printf $2}')
user_agent="openNDS(authmon;NDS:$version;)"

# Main loop:
while true; do
	# Get remote authlist from the FAS:
	$payload="none";
	authlist=$($phpcli -f "$postrequest" "$url" "$action" "$gatewayhash" "$user_agent" "$payload")
	validator=${authlist:0:1}

	if [ "$validator" = "*" ]; then
		authlist=${authlist:1:1024}

		if [ ${#authlist} -ge 2 ]; then

			for authparams in $authlist; do
				authparams=$(printf "${authparams//%/\\x}")
				logger -s -p daemon.notice -t "authmon" "authentication parameters $authparams"
				echo $authparams
				ndsctlcmd="auth $authparams 2>/dev/null"
				do_ndsctl

				if [ "$ndsstatus" = "busy" ]; then
					logger -s -p daemon.err -t "authmon" "ERROR: ndsctl is in use by another process"
				fi
			done
		fi
	else
		for keyword in $authlist; do

			if [ $keyword = "ERROR:" ]; then
				logger -s -p daemon.err -t "authmon" "[$authlist]"
				break
			fi
		done
	fi

	# Send auth_ack list to the FAS:

	# Sleep for a while:
	sleep $loopinterval
done

