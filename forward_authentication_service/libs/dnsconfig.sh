#!/bin/sh
#Copyright (C) BlueWave Projects and Services 2015-2021
#This software is released under the GNU GPL license.
#
# Warning - shebang sh is for compatibliity with busybox ash (eg on OpenWrt)
# This is changed to bash automatically by Makefile for generic Linux
#

restart_dnsmasq() {
	if [ "$uciconfig" = "" ]; then
		systemctl restart dnsmasq &
	else
		/etc/init.d/dnsmasq restart &
	fi
}

setconf="$1"
uciconfig=$(uci show dhcp 2>/dev/null)

if [ "$setconf" = "" ]; then
	exit 1
elif [ "$setconf" = "restart_only" ]; then
	restart_dnsmasq
	exit 0
elif [ "$setconf" = "ipsetconf" ]; then
	ipsetconf=$2	

	if [ "$uciconfig" = "" ]; then
		conflocation="/etc/dnsmasq.conf"
		sed -i '/System\|walledgarden/d' $conflocation
		echo "ipset=$ipsetconf" >> $conflocation
	else
		uci revert dhcp
		hardconfig=$(uci get dhcp.@dnsmasq[0].ipset | awk -F' ' '{print $1}' | grep '/walledgarden')

		if [ "$hardconfig" = "$ipsetconf" ]; then
			uci del_list dhcp.@dnsmasq[0].ipset=$ipsetconf
			uci commit dhcp
		fi
		uci add_list dhcp.@dnsmasq[0].ipset=$ipsetconf
	fi
	exit 0
elif [ "$setconf" = "hostconf" ]; then
	gw_ip=$2
	gw_fqdn=$3
	host_entry="$gw_ip $gw_fqdn " 
	hosts="/etc/hosts"
	host_entry_check=$(grep "$host_entry" "$hosts")
	ip_check=$(grep "$gw_ip" "$hosts" | awk 'NR==1{printf("%s ", $1)}')
	fqdn_check=$(grep "$gw_fqdn" "$hosts" | awk 'NR==1{printf("%s ", $2)}')

	if [ -z "$ip_check" ] && [ ! -z "$fqdn_check" ]; then
		sed -i "/$fqdn_check/d" $hosts
		echo "$host_entry" >> "$hosts"

	elif [ -z "$fqdn_check" ] && [ ! -z "$ip_check" ]; then
		sed -i "/$ip_check/d" $hosts
		echo "$host_entry" >> "$hosts"

	elif [ -z "$host_entry_check" ] && [ ! -z "$fqdn_check" ]; then
		sed -i "/$fqdn_check/d" $hosts
		echo "$host_entry" >> "$hosts"

	elif [ -z "$host_entry_check" ]; then
		echo "$host_entry" >> "$hosts"
	fi

	exit 0
else
	exit 1 
fi

