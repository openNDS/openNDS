#!/bin/sh
#Copyright (C) The openNDS Contributors 2004-2023
#Copyright (C) BlueWave Projects and Services 2015-2024
#Copyright (C) Francesco Servida 2023
#This software is released under the GNU GPL license.
#
# Warning - shebang sh is for compatibliity with busybox ash (eg on OpenWrt)
# This must be changed to bash for use on generic Linux
#

# Title of this theme:
title="theme_voucher"

# functions:

generate_splash_sequence() {
	login_with_voucher
}

header() {
# Define a common header html for every page served
	gatewayurl=$(printf "${gatewayurl//%/\\x}")
	echo "<!DOCTYPE html>
		<html>
		<head>
		<meta http-equiv=\"Cache-Control\" content=\"no-cache, no-store, must-revalidate\">
		<meta http-equiv=\"Pragma\" content=\"no-cache\">
		<meta http-equiv=\"Expires\" content=\"0\">
		<meta charset=\"utf-8\">
		<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
		<link rel=\"shortcut icon\" href=\"/images/splash.jpg\" type=\"image/x-icon\">
		<style>
			:root {
				--primary-color: #4285f4;
				--secondary-color: #34a853;
				--accent-color: #ea4335;
				--background-color: #f8f9fa;
				--text-color: #202124;
				--light-text: #5f6368;
				--border-color: #dadce0;
			}
			
			* {
				box-sizing: border-box;
				margin: 0;
				padding: 0;
			}
			
			body {
				font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
				line-height: 1.6;
				color: var(--text-color);
				background-color: var(--background-color);
				padding: 0;
				margin: 0;
			}
			
			.offset {
				padding: 20px;
				max-width: 800px;
				margin: 0 auto;
			}
			
			.insert {
				background-color: white;
				border-radius: 8px;
				box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
				padding: 25px;
				margin-bottom: 20px;
			}
			
			h1, h2, h3, h4 {
				color: var(--primary-color);
				margin-bottom: 15px;
			}
			
			hr {
				border: none;
				border-top: 1px solid var(--border-color);
				margin: 20px 0;
			}
			
			p {
				margin-bottom: 15px;
			}
			
			input[type=\"text\"], input[type=\"password\"] {
				width: 100%;
				padding: 12px;
				margin: 8px 0;
				display: inline-block;
				border: 1px solid var(--border-color);
				border-radius: 4px;
				box-sizing: border-box;
			}
			
			input[type=\"button\"], input[type=\"submit\"] {
				background-color: var(--primary-color);
				color: white;
				padding: 12px 20px;
				margin: 8px 0;
				border: none;
				border-radius: 4px;
				cursor: pointer;
				font-weight: bold;
				transition: background-color 0.3s;
			}
			
			input[type=\"button\"]:hover, input[type=\"submit\"]:hover {
				background-color: #3367d6;
			}
			
			big-red {
				color: var(--accent-color);
				font-size: 1.2em;
				font-weight: bold;
				display: block;
				margin: 10px 0;
			}
			
			med-blue {
				color: var(--primary-color);
				font-size: 1.5em;
				font-weight: bold;
				display: block;
				margin: 10px 0;
			}
			
			italic-black {
				font-style: italic;
				color: var(--light-text);
				display: block;
				margin: 10px 0;
			}
			
			.terms-container {
				max-height: 300px;
				overflow-y: auto;
				border: 1px solid var(--border-color);
				padding: 15px;
				margin: 15px 0;
				border-radius: 4px;
			}
			
			.info-box {
				background-color: rgba(66, 133, 244, 0.1);
				border-left: 4px solid var(--primary-color);
				padding: 10px 15px;
				margin: 15px 0;
			}
			
			.ad-container {
				background-color: #f1f3f4;
				border-radius: 4px;
				padding: 15px;
				margin-top: 20px;
				text-align: center;
			}
			
			.footer {
				font-size: 0.8em;
				color: var(--light-text);
				text-align: center;
				margin-top: 30px;
				padding-top: 20px;
				border-top: 1px solid var(--border-color);
			}
			
			@media screen and (max-width: 600px) {
				.offset {
					padding: 10px;
				}
				
				.insert {
					padding: 15px;
				}
			}
		</style>
		<title>$gatewayname</title>
		</head>
		<body>
		<div class=\"offset\">
		<div class=\"insert\">
	"
}

footer() {
	# Define a common footer html for every page served
	year=$(date +'%Y')
	echo "
		<div class=\"ad-container\">
			<!-- Ad Placeholder - Replace this with your actual ad code -->
			<p>Advertisement Space</p>
			<div style=\"width:100%; height:90px; background:#e0e0e0; display:flex; align-items:center; justify-content:center;\">
				<p>Your Ad Could Be Here</p>
			</div>
		</div>
		
		<div class=\"footer\">
			<div style=\"display:flex; align-items:center; justify-content:center; margin-bottom:15px;\">
				<img style=\"height:60px; width:60px; margin-right:15px;\" src=\"$gatewayurl""$imagepath\" alt=\"Hotspot Logo\">
				<div>
					<p>&copy; Portal: BlueWave Projects and Services 2015 - $year</p>
					<p>Portal Version: $version</p>
				</div>
			</div>
		</div>
		</div>
		</div>
		</body>
		</html>
	"

	exit 0
}

login_with_voucher() {
	# This is the simple click to continue splash page with no client validation.
	# The client is however required to accept the terms of service.

	if [ "$tos" = "accepted" ]; then
		#echo "$tos <br>"
		#echo "$voucher <br>"
		voucher_validation
		footer
	fi

	voucher_form
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

	##############################################################################################################################
	# WARNING
	# The voucher roll is written to on every login
	# If its location is on router flash, this **WILL** result in non-repairable failure of the flash memory
	# and therefore the router itself. This will happen, most likely within several months depending on the number of logins.
	#
	# The location is set here to be the same location as the openNDS log (logdir)
	# By default this will be on the tmpfs (ramdisk) of the operating system.
	# Files stored here will not survive a reboot.

	voucher_roll="$logdir""vouchers.txt"

	#
	# In a production system, the mountpoint for logdir should be changed to the mount point of some external storage
	# eg a usb stick, an external drive, a network shared drive etc.
	#
	# See "Customise the Logfile location" at the end of this file
	#
	##############################################################################################################################

	output=$(grep $voucher $voucher_roll | head -n 1) # Store first occurence of voucher as variable
	#echo "$output <br>" #Matched line
 	if [ $(echo -n $output | wc -w) -ge 1 ]; then 
		#echo "Voucher Found - Checking Validity <br>"
		current_time=$(date +%s)
		voucher_token=$(echo -n $output | sed -r "s#([a-zA-Z0-9-]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+)#\1#")
		voucher_rate_down=$(echo -n $output | sed -r "s#([a-zA-Z0-9-]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+)#\2#")
		voucher_rate_up=$(echo -n $output | sed -r "s#([a-zA-Z0-9-]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+)#\3#")
		voucher_quota_down=$(echo -n $output | sed -r "s#([a-zA-Z0-9-]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+)#\4#")
		voucher_quota_up=$(echo -n $output | sed -r "s#([a-zA-Z0-9-]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+)#\5#")
		voucher_time_limit=$(echo -n $output | sed -r "s#([a-zA-Z0-9-]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+)#\6#")
		voucher_first_punched=$(echo -n $output | sed -r "s#([a-zA-Z0-9-]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+)#\7#")
		
		# Set limits according to voucher
		upload_rate=$voucher_rate_up
		download_rate=$voucher_rate_down
		upload_quota=$voucher_quota_up
		download_quota=$voucher_quota_down

		if [ $voucher_first_punched -eq 0 ]; then
			#echo "First Voucher Use"
			# "Punch" the voucher by setting the timestamp to now
			voucher_expiration=$(($current_time + $voucher_time_limit * 60))
			# Override session length according to voucher
			sessiontimeout=$voucher_time_limit
			sed -i -r "s/($voucher.*,)(0)/\1$current_time/" $voucher_roll
			return 0
		else
			#echo "Voucher Already Used, Checking validity <br>"
			# Current timestamp <= than Punch Timestamp + Validity (minutes) * 60 secs/minute
			voucher_expiration=$(($voucher_first_punched + $voucher_time_limit * 60))

			if [ $current_time -le $voucher_expiration ]; then
				time_remaining=$(( ($voucher_expiration - $current_time) / 60 ))
				#echo "Voucher is still valid - You have $time_remaining minutes left <br>"
				# Override session length according to voucher
				sessiontimeout=$time_remaining
				# Nothing to change in the roll
				return 0
			else
				#echo "Voucher has expired, please try another one <br>"
				# Delete expired voucher from roll
				sed -i "/$voucher/"d $voucher_roll
				return 1
			fi
		fi
	else
		echo "No Voucher Found - Retry <br>"
		return 1
	fi
	
	# Should not get here
	return 1
}

voucher_validation() {
	originurl=$(printf "${originurl//%/\\x}")

	check_voucher
	if [ $? -eq 0 ]; then
		# Refresh quotas with ones imported from the voucher roll.
		quotas="$sessiontimeout $upload_rate $download_rate $upload_quota $download_quota"
		# Set voucher used (useful if for accounting reasons you track who received which voucher)
		userinfo="$title - $voucher"

		# Authenticate and write to the log - returns with $ndsstatus set
		auth_log

		# output the landing page - note many CPD implementations will close as soon as Internet access is detected
		# The client may not see this page, or only see it briefly
		auth_success="
			<div style=\"text-align:center; padding:20px 0;\">
				<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"64\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"#34a853\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\">
					<path d=\"M22 11.08V12a10 10 0 1 1-5.93-9.14\"></path>
					<polyline points=\"22 4 12 14.01 9 11.01\"></polyline>
				</svg>
				<h2 style=\"color:#34a853; margin-top:10px;\">Successfully Connected!</h2>
			</div>
			
			<div class=\"info-box\">
				<p>Your voucher is valid for <strong>$sessiontimeout minutes</strong>.</p>
				<p>You can now use your Browser, Email, and other network Apps as you normally would.</p>
			</div>
			
			<p style=\"margin-top:20px;\">
				Your device originally requested:
				<a href=\"$originurl\" style=\"word-break:break-all;\">$originurl</a>
			</p>
			
			<div style=\"text-align:center; margin-top:20px;\">
				<input type=\"button\" VALUE=\"Continue to Website\" onClick=\"location.href='$originurl'\" >
			</div>
		"
		
		auth_fail="
			<div style=\"text-align:center; padding:20px 0;\">
				<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"64\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"#ea4335\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\">
					<circle cx=\"12\" cy=\"12\" r=\"10\"></circle>
					<line x1=\"15\" y1=\"9\" x2=\"9\" y2=\"15\"></line>
					<line x1=\"9\" y1=\"9\" x2=\"15\" y2=\"15\"></line>
				</svg>
				<h2 style=\"color:#ea4335; margin-top:10px;\">Connection Failed</h2>
			</div>
			
			<div class=\"info-box\">
				<p>Something went wrong and you have failed to log in.</p>
				<p>Your login attempt probably timed out.</p>
			</div>
			
			<div style=\"text-align:center; margin-top:20px;\">
				<input type=\"button\" VALUE=\"Try Again\" onClick=\"location.href='$originurl'\" >
			</div>
		"

		if [ "$ndsstatus" = "authenticated" ]; then
			echo "$auth_success"
		else
			echo "$auth_fail"
		fi
	else
		echo "
			<div style=\"text-align:center; padding:20px 0;\">
				<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"64\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"#ea4335\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\">
					<circle cx=\"12\" cy=\"12\" r=\"10\"></circle>
					<line x1=\"12\" y1=\"8\" x2=\"12\" y2=\"12\"></line>
					<line x1=\"12\" y1=\"16\" x2=\"12.01\" y2=\"16\"></line>
				</svg>
				<h2 style=\"color:#ea4335; margin-top:10px;\">Invalid Voucher</h2>
				<p>The voucher you entered is not valid.</p>
			</div>
			
			<div style=\"text-align:center; margin-top:20px;\">
				<input type=\"button\" VALUE=\"Try Again\" onClick=\"location.href='$originurl'\" >
			</div>
		"
	fi

	# Serve the rest of the page:
	read_terms
	footer
}

voucher_form() {
	# Define a click to Continue form

	# From openNDS v10.2.0 onwards, QL code scanning is supported to pre-fill the "voucher" field in this voucher_form page.
	#
	# The QL code must be of the link type and be of the following form:
	#
	# http://[gatewayfqdn]/login?voucher=[voucher_code]
	#
	# where [gatewayfqdn] defaults to status.client (can be set in the config)
	# and [voucher_code] is of course the unique voucher code for the current user

	# Get the voucher code:

	voucher_code=$(echo "$cpi_query" | awk -F "voucher%3d" '{printf "%s", $2}' | awk -F "%26" '{printf "%s", $1}')

	echo "
		<h1>Welcome to our Hotspot</h1>
		<div class=\"info-box\">
			<p><strong>Your IP:</strong> $clientip</p>
			<p><strong>Your MAC:</strong> $clientmac</p>
		</div>
		
		<form action=\"/opennds_preauth/\" method=\"get\" style=\"margin-top:20px;\">
			<input type=\"hidden\" name=\"fas\" value=\"$fas\">
			
			<div style=\"margin-bottom:15px;\">
				<label for=\"voucher-input\"><strong>Voucher Code:</strong></label>
				<input type=\"text\" id=\"voucher-input\" name=\"voucher\" value=\"$voucher_code\" placeholder=\"Enter your voucher code\" required>
			</div>
			
			<div style=\"display:flex; align-items:center; margin-bottom:20px;\">
				<input type=\"checkbox\" id=\"tos-checkbox\" name=\"tos\" value=\"accepted\" required style=\"width:auto; margin-right:10px;\">
				<label for=\"tos-checkbox\">I accept the <a href=\"#\" onclick=\"document.getElementById('tos-form').submit(); return false;\">Terms of Service</a></label>
			</div>
			
			<input type=\"submit\" value=\"Connect\" style=\"width:100%;\">
		</form>
		
		<form id=\"tos-form\" action=\"/opennds_preauth/\" method=\"get\" style=\"display:none;\">
			<input type=\"hidden\" name=\"fas\" value=\"$fas\">
			<input type=\"hidden\" name=\"terms\" value=\"yes\">
		</form>
	"

	footer
}

read_terms() {
	#terms of service button - now hidden, using link in form instead
	echo "
		<form action=\"/opennds_preauth/\" method=\"get\" style=\"display:none;\">
			<input type=\"hidden\" name=\"fas\" value=\"$fas\">
			<input type=\"hidden\" name=\"terms\" value=\"yes\">
			<input type=\"submit\" value=\"Read Terms of Service\">
		</form>
	"
}

display_terms() {
	# This is the all important "Terms of service"
	# Edit this long winded generic version to suit your requirements.
	####
	# WARNING #
	# It is your responsibility to ensure these "Terms of Service" are compliant with the REGULATIONS and LAWS of your Country or State.
	# In most locations, a Privacy Statement is an essential part of the Terms of Service.
	####

	echo "
		<h1>Terms of Service</h1>
		
		<div style=\"margin:20px 0; text-align:right;\">
			<input type=\"button\" VALUE=\"Back to Login\" onClick=\"history.go(-1);return true;\">
		</div>
		
		<div class=\"info-box\">
			<h3>Privacy Statement</h3>
			<p>
				By logging in to the system, you grant your permission for this system to store any data you provide for
				the purposes of logging in, along with the networking parameters of your device that the system requires to function.
			</p>
			<p>
				All information is stored for your convenience and for the protection of both yourself and us.
				All information collected by this system is stored in a secure manner and is not accessible by third parties.
			</p>
		</div>
		
		<div class=\"terms-container\">
			<h3>Terms of Service</h3>
			<p><strong>Access is granted on a basis of trust that you will NOT misuse or abuse that access in any way.</strong></p>
			
			<h4>Proper Use</h4>
			<p>
				This Hotspot provides a wireless network that allows you to connect to the Internet.<br>
				<strong>Use of this Internet connection is provided in return for your FULL acceptance of these Terms Of Service.</strong>
			</p>
			<p>
				<strong>You agree</strong> that you are responsible for providing security measures that are suited for your intended use of the Service.
				For example, you shall take full responsibility for taking adequate measures to safeguard your data from loss.
			</p>
			<p>
				While the Hotspot uses commercially reasonable efforts to provide a secure service,
				the effectiveness of those efforts cannot be guaranteed.
			</p>
			<p>
				<strong>You may</strong> use the technology provided to you by this Hotspot for the sole purpose
				of using the Service as described here.
				You must immediately notify the Owner of any unauthorized use of the Service or any other security breach.<br><br>
				We will give you an IP address each time you access the Hotspot, and it may change.
				<br>
				<strong>You shall not</strong> program any other IP or MAC address into your device that accesses the Hotspot.
				You may not use the Service for any other reason, including reselling any aspect of the Service.
				Other examples of improper activities include, without limitation:
			</p>
			<ol>
				<li>
					downloading or uploading such large volumes of data that the performance of the Service becomes
					noticeably degraded for other users for a significant period;
				</li>
				<li>
					attempting to break security, access, tamper with or use any unauthorized areas of the Service;
				</li>
				<li>
					removing any copyright, trademark or other proprietary rights notices contained in or on the Service;
				</li>
				<li>
					attempting to collect or maintain any information about other users of the Service
					(including usernames and/or email addresses) or other third parties for unauthorized purposes;
				</li>
				<li>
					logging onto the Service under false or fraudulent pretenses;
				</li>
				<li>
					creating or transmitting unwanted electronic communications such as SPAM or chain letters to other users
					or otherwise interfering with other user's enjoyment of the service;
				</li>
				<li>
					transmitting any viruses, worms, defects, Trojan Horses or other items of a destructive nature; or
				</li>
				<li>
					using the Service for any unlawful, harassing, abusive, criminal or fraudulent purpose.
				</li>
			</ol>
			
			<h4>Content Disclaimer</h4>
			<p>
				The Hotspot Owners do not control and are not responsible for data, content, services, or products
				that are accessed or downloaded through the Service.
				The Owners may, but are not obliged to, block data transmissions to protect the Owner and the Public.
			</p>
			<p>
				The Owners, their suppliers and their licensors expressly disclaim to the fullest extent permitted by law,
				all express, implied, and statutary warranties, including, without limitation, the warranties of merchantability
				or fitness for a particular purpose.
			</p>
			<p>
				The Owners, their suppliers and their licensors expressly disclaim to the fullest extent permitted by law
				any liability for infringement of proprietory rights and/or infringement of Copyright by any user of the system.
				Login details and device identities may be stored and be used as evidence in a Court of Law against such users.
			</p>
			
			<h4>Limitation of Liability</h4>
			<p>
				Under no circumstances shall the Owners, their suppliers or their licensors be liable to any user or
				any third party on account of that party's use or misuse of or reliance on the Service.
			</p>
			
			<h4>Changes to Terms of Service and Termination</h4>
			<p>
				We may modify or terminate the Service and these Terms of Service and any accompanying policies,
				for any reason, and without notice, including the right to terminate with or without notice,
				without liability to you, any user or any third party. Please review these Terms of Service
				from time to time so that you will be apprised of any changes.
			</p>
			<p>
				We reserve the right to terminate your use of the Service, for any reason, and without notice.
				Upon any such termination, any and all rights granted to you by this Hotspot Owner shall terminate.
			</p>
			
			<h4>Indemnity</h4>
			<p>
				<strong>You agree</strong> to hold harmless and indemnify the Owners of this Hotspot,
				their suppliers and licensors from and against any third party claim arising from
				or in any way related to your use of the Service, including any liability or expense arising from all claims,
				losses, damages (actual and consequential), suits, judgments, litigation costs and legal fees, of every kind and nature.
			</p>
		</div>
		
		<div style=\"margin:20px 0; text-align:center;\">
			<input type=\"button\" VALUE=\"I Understand and Accept\" onClick=\"history.go(-1);return true;\">
		</div>
	"
	footer
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
# sessiontimeout="100"
#
# eg for 20 hours:
# sessiontimeout=$((20*60))
#
# eg for 20 hours and 30 minutes:
# sessiontimeout=$((20*60+30))
sessiontimeout="0"

# Set Rate and Quota values for the client
# The session length, rate and quota values could be determined by this script, on a per client basis.
# rates are in kb/s, quotas are in kB. - if set to 0 then defaults to global value).
upload_rate="0"
download_rate="0"
upload_quota="0"
download_quota="0"

quotas="$sessiontimeout $upload_rate $download_rate $upload_quota $download_quota"

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
