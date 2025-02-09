#!/bin/sh
output="2074408296,1024,1024,0,0,1440,0"
voucher_token=$(echo "$output" | awk -F',' '{print $1}')
voucher_rate_down=$(echo "$output" | awk -F',' '{print $2}')
voucher_rate_up=$(echo "$output" | awk -F',' '{print $3}')
voucher_quota_down=$(echo "$output" | awk -F',' '{print $4}')
voucher_quota_up=$(echo "$output" | awk -F',' '{print $5}')
voucher_time_limit=$(echo "$output" | awk -F',' '{print $6}')
voucher_first_punched=$(echo "$output" | awk -F',' '{print $7}')

echo "Token: $voucher_token"
echo "Rate Down: $voucher_rate_down"
echo "Rate Up: $voucher_rate_up"
echo "Quota Down: $voucher_quota_down"
echo "Quota Up: $voucher_quota_up"
echo "Time Limit: $voucher_time_limit"
echo "First Punched: $voucher_first_punched"