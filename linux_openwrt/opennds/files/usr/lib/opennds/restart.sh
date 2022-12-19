#!/bin/sh

# Check if opennds is running
ndspid=$(pidof opennds)
fwhook=$(uci -q get opennds.@opennds[0].fwhook_enabled)

if [ ! -z $ndspid ]; then
	if [ "$fwhook" = "1" ]; then

		/usr/lib/opennds/libopennds users_to_router allow

		ret=$?

		if [ $ret -eq 0 ]; then
			echo "fwhook signalled thefirewall is restarting, so adding rule to chain $inputchain for interface $gatewayinterface  " \
				| logger -p "daemon.info" -s -t "opennds[$ndspid]"
		else
			echo "fwhook signalled thefirewall is restarting, but error $ret occured adding rule to chain $inputchain for interface $gatewayinterface  " \
				| logger -p "daemon.error" -s -t "opennds[$ndspid]"
		fi
	fi
fi
