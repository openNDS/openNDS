#!/bin/sh
#Copyright (C) BlueWave Projects and Services 2015-2021
#This software is released under the GNU GPL license.
#
# Warning - shebang sh is for compatibliity with busybox ash (eg on OpenWrt)
# This is changed to bash automatically by Makefile for generic Linux
#

# Define the dnsmask config file and hosts file locations for generic Linux
# Edit these if your system uses a non standard locations:
conflocation="/etc/dnsmasq.conf"
hosts="/etc/hosts"
#

setconf="$1"
uciconfig=$(uci show dhcp 2>/dev/null)

delete_114s() {

	if [ ! -z "$cpidconfig" ]; then

		for option114 in $cpidconfig; do
			is_114=$(echo "$option114" | grep "114")

			if [ ! -z "$is_114" ]; then
				echo "$dellist'$option114'" | uci batch
			fi
		done
	fi
}

restart_dnsmasq() {
	if [ "$uciconfig" = "" ]; then
		systemctl restart dnsmasq &
	else
		/etc/init.d/dnsmasq restart &
	fi
}

if [ "$setconf" = "" ]; then
	exit 1

elif [ "$setconf" = "restart_only" ]; then
	restart_dnsmasq
	printf "%s" "done"
	exit 0

elif [ "$setconf" = "ipsetconf" ]; then
	ipsetconf=$2	

	if [ "$uciconfig" = "" ]; then
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

	printf "%s" "done"
	exit 0

elif [ "$setconf" = "hostconf" ]; then
	gw_ip=$2
	gw_fqdn=$3
	host_entry="$gw_ip $gw_fqdn " 
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

	printf "%s" "done"
	exit 0

elif [ "$setconf" = "cpidconf" ]; then
	gatewayfqdn=$2

	if [ "$uciconfig" = "" ]; then
		# Generic Linux
		sed -i '/System\|114,http:/d' $conflocation

		if [ ! -z "$gatewayfqdn" ]; then
			echo "dhcp-option-force=114,http://$gatewayfqdn" >> $conflocation
		fi
	else
		# OpenWrt
		cpidconfig=$(uci get dhcp.lan.dhcp_option_force 2>/dev/null)
		dellist="del_list dhcp.lan.dhcp_option_force="

		if [ -z "$gatewayfqdn" ]; then
			delete_114s
			uci commit dhcp
			printf "%s" "done"
			exit 0
		fi

		addlist="add_list dhcp.lan.dhcp_option_force='114,http://$gatewayfqdn'"

		if [ -z "$cpidconfig" ]; then
			echo $addlist | uci batch
			# Note we do not commit here so that the config changes do NOT survive a reboot

		elif [ "$cpidconfig" != "114,http://$gatewayfqdn" ]; then
			delete_114s
			echo $addlist | uci batch
			# Note we do not commit here so that the config changes do NOT survive a reboot
		fi
	fi

	printf "%s" "done"
	exit 0

else
	exit 1 
fi

