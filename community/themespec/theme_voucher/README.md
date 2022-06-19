# Vouchers ThemeSpec
This ThemeSpec provides a simple portal requiring a voucher to login.

Vouchers can be generated according to voucher specifications in any way, either manually or programmatically.

An example voucher file is provided, along with a python script to generate more.

# Installation (openWRT)
Copy the themespec (theme_voucher.sh) file and the voucher.txt file to /usr/lib/opennds/

Edit /etc/config/opennds:

- option login_option_enabled '3'
- option themespec_path '/usr/lib/opennds/theme_voucher.sh'

## Voucher Roll
The vouchers are contained in a "voucher roll", the path to which is defined in the themespec file and on OpenWrt defaults to `/tmp/ndslog/vouchers.txt` . It should be changed to an external storage medium. (See the last section of the `theme_voucher.sh` file, entitled "Customise the Logfile location").

### Flash Wearout Notice
**WARNING**

 * The voucher roll is written to on every login
 * If its location is on router flash, this **WILL** result in non-repairable failure of the flash memory
and therefore the router itself.
 * This will happen, most likely within several months depending on the number of logins.
 * The location is set by default to be the same location as the openNDS log (logdir) ie on the tmpfs (ramdisk) of the operating system.
 * Files stored here will not survive a reboot.
 * In a production system, the mountpoint for logdir should be changed to the mount point of some external storage
eg a usb stick, an external drive, a network shared drive etc.

### Voucher Specifications
File MUST be:
- CSV style table, with comma (",") separators. No headers.
- 7 Columns: voucher code, speed limit down, speed limit up, quota down, quota up, voucher validity (minutes), 0 (placeholder for when voucher is used)

Voucher code MUST respect the following:
- 9 characters
- alphanumeric or dash ("-") character
(eg. 12345abcd, 1234-abcd, abcd-efgh)
Beware that no rate limiting is in place in this script (no idea elsewhere in opennds, so preferably don't limit yourself to only digits.
