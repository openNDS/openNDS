#!/bin/sh
#Copyright (C) The openNDS Contributors 2004-2021
#Copyright (C) BlueWave Projects and Services 2015-2021
#This software is released under the GNU GPL license.
#
# Warning - shebang sh is for compatibliity with busybox ash (eg on OpenWrt)
# This is changed to bash automatically by Makefile for Debian
#

# ip address of client is passed as a command line argument
clientip=$1

# exit if ip not passed

if [  $(echo "$clientip" | awk -F '.' '{print NF}') != 4 ]; then
	echo "
  Usage: get_client_token.sh [clientip]

  Returns: [client token]

  Where:
    [client token] is the unique client token string.
"
	exit 1
fi


wait_for_ndsctl () {
	local timeout=3

	for i in $(seq $timeout); do

		if [ ! -f "/tmp/ndsctl.lock" ]; then
			break
		fi

		sleep 1

		if [ $i = $timeout ] ; then
			pid=$(ps | grep get_client_token | awk -F ' ' 'NR==2 {print $1}')
			echo "ndsctl is busy or locked" | logger -p "daemon.warn" -s -t "NDS-Library[$pid]"
			exit 1
		fi

	done
}

wait_for_ndsctl
client_token=$(ndsctl json $clientip | awk -F '"' '$2=="token"{printf $4}')

if [ -z "$client_token" ]; then
	pid=$(ps | grep get_client_token | awk -F ' ' 'NR==2 {print $1}')
	echo "client at [$clientip] is not preauthenticated" | logger -p "daemon.warn" -s -t "NDS-Library[$pid]"
	exit 1
else
	echo "$client_token"
fi
exit 0
