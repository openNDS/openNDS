#!/bin/sh

# Check if opennds is running
ndspid=$(ps | grep opennds_cfg | awk -F ' ' 'NR==2 {print $1}')
if [ ! -z $ndspid ]; then
  if [ "$(uci -q get opennds.@opennds[0].fwhook_enabled)" = "1" ]; then
    echo "fwhook restart request received - restarting " | logger -p "daemon.warn" -s -t "opennds[$ndspid]: "
    /etc/init.d/opennds restart
  fi
fi
