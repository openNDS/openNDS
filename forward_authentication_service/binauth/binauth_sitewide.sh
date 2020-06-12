#!/bin/sh
#Copyright (C) The openNDS Contributors 2004-2020
#Copyright (C) BlueWave Projects and Services 2015-2020
#This software is released under the GNU GPL license.

# This is an example script for BinAuth

# The templated splash page, splash_sitewide.html, is specifically designed to work with this BinAuth script.
# It verifies a client username and password and sets the session length.

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
# 1. splash_sitewide.html
# 2. PreAuth
# 3. FAS
#



# Customise the Logfile location:
#
# mountpoint is the mount point for the storage the log is to be kept on
#
# /tmp on OpenWrt is tmpfs (ram disk) and does not survive a reboot.
#
# /run on Raspbian is also tmpfs and also does not survive a reboot.
#
# These choices for OpenWrt and Raspbian are a good default for testing purposes
# as long term use on internal flash could cause memory wear
# In a production system, use the mount point of a usb drive for example
#
#
# logdir is the directory path for the log file
#
#
# logname is the name of the log file
#

#For Openwrt:
mountpoint="/tmp"
logdir="/tmp/ndslog/"
logname="binauthlog.log"

#For Raspbian:
#mountpoint="/run"
#logdir="/run/ndslog/"
#logname="binauthlog.log"

# functions:

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

#
# Get the action method from NDS ie the first command line argument.
#
# Possible values are:
# "auth_client" - NDS requests validation of the client
# "client_auth" - NDS has authorised the client
# "client_deauth" - NDS has deauthorised the client
# "idle_deauth" - NDS has deauthorised the client because the idle timeout duration has been exceeded
# "timeout_deauth" - NDS has deauthorised the client because the session length duration has been exceeded
# "ndsctl_auth" - NDS has authorised the client because of an ndsctl command
# "ndsctl_deauth" - NDS has deauthorised the client because of an ndsctl command
# "shutdown_deauth" - NDS has deauthorised the client because it received a shutdown command
#
action=$1
exit_code=1

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
	# aes encrypted (fas_secure_enabled 2 and 3)
	#
	# The username and password variables should be passed from splash_sitewide.html, FAS or PreAuth and can be used
	# not just as "username" and "password" but also as general purpose string variables to pass information to BinAuth.
	#
	# The client User Agent string is sent as the sixth command line argument.
	# This can be used to determine much information about the capabilities of the client.
	# In this case it will be added to the log.
	#

	userlist="/etc/opennds/userlist.dat"
	varlist="username password session_length"

	while read user; do

		for var in $varlist; do
			nextvar=$(echo "$varlist" | awk '{for(i=1;i<=NF;i++) if ($i=="'$var'") printf $(i+1)}')
			eval $var=$(echo "$user" | awk -F "$var=" '{print $2}' | awk -F ", $nextvar=" '{print $1}')
		done

		if [ "$username" = "$3" -a "$password" = "$4" ]; then
			echo "$session_length 0 0"
			exit_code=0
			break
		else
			exit_code=1
		fi

	done < $userlist

	# Both redir and useragent are url-encoded, so decode:
	redir_enc=$5
	redir=$(printf "${redir_enc//%/\\x}")
	useragent_enc=$6
	useragent=$(printf "${useragent_enc//%/\\x}")

	log_entry="method=$1, clientmac=$2, clientip=$7, username=$3, password=$4"
	log_entry="$log_entry, redir=$redir, useragent=$useragent, deny_access=$exit_code, token=$9"
else
	log_entry="method=$1, clientmac=$2, bytes_incoming=$3, bytes_outgoing=$4, session_start=$5, session_end=$6, token=$7"
fi

# Append to the log.
write_log

exit $exit_code

