#!/bin/sh
#Copyright (C) The openNDS Contributors 2004-2021
#Copyright (C) BlueWave Projects and Services 2015-2021
#Copyright (C) Francesco Servida 2022
#This software is released under the GNU GPL license.
#
# Warning - shebang sh is for compatibliity with busybox ash (eg on OpenWrt)
# This must be changed to bash for use on generic Linux
#

# read language strings
. /usr/lib/opennds/theme_voucher_*.sh

[[ "$logdir" == ""  ]] && logdir="/tmp/ndslog/"
voucher_roll="$logdir""vouchers.txt"
voucher_flash="/usr/lib/opennds/vouchers.txt"

# generate vouchers
if ! [ -e $voucher_flash ]; then
	rm $voucher_roll
	count=408
	while [ $count -gt 0 ]; do
		token=$(</dev/urandom tr -dc A-Za-z0-9 | head -c 8)
		echo ${token:0:4}-${token:4:4},600,1024,4096,0,0,0  >> $voucher_roll
		count=$(( $count - 1 )) # minutes_valid, speed_up, down, quota_up, down, used_token
	done
	cp $voucher_roll $voucher_flash
fi

# if voucher does not exist in tmpfs, copy it from flash to tmpfs
[ -e $voucher_roll ] || cp $voucher_flash $voucher_roll

# you may create a cron job to update it from tmpfs to flash, once a month may not harm the flash.


# Title of this theme:
title="theme_voucher"

#### required functions ####

header(){
	echo '
		<!DOCTYPE html>
		<html>
		<head>
		<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
		<meta http-equiv="Pragma" content="no-cache">
		<meta http-equiv="Expires" content="0">
		<meta charset="utf-8">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		<link rel="shortcut icon" href="/images/splash.jpg" type="image/x-icon">
		<link rel="stylesheet" type="text/css" href="/splash.css">
		<title></title>
		</head>
		<body>
		<div class="offset">
		<div class="insert" style="max-width:100%;">
	'
}

display_terms() {
	echo "$terms_privacy"
	echo "$terms_service"
	echo "$terms_use"
	echo "$terms_content"
	echo "$terms_liability"
	echo "$terms_indemnity"
	footer
}

footer() {  # Define a common footer html for every page served

	year=$(date +'%Y')
	echo "
		<hr>
		<div style=\"font-size:0.5em;\">
			<br>
			<img style=\"height:60px; width:60px; float:left;\" src=\"$imagepath\" alt=\"Splash Page: For access to the Internet.\">
			&copy; Portal: BlueWave Projects and Services 2015 - $year<br>
			<br>
			Portal Version: $version fff
			<br><br><br><br>
		</div>
		</div>
		</div>
		</body>
		</html>
	"

	exit 0
}

generate_splash_sequence() {
	
	if [ "$tos" = "accepted" ]; then
		#echo "$tos <br>"
		#echo "$voucher <br>"
		voucher_validation
		footer
	fi

	printf "$vform" "$clientip" "$clientmac" "$fas"

	echo "$terms_button"
	footer
}



#### custom functions ####

voucher_validation() {

	check_voucher
	if [ $? -eq 0 ]; then

		# Set voucher used (useful if for accounting reasons you track who received which voucher)
		userinfo="$title - $voucher"

		# Authenticate and write to the log - returns with $ndsstatus set
		auth_log

		# output the landing page - note many CPD implementations will close as soon as Internet access is detected
		# The client may not see this page, or only see it briefly
		if [ "$ndsstatus" = "authenticated" ]; then
			echo "$auth_success"
		else
			echo "$auth_fail"
		fi
	else
		echo "$invalid_voucher"
	fi

	# Serve the rest of the page:
	echo "$terms_button"
	footer
}

check_voucher() {

	# Strict Voucher Validation for shell escape prevention - Only alphanumeric (and dash character) allowed.
	if validation=$(echo -n $voucher | grep -E "^[a-zA-Z0-9-]{9}$"); then
		#echo "Voucher Validation successful, proceeding"
		: #no-op
	else
		#echo "Invalid Voucher - Voucher must be alphanumeric (and dash) of 9 chars."
		return 1
	fi



	output=$(grep $voucher $voucher_roll | head -n 1) # Store first occurence of voucher as variable
	#echo "$output <br>" #Matched line

	
	IFS=',' read -r voucher_token voucher_length voucher_upload_rate voucher_download_rate voucher_upload_quota voucher_download_quota voucher_expiration << EOF
$output
EOF

	current_time=$(date +%s)
	if [ $voucher_expiration -eq 0 ]; then
		voucher_expiration=$(($current_time + $voucher_length * 60))
		sed -i -r "s/($voucher.*,)(0)/\1$voucher_expiration/" $voucher_roll
	else
		# Override session length according to voucher
		voucher_length=$(( ($voucher_expiration - $current_time) / 60 ))
	fi

	# Refresh quotas with ones imported from the voucher roll.
	quotas="$voucher_length $voucher_upload_rate $voucher_download_rate $voucher_upload_quota $voucher_download_quota"


	if [ $voucher_length -gt 0 ]; then
		#echo "Voucher valid <br>"
		return 0
	else
		#echo "Voucher has expired, please try another one <br>"
		return 1
	fi
}


#### end of functions ####






#################################################
#						#
#  Start - Main entry point for this Theme	#
#						#
#  Parameters set here overide those		#
#  set in libopennds.sh			#
#						#
#################################################

# Quotas and Data Rates
#########################################
# Set length of session in minutes (eg 24 hours is 1440 minutes - if set to 0 then defaults to global sessiontimeout value):
# eg for 100 mins:
# session_length="100"
#
# eg for 20 hours:
# session_length=$((20*60))
#
# eg for 20 hours and 30 minutes:
# session_length=$((20*60+30))
session_length="0"

# Set Rate and Quota values for the client
# The session length, rate and quota values could be determined by this script, on a per client basis.
# rates are in kb/s, quotas are in kB. - if set to 0 then defaults to global value).
upload_rate="0"
download_rate="0"
upload_quota="0"
download_quota="0"

quotas="$session_length $upload_rate $download_rate $upload_quota $download_quota"

# Define the list of Parameters we expect to be sent sent from openNDS ($ndsparamlist):
# Note you can add custom parameters to the config file and to read them you must also add them here.
# Custom parameters are "Portal" information and are the same for all clients eg "admin_email" and "location" 
ndscustomparams=""
ndscustomimages=""
ndscustomfiles=""

ndsparamlist="$ndsparamlist $ndscustomparams $ndscustomimages $ndscustomfiles"

# The list of FAS Variables used in the Login Dialogue generated by this script is $fasvarlist and defined in libopennds.sh
#
# Additional custom FAS variables defined in this theme should be added to $fasvarlist here.
additionalthemevars="tos voucher"

fasvarlist="$fasvarlist $additionalthemevars"

# You can choose to define a custom string. This will be b64 encoded and sent to openNDS.
# There it will be made available to be displayed in the output of ndsctl json as well as being sent
#	to the BinAuth post authentication processing script if enabled.
# Set the variable $binauth_custom to the desired value.
# Values set here can be overridden by the themespec file

#binauth_custom="This is sample text sent from \"$title\" to \"BinAuth\" for post authentication processing."

# Encode and activate the custom string
#encode_custom

# Set the user info string for logs (this can contain any useful information)
userinfo="$title"

##############################################################################################################################
# Customise the Logfile location.
##############################################################################################################################
#Note: the default uses the tmpfs "temporary" directory to prevent flash wear.
# Override the defaults to a custom location eg a mounted USB stick.
#mountpoint="/mylogdrivemountpoint"
#logdir="$mountpoint/ndslog/"
#logname="ndslog.log"
