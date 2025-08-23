#!/bin/sh
#Copyright (C) BlueWave Projects and Services 2015-2025
#This software is released under the GNU GPL license.
#
# Warning - shebang sh is for compatibliity with busybox ash (eg on OpenWrt)
# This is changed to bash automatically by Makefile for generic Linux
#

get_client_local_if() {
	clientlocalif=$(ip -4 neigh | grep "$mac" | awk 'NR==1{printf "%s", $3}')

	if [ -z "$clientlocalif" ]; then
		# The client has gone offline eg battery saving or switched to another ssid
		exit 1
	fi
}

# mac address of client is passed as a command line argument
mac=$1

# exit if mac not passed

if [  $(echo "$mac" | awk -F ':' '{print NF}') -ne 6 ]; then
	echo "
  Usage: get_client_interface.sh [clientmac]

  Returns: [local_interface] [meshnode_mac] [local_mesh_interface]

  Where:
    [local_interface] is the local interface the client is using.

    [meshnode_mac] is the mac address of the 802.11s meshnode the
      client is using (null if mesh not present).

    [local_mesh_interface] is the local 802.11s interface the
      client is using (null if mesh not present).

"
	exit 1
fi

get_client_local_if

fast_client_scan=$(/usr/lib/opennds/libopennds.sh "get_option_from_config" "fast_client_scan")

if [ -z "$fast_client_scan" ]; then
	fast_client_scan=0
fi

# This script requires the iw and ip packages to find the client wifi or mesh interface (usually available by default)

if [ -z $(command -v ip) ]; then
	/usr/lib/opennds/libopennds.sh write_to_syslog "ip utility not available - critical error" "err"
	exit 1
fi

if [ -z $(command -v iw) ]; then
	/usr/lib/opennds/libopennds.sh write_to_syslog "unable to detect wireless interface - iw utility not available" "debug"
	iwstatus=false
else
	iwstatus=true
fi

# Get default interface
# This will be the interface NDS is bound to eg. br-lan

if [ "$iwstatus" = true ]; then 
	# Get list of wireless interfaces on this device
	# This list will contain all the wireless interfaces configured on the device
	# eg wlan0, wlan0-1, wlan1, wlan1-1 etc
	interface_list=$(iw dev | awk -F 'Interface ' 'NF>1{printf $2" "}')

	# Scan the wireless interfaces on this device for the client mac
	# checking first for a mesh connection

	for interface in $interface_list; do
		clientmeshif=$(iw dev $interface mpp dump | awk -F "$mac " 'NF>1{printf $2}')

		if [ ! -z "$clientmeshif" ]; then
			break
		fi
	done

	if [ -z "$clientmeshif" ] && [ "$fast_client_scan" -eq 0 ]; then
		# Not mesh, so might be local wireless. We can scan for staions here, but it takes a while..
		for interface in $interface_list; do
			stations=$(iw dev $interface station dump | grep -w "$mac")

			if [ ! -z "$stations" ]; then
				clientlocalif="$interface"
				ssid=$(iw dev $interface info | grep -w "ssid" | awk '{printf "%s", $2}')
				zonemac=$(iw dev $interface info | grep -w "addr" | awk '{printf "%s", $2}')
				clientmeshif="$zonemac $ssid"
				break
			fi
		done
	fi

	if [ -z "$stations" ] && [ "$fast_client_scan" -eq 0 ]; then
		# Not local wireless, so check in mesh11sd's vxtun
		client_vtunif=$(type mesh11sd &>/dev/null && mesh11sd show_ap_data all 2>/dev/null | grep -w -B 1 "$mac" | grep "@" | awk -F "\"" 'NR==1 {printf "%s", $2}' | awk -F "@" '{printf "%s %s", $3, $1}')
		clientmeshif="$client_vtunif"
	fi
fi

# Return the local interface the client is using, the mesh node mac address and the local mesh interface
if [ -z "$clientmeshif" ]; then
	printf "%s" "$clientlocalif"
else
	printf "%s" "$clientlocalif $clientmeshif"
fi

exit 0

