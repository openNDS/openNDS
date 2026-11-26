#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later

# Check if opennds is running
ndspid=$(pidof opennds)
fwhook=$(uci -q get opennds.@opennds[0].fwhook_enabled)

# openNDS has no nftables tables while it is dormant (see option auto_run)
ndstable=$(nft list tables 2> /dev/null | grep -c -w "nds_filter")

if [ ! -z $ndspid ] && [ "$ndstable" -gt 0 ]; then
	if [ "$fwhook" != "0" ]; then
		echo "fwhook received a signal that the system firewall is restarting" | logger -p "daemon.notice" -s -t "opennds[$ndspid]"

		# Set "users_to_router allow"
		/usr/lib/opennds/libopennds.sh users_to_router allow
	fi
fi
