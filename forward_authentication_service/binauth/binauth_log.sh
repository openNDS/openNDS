#!/bin/sh
#Copyright (C) The openNDS Contributors 2004-2020
#Copyright (C) BlueWave Projects and Services 2015-2020
#This software is released under the GNU GPL license.

# This is an example script for BinAuth
# It can set the session duration per client and writes a local log.
#
# It retrieves redir, a variable that either contains the originally requested url
# or a url-encoded or aes-encrypted payload of custom variables sent from FAS or PreAuth.
#
# The client User Agent string is also forwarded to this script.
#
# If BinAuth is enabled, NDS will call this script as soon as it has received an authentication request
# from the web page served to the client's CPD (Captive Portal Detection) Browser by one of the following:
#
# 1. splash.html
# 2. PreAuth
# 3. FAS
#

##################
# functions:

configure_log_location() {
	# Generate the Logfile location; use the tmpfs "temporary" directory to prevent flash wear.
	# Alternately you may choose to manually override the settings generated here.
	# For example mount a USB storage device and manually set logdir and logname instead of this code
	#
	# DEFAULT Location depends upon OS distro in use:
	tempdir="/tmp /run /var"
	mountpoint=""
	logdir="/tmp/ndslog/"
	logname="binauthlog.log"

	for var in $tempdir; do
		_mountpoint=$(df | awk -F ' ' '$1=="tmpfs" && $6=="'$var'" {print $6}')
		if [ "$_mountpoint" = "$var" ]; then
			mountpoint="$var"
			logdir="$mountpoint/ndslog/"
			break
		fi
	done

	#For syslog
	ndspid=$(pgrep '/usr/bin/opennds')
}

write_log () {

	if [ ! -d "$logdir" ]; then
		mkdir -p "$logdir"
	fi

	logfile="$logdir""$logname"
	awkcmd="awk ""'\$6==""\"$mountpoint\"""{print \$4}'"
	min_freespace_to_log_ratio=10
	datetime=$(date)

	if [ ! -f "$logfile" ]; then
		echo "$datetime, New log file created" > $logfile
	fi

	ndspid=$(ps | grep opennds | awk -F ' ' 'NR==2 {print $1}')
	filesize=$(ls -s -1 $logfile | awk -F' ' '{print $1}')
	available=$(df | grep "$mountpoint" | eval "$awkcmd")
	sizeratio=$(($available/$filesize))

	if [ $sizeratio -ge $min_freespace_to_log_ratio ]; then
		echo "$datetime, $log_entry" >> $logfile
	else
		echo "BinAuth - log file too big, please archive contents" | logger -p "daemon.err" -s -t "opennds[$ndspid]: "
	fi
}
# END of functions
##################

#Configure log location
configure_log_location

#
# Get the action method from NDS ie the first command line argument.
#
# Possible values are:
# "auth_client" - NDS requests validation of the client
# "client_auth" - NDS has authorised the client
# "client_deauth" - NDS has deauthenticated the client
# "idle_deauth" - NDS has deauthenticated the client because the idle timeout duration has been exceeded
# "timeout_deauth" - NDS has deauthenticated the client because the session length duration has been exceeded
# "downquota_deauth" - NDS has deauthenticated the client because the client's download quota has been exceeded
# "upquota_deauth" - NDS has deauthenticated the client because the client's upload quota has been exceeded
# "ndsctl_auth" - NDS has authorised the client because of an ndsctl command
# "ndsctl_deauth" - NDS has deauthenticated the client because of an ndsctl command
# "shutdown_deauth" - NDS has deauthenticated the client because it received a shutdown command
#
action=$1

if [ $action = "auth_client" ]; then
	#
	# The redir parameter is sent to this script as the fifth command line argument in url-encoded form.
	#
	# In the case of a simple splash.html login, redir is the URL originally requested by the client CPD.
	#
	# In the case of PreAuth or FAS it MAY contain not only the originally requested URL
	# but also a payload of custom variables defined by Preauth or FAS.
	#
	# It may just be simply url-encoded (fas_secure_enabled 0 and 1), or
	# aes encrypted (fas_secure_enabled 2)
	#
	# The username and password variables may be passed from splash.html, FAS or PreAuth and can be used
	# not just as "username" and "password" but also as general purpose string variables to pass information to BinAuth.
	#
	# The client User Agent string is sent as the sixth command line argument.
	# This can be used to determine much information about the capabilities of the client.
	# In this case it will be added to the log.
	#
	# customdata is sent in argument nine
	#
	# redir, useragent and customdata are url-encoded, so decode:
	redir_enc=$5
	redir=$(printf "${redir_enc//%/\\x}")
	useragent_enc=$6
	useragent=$(printf "${useragent_enc//%/\\x}")
	customdata_enc=$9
	customdata=$(printf "${customdata_enc//%/\\x}")

	log_entry="method=$1, clientmac=$2, clientip=$7, username=$3, password=$4, redir=$redir, useragent=$useragent, token=$8, custom=$customdata"

elif [ $action = "ndsctl_auth" ]; then
	# in the case of authmon (FAS level 3) or ndsctl authentication
	customdata_enc=$8
	customdata=$(printf "${customdata_enc//%/\\x}")
	log_entry="method=$1, clientmac=$2, bytes_incoming=$3, bytes_outgoing=$4, session_start=$5, session_end=$6, token=$7, custom=$customdata_enc"

else
	log_entry="method=$1, clientmac=$2, bytes_incoming=$3, bytes_outgoing=$4, session_start=$5, session_end=$6, token=$7"
fi

# Append to the log.
write_log

# Set length of session in seconds (eg 24 hours is 86400 seconds - if set to 0 then defaults to global sessiontimeout value):
session_length=0

# Set Rate and Quota values for the client
# The session length, rate and quota values could be determined by FAS or PreAuth, on a per client basis, and embedded in the customdata variable payload.
# rates are in kb/s, quotas are in kB. Setting to 0 means no limit
upload_rate=0
download_rate=0
upload_quota=0
download_quota=0

# Finally before exiting, output the session length, upload rate, download rate, upload quota and download quota.

echo "$session_length $upload_rate $download_rate $upload_quota $download_quota"

# exit 0 tells NDS is is ok to allow the client to have access.
# exit 1 would tell NDS to deny access.
exit 0
