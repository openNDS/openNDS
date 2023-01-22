#!/bin/sh
#Copyright (C) The openNDS Contributors 2004-2021
#Copyright (C) BlueWave Projects and Services 2015-2021
#Copyright (C) Francesco Servida 2022
#This software is released under the GNU GPL license.
#
# Warning - shebang sh is for compatibliity with busybox ash (eg on OpenWrt)
# This must be changed to bash for use on generic Linux
#

vform='
	<med-blue>
		Welcome!
	</med-blue><br>
	<hr>
	Your IP: %s <br>
	Your MAC: %s <br>
	<hr>
	<form action="/opennds_preauth/" method="get">
		<input type="hidden" name="fas" value="%s"> 
		<input type="checkbox" name="tos" value="accepted" required> I accept the Terms of Service<br>
		Voucher #: <input type="text" name="voucher" value="" required><br>
		<input type="submit" value="Connect">
	</form>
	<br>
'
#	Your IP: $clientip <br>
#	Your MAC: $clientmac <br>

invalid_voucher='
	<big-red>Voucher is not Valid, click Continue to restart login<br></big-red>
	<form>
		<input type="button" VALUE="Continue" onClick="history.go(-1);return true;">
	</form>
'

auth_success='
	<p>
		<big-red>
			You are now logged in and have been granted access to the Internet.
		</big-red>
		<hr>
	</p>
	This voucher is valid for $session_length minutes.
	<hr>
	<p>
		<italic-black>
			You can use your Browser, Email and other network Apps as you normally would.
		</italic-black>
	</p>
	<p>
		Your device originally requested <b>$originurl</b>
		<br>
		Click or tap Continue to go to there.
	</p>
	<form>
		<input type="button" VALUE="Continue" onClick="history.go(-1);return true;">
	</form>
	<hr>
'

#		<input type="button" VALUE="Continue" onClick="location.href='"'"'$originurl'"'"'" >

auth_fail='
	<p>
		<big-red>
			Something went wrong and you have failed to log in.
		</big-red>
		<hr>
	</p>
	<hr>
	<p>
		<italic-black>
			Your login attempt probably timed out.
		</italic-black>
	</p>
	<p>
		<br>
		Click or tap Continue to try again.
	</p>
	<form>
		<input type="button" VALUE="Continue" onClick="history.go(-1);return true;">
	</form>
	<hr>
'

terms_button='
	<form action="/opennds_preauth/" method="get">
		<input type="hidden" name="fas" value="$fas">
		<input type="hidden" name="terms" value="yes">
		<input type="submit" value="Read Terms of Service   " >
	</form>
'


# WARNING #
# This is the all important "Terms of service"
# Edit this long winded generic version to suit your requirements.
# It is your responsibility to ensure these "Terms of Service" are compliant with the REGULATIONS and LAWS of your Country or State.
# In most locations, a Privacy Statement is an essential part of the Terms of Service.
	
terms_privacy='
	<b style="color:red;">Privacy.</b><br>
	<b>
		By logging in to the system, you grant your permission for this system to store any data you provide for
		the purposes of logging in, along with the networking parameters of your device that the system requires to function.<br>
		All information is stored for your convenience and for the protection of both yourself and us.<br>
		All information collected by this system is stored in a secure manner and is not accessible by third parties.<br>
	</b><hr>
'

terms_service='
	<b style="color:red;">Terms of Service for this Hotspot.</b> <br>
	<b>Access is granted on a basis of trust that you will NOT misuse or abuse that access in any way.</b><hr>
	<b>Please scroll down to read the Terms of Service in full or click the Continue button to return to the Acceptance Page</b>
	<form>
		<input type="button" VALUE="Continue" onClick="history.go(-1);return true;">
	</form>
'

terms_use='
	<hr>
	<b>Proper Use</b>
	<p>
		This Hotspot provides a wireless network that allows you to connect to the Internet. <br>
		<b>Use of this Internet connection is provided in return for your FULL acceptance of these Terms Of Service.</b>
	</p>
	<p>
		<b>You agree</b> that you are responsible for providing security measures that are suited for your intended use of the Service.
		For example, you shall take full responsibility for taking adequate measures to safeguard your data from loss.
	</p>
	<p>
		While the Hotspot uses commercially reasonable efforts to provide a secure service,
		the effectiveness of those efforts cannot be guaranteed.
	</p>
	<p>
		<b>You may</b> use the technology provided to you by this Hotspot for the sole purpose
		of using the Service as described here.
		You must immediately notify the Owner of any unauthorized use of the Service or any other security breach.<br><br>
		We will give you an IP address each time you access the Hotspot, and it may change.
		<br>
		<b>You shall not</b> program any other IP or MAC address into your device that accesses the Hotspot.
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
				or otherwise interfering with other user"s enjoyment of the service;
			</li>
			<li>
				transmitting any viruses, worms, defects, Trojan Horses or other items of a destructive nature; or
			</li>
			<li>
				using the Service for any unlawful, harassing, abusive, criminal or fraudulent purpose.
			</li>
		</ol>
'

terms_content='
	<hr>
	<b>Content Disclaimer</b>
	<p>
		The Hotspot Owners do not control and are not responsible for data, content, services, or products
		that are accessed or downloaded through the Service.
		The Owners may, but are not obliged to, block data transmissions to protect the Owner and the Public.
	</p>
	The Owners, their suppliers and their licensors expressly disclaim to the fullest extent permitted by law,
	all express, implied, and statutary warranties, including, without limitation, the warranties of merchantability
	or fitness for a particular purpose.
	<br><br>
	The Owners, their suppliers and their licensors expressly disclaim to the fullest extent permitted by law
	any liability for infringement of proprietory rights and/or infringement of Copyright by any user of the system.
	Login details and device identities may be stored and be used as evidence in a Court of Law against such users.
	<br>
'

terms_liability='
	<hr><b>Limitation of Liability</b>
	<p>
		Under no circumstances shall the Owners, their suppliers or their licensors be liable to any user or
		any third party on account of that party"s use or misuse of or reliance on the Service.
	</p>
	<hr><b>Changes to Terms of Service and Termination</b>
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
'

terms_indemnity='
	<hr><b>Indemnity</b>
	<p>
		<b>You agree</b> to hold harmless and indemnify the Owners of this Hotspot,
		their suppliers and licensors from and against any third party claim arising from
		or in any way related to your use of the Service, including any liability or expense arising from all claims,
		losses, damages (actual and consequential), suits, judgments, litigation costs and legal fees, of every kind and nature.
	</p>
	<hr>
	<form>
		<input type="button" VALUE="Continue" onClick="history.go(-1);return true;">
	</form>
'
