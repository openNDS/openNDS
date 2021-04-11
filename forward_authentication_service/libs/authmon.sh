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

#action can be "list" (list and delete from FAS auth log), "view" (view and leave in FAS auth log) or "clear" (clear any stale FAS auth log entries)
#

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

# Initialise by clearing stale FAS auth log entries
action="clear"
payload="none"
ret=$($phpcli -f "$postrequest" "$url" "$action" "$gatewayhash" "$user_agent" "$payload")

# Main loop:
while true; do
	# Get remote authlist from the FAS:
	action="view"
	payload="none"
	acklist="*"

	authlist=$($phpcli -f "$postrequest" "$url" "$action" "$gatewayhash" "$user_agent" "$payload")
	validator=${authlist:0:1}

	if [ "$validator" = "*" ]; then
		authlist=${authlist:2:1024}

		if [ ${#authlist} -ge 3 ]; then

			# Set the maximum number of clients to authenticate in one go
			# (This is necessary due to string length limits in some shell implementations eg Busybox ash)
			authcount=4

			for authparams_enc in $authlist; do
				authparams=$(printf "${authparams_enc//%/\\x}")
				logger -s -p daemon.notice -t "authmon" "authentication parameters $authparams"

				ndsctlcmd="auth $authparams 2>/dev/null"
				do_ndsctl
				authcount=$((--authcount))

				if [ "$ndsstatus" = "authenticated" ]; then
					client_rhid=$(echo "$authparams" | awk '{printf($1)}')
					acklist="$acklist $client_rhid"
				fi

				if [ "$ndsstatus" = "busy" ]; then
					logger -s -p daemon.err -t "authmon" "ERROR: ndsctl is in use by another process"
				fi

				if [ "$authcount" < 1 ]; then
					break
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

	# acklist is a space separated list of the rhid's of sucessfully authenticated clients.
	# Send acklist to the FAS for upstream processing:
	ackresponse=$($phpcli -f "$postrequest" "$url" "$action" "$gatewayhash" "$user_agent" "$acklist")

	# Sleep for a while:
	sleep $loopinterval
done

