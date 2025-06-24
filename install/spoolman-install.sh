#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: MickLesk (CanbiZ)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/Donkie/Spoolman

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  build-essential \
  make \
  libpq-dev \
  ca-certificates
msg_ok "Installed Dependencies"

PYTHON_VERSION="3.12" setup_uv
fetch_and_deploy_gh_release "spoolman" "Donkie/Spoolman" "prebuild" "latest" "/opt/spoolman" "spoolman.zip"

msg_info "Installing Spoolman"
cd /opt/spoolman
$STD uv venv /opt/spoolman/.venv
$STD /opt/spoolman/.venv/bin/python -m ensurepip --upgrade
$STD /opt/spoolman/.venv/bin/python -m pip install --upgrade pip
$STD /opt/spoolman/.venv/bin/python -m pip install -r requirements.txt

curl -fsSL "https://raw.githubusercontent.com/Donkie/Spoolman/master/.env.example" -o ".env"
msg_ok "Installed Spoolman"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/spoolman.service
[Unit]
Description=Spoolman
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/spoolman
EnvironmentFile=/opt/spoolman/.env
ExecStart=/opt/spoolman/.venv/bin/uvicorn spoolman.main:app --host 0.0.0.0 --port 7912
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now spoolman
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
