#!/bin/sh

# Check if opennds is running
ndspid=$(pidof opennds)
fwhook=$(uci -q get opennds.@opennds[0].fwhook_enabled)
if [ ! -z $ndspid ]; then
  if [ "$fwhook" = "1" ]; then
    echo "fwhook restart request received - restarting " | logger -p "daemon.warn" -s -t "opennds[$ndspid]: "
    /etc/init.d/opennds restart
  fi
fi
