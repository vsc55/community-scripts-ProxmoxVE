#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: Michel Roegl-Brunner (michelroegl-brunner)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://checkmk.com/

APP="checkmk"
var_tags="${var_tags:-monitoring}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-6}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -f /opt/checkmk_version.txt ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  RELEASE=$(curl -fsSL https://api.github.com/repos/checkmk/checkmk/tags | grep "name" | awk '{print substr($2, 3, length($2)-4) }' | tr ' ' '\n' | grep -Ev 'rc|b' | sort -V | tail -n 1)
  if [[ "${RELEASE}" != "$(cat ~/.checkmk 2>/dev/null)" ]] || [[ ! -f ~/.checkmk ]]; then
    fetch_and_deploy_gh_release "checkmk" "checkmk/checkmk" "binary" "${RELEASE}"
    msg_ok "Updated ${APP} to v${RELEASE}"
  else
    msg_ok "No update required. ${APP} is already at v${RELEASE}."
  fi

  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}/monitoring${CL}"
