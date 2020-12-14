#!/bin/sh

url=$1
gatewayhash=$2
phpcli=$3
loopinterval=15
postrequest="/usr/lib/opennds/post-request.php"

#action can be "list" (list and delete from FAS auth log) or "view" (view and leave in FAS auth log)
#
# For debugging purposes, action can be set to "view"
#action="view"
# For normal running, action will be set to "list"
action="list"

version=$(ndsctl status 2>/dev/null | grep Version | awk '{printf $2}')
user_agent="openNDS(authmon;NDS:$version;)"

while true; do
	authlist=$($phpcli -f "$postrequest" "$url" "$action" "$gatewayhash" "$user_agent")

	if [ ${#authlist} -ge 2 ]; then

		for authparams in $authlist; do
			authparams=$(printf "${authparams//%/\\x}")
			logger -s -p daemon.notice -t "authmon" "authentication parameters $authparams"
			echo $authparams
			echo $(ndsctl auth $authparams 2>/dev/null)
		done
	fi

	sleep $loopinterval
done

