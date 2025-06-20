#!/bin/sh
#Copyright (C) The openNDS Contributors 2004-2022
#Copyright (C) BlueWave Projects and Services 2015-2025
#This software is released under the GNU GPL license.

# This is a stub for a custom binauth script.
# It is included by the default binauth_log.sh script when it runs.
# By default, it does nothing as it is a template.
# This included script can override:
# exitlevel, sessiontimeout, upload rate, download rate, upload quota and download quota.

# The following variables are initialised with valid information by the openNDS daemon and can be used in any custom code added below:
# HOSTNAME
# action
# authlog
# cidfile
# client_if
# client_if_string
# client_mac
# client_meshnode
# client_type
# client_zone
# clientif
# clientip
# clientmac
# cpi_query
# custom
# custombinauthpath
# customdata
# download_quota
# download_rate
# exitlevel
# fulllog
# gatewayaddress
# gatewaymac
# gatewayname
# gatewayurl
# hid
# local_mesh_if
# log_mountpoint
# logdir
# loginfo
# mountpoint
# ndspid
# originurl
# sessiontimeout
# themespec
# upload_quota
# upload_rate
# version

# BinAuth Descriptors:
custombinauth_title="Template"
custombinauth_description="Custom BinAuth Template"

# Add custom code after this line:


