#!/usr/bin/env bash

#Copyright (c) 2021-2025 community-scripts ORG
# Author: Michel Roegl-Brunner (michelroegl-brunner)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://checkmk.com/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

RELEASE=$(curl -fsSL https://api.github.com/repos/checkmk/checkmk/tags | grep "name" | awk '{print substr($2, 3, length($2)-4) }' | tr ' ' '\n' | grep -Ev 'rc|b' | sort -V | tail -n 1)
fetch_and_deploy_gh_release "checkmk" "checkmk/checkmk" "binary" "${RELEASE}"

motd_ssh
customize

msg_info "Creating Service"
PASSWORD=$(omd create monitoring | grep "password:" | awk '{print $NF}')
$STD omd start
{
  echo "Application-Credentials"
  echo "Username: cmkadmin"
  echo "Password: $PASSWORD"
} >>~/checkmk.creds
msg_ok "Created Service"

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
