#!/bin/sh
#Copyright (C) The openNDS Contributors 2004-2020
#Copyright (C) BlueWave Projects and Services 2015-2020
#This software is released under the GNU GPL license.
#
# Warning - shebang sh is for compatibliity with busybox ash (eg on OpenWrt)
# This is changed to bash automatically by Makefile for generic Linux
#

ipsetconf="$1"

if [ "$ipsetconf" == "" ]; then
	exit 1
fi

uciconfig=$(uci show dhcp 2>/dev/null)

if [ "$uciconfig" == "" ]; then
	conflocation="/etc/dnsmasq.conf"
	sed -i '/System\|walledgarden/d' $conflocation
	echo "ipset=$ipsetconf" >> $conflocation
	systemctl restart dnsmasq &
else
	uci revert dhcp
	hardconfig=$(uci get dhcp.@dnsmasq[0].ipset | awk -F' ' '{print $1}' | grep '/walledgarden')

	if [ "$hardconfig" = "$ipsetconf" ]; then
		uci del_list dhcp.@dnsmasq[0].ipset=$ipsetconf
		uci commit dhcp
	fi
	uci add_list dhcp.@dnsmasq[0].ipset=$ipsetconf
	/etc/init.d/dnsmasq restart &
fi

exit 0
