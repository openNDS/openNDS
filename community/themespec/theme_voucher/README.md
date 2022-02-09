# Vouchers Themespec
This themespec provides a simple portal requiring a voucher to login.
Voucher can be generated according to vouchers specifications in any way, either manually or programmatically.
An example voucher file is provided, alongise with a python script to generate more.

# Installation (openWRT)
Copy the themespec (theme_voucher.sh) file and the voucher.txt file to /usr/lib/opennds/
Edit /etc/config/opennds:
- option login_option_enabled '3'
- option themespec_path '/usr/lib/opennds/theme_voucher.sh'

## Voucher Roll
The vouchers are contained in a "voucher roll", the path to which is defined in the themespec file and defaults to /usr/lib/opennds/vouchers.txt . It can be changed as needed.

### Flash Wearout Notice
The voucher file is written once every first voucher use. This can lead to flash wearout if the portal has more than just a light user load.

To prevent this problem, you can move the file to external storage (eg. USB, NFS/SMB share), and edit the themespec accordingly.

### Voucher Specifications
File MUST be:
- CSV style table, with comma (",") separators. No headers.
- 7 Columns: voucher code, speed limit down, speed limit up, quota down, quota up, voucher validity (minutes), 0 (placeholder for when voucher is used)

Voucher code MUST respect the following:
- 9 characters
- alphanumeric or dash ("-") character
(eg. 12345abcd, 1234-abcd, abcd-efgh)
Beware that no rate limiting is in place in this script (no idea elsewhere in opennds, so preferably don't limit yourself to only digits.
