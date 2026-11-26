#!/bin/sh
#Copyright (C) BlueWave Projects and Services 2015-2023
# SPDX-License-Identifier: GPL-2.0-or-later
i=0
while true; do
	./ndsctlstatus.sh $i &
	echo "Iteration $i forked:"
	i=$((i+1))
	sleep 1
done
