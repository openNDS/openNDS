#!/bin/sh
#Copyright (C) The openNDS Contributors 2004-2022
#Copyright (C) BlueWave Projects and Services 2015-2026
#This software is released under the GNU GPL license.
#
# A list of variables that are initialised with valid information by the openNDS daemon and can be used in any custom code added below can be seen in the custombinauth.sh stub/template.

# BinAuth Descriptors:
custombinauth_title="reauth_interval"
custombinauth_description="Set minimum time between deauthentication and reauthentication"

#Define a function
parse_timestamp() {
	local action="$1"
	local line
	timestamp=""

	# Deauth lines look like method="idle_deauth", ..., timestamp=<seconds>, bytes_incoming=.
	# Take the first timestamp's digits. Do not execute the line: later fields can come from the client.
	if [ -n "$clientmac" ] && [ -n "$logdir" ]; then
		line=$(grep -F -- "$clientmac" "${logdir}binauthlog.log" 2>/dev/null | grep 'method="[^"]*_deauth"' | tail -n 1)
		timestamp=$(printf '%s\n' "$line" | awk '
			{
				i = index($0, "timestamp=")
				if (i == 0) {
					exit
				}
				s = substr($0, i + 10)
				n = ""
				while (length(s) > 0) {
					c = substr(s, 1, 1)
					if (c < "0" || c > "9") {
						break
					}
					n = n c
					s = substr(s, 2)
				}
				printf "%s", n
			}
		')
	fi

	syslogmessage="clientmac [$clientmac] action [$action] timestamp [$timestamp]"
	debuglevel="debug"
	write_to_syslog
}

# Get the reauth_interval in seconds
reauth_interval=$(ndscfg get_option_from_config reauth_interval)

if [ -z "$reauth_interval" ] || [ "$reauth_interval" -eq 0 ]; then
	# Reauth interval checking is disabled.
	exitlevel=0 #allow
else
	syslogmessage="reauth_interval clientmac [$clientmac] action [ $action ]"
	debuglevel="debug"
	write_to_syslog

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
			write_to_syslog

			if [ "$re_auth_min_time" -lt "$time_now" ]; then
				exitlevel=0 #allow
			else
				exitlevel=1 #deny
				syslogmessage="clientmac [$clientmac] attempted login before reauth interval expired"
				debuglevel="debug"
				write_to_syslog
			fi
		fi
	fi
fi

