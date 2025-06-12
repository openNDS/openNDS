#!/bin/sh
#Copyright (C) The openNDS Contributors 2004-2022
#Copyright (C) BlueWave Projects and Services 2015-2025
#This software is released under the GNU GPL license.

# This is a stub for a custom binauth script
# It is included by the default binauth_log.sh script when it runs
#
# This included script can override:
# exitlevel, session length, upload rate, download rate, upload quota and download quota.

# Add custom code after this line:

###########################################################################
# reauth_interval - Set minimum time between deauthentication and reauthentication

#Define a function
parse_timestamp() {
	local action="$1"
	eval $(grep "$clientmac" /tmp/ndslog/binauthlog.log | grep "$action" | awk -F", " '{print $4}' | tail -n 1)
	syslogmessage="clientmac [$clientmac] action [$action] timestamp [$timestamp]"
	debuglevel="debug"
	/usr/lib/opennds/libopennds.sh "write_to_syslog" "$syslogmessage" "$debuglevel"
}

# Set the reauth_interval in seconds

reauth_interval=3600 # Lets hard code it to 1 hour, we can make this a config option later

syslogmessage="reauth_interval clientmac [$clientmac] action [ $action ]"

debuglevel="debug"
/usr/lib/opennds/libopennds.sh "write_to_syslog" "$syslogmessage" "$debuglevel"

if [ "$action" = "auth" ]; then
	parse_timestamp "_deauth"
	last_deauth=$timestamp

	if [ -z "$last_deauth" ]; then
		# Client has never been deauthed so we can let them re-auth
		exitlevel=0 #allow
	else
		time_now=$(date +%s)
		re_auth_min_time=$((last_deauth + reauth_interval))

		syslogmessage="clientmac [$clientmac] re_auth_min_time [ $re_auth_min_time ]"
		debuglevel="debug"
		/usr/lib/opennds/libopennds.sh "write_to_syslog" "$syslogmessage" "$debuglevel"

		if [ "$re_auth_min_time" -lt "$time_now" ]; then
			exitlevel=0 #allow
		else
			exitlevel=1 #deny
			syslogmessage="clientmac [$clientmac] attempted login before reauth interval expired"
			debuglevel="debug"
			/usr/lib/opennds/libopennds.sh "write_to_syslog" "$syslogmessage" "$debuglevel"
		fi
	fi
fi


