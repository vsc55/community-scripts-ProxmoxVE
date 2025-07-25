#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: Arian Nasr (arian-nasr)
# Updated by: Javier Pastor (vsc55) 
#   - Add OpenSource modules option
#   - Add verbose mode
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.freepbx.org/

INSTALL_URL="https://github.com/FreePBX/sng_freepbx_debian_install/raw/master/sng_freepbx_debian_install.sh"
INSTALL_PATH="/opt/sng_freepbx_debian_install.sh"

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

run_bin() {
  if [[ "$VERBOSE" == "yes" ]]; then
    msg_ok "Running command [$*]...\n"
    "${@}"
    if [[ $? -ne 0 ]]; then
      msg_error "Command failed [$*] with exit code $?\n"
    fi
  else
    $STD "${@}"
  fi
  return $?
}

print_msg_info() {
  local txt_normal="${1:-}"
  local txt_verbose="${2:-}"

  if [[ "$VERBOSE" == "yes" ]]; then
    if [[ -n "$txt_verbose" ]]; then
      msg_info "$txt_verbose"
    else
      msg_info "$txt_normal\n"
    fi
  else
    msg_info "$txt_normal"
  fi
}

has_commercial_modules() {
  fwconsole ma list | awk '/Commercial/ {found=1} END {exit !found}'
}

run_bin_remove() {
  local err=0
  while read -r module; do
    msg_info "Removing module: $module"
    run_bin fwconsole ma -f remove "$module" 
    err=$?
    #|| err=1
    
    if [[ $err -ne 0 ]]; then
      msg_error "Failed to remove module: $module - error code $err"
    else
      msg_ok "Module $module removed successfully"
    fi

  done < <(fwconsole ma list | awk '/Commercial/ {print $2}')
  return $err
}

msg_info "Downloading FreePBX installation script..."
if curl -fsSL "$INSTALL_URL" -o "$INSTALL_PATH"; then
  msg_ok "Download completed successfully"
else
  curl_exit_code=$?
  msg_error "Error downloading FreePBX installation script (curl exit code: $curl_exit_code)"
  msg_error "Aborting!"
  exit 1
fi

# read -n1 -rp "${TAB3}Remove Commercial modules? [y/N] " prompt
# echo
install_args=""
ONLY_OPENSOURCE="${ONLY_OPENSOURCE:-no}"
# if [[ ${prompt,,} =~ ^(y|yes|s|si)$ ]]; then
#   only_opensource="yes"
# else
#   only_opensource="no"
# fi

msg_ok "Remove Commercial modules is set to: $ONLY_OPENSOURCE"


print_msg_info "Installing FreePBX, be patient, this takes time..." "Installing FreePBX (Verbose)\n"
run_bin bash "$INSTALL_PATH" $install_args

if [[ $ONLY_OPENSOURCE == "yes" ]]; then
  
  print_msg_info "Removing Commercial modules..."
  
  max_tries=5
  count=0
  # while output=$(fwconsole ma list | awk '/Commercial/ {print $2}'); do
  while true; do
    ! has_commercial_modules && break

    count=$((count + 1))

    # run_bin fwconsole ma list | awk '/Commercial/ {print $2}' | xargs -I {} fwconsole ma -f remove {}
    # err_code=$?

    run_bin_remove
    err_code=$?

    # Note: Code 123 may not be an error, it could be dependencies. We'll try again.
    if [[ $err_code -ne 0 && $err_code -ne 123 ]]; then
      msg_error "Error removing commercial modules (exit code: $err_code)"
      msg_error "Please check the output above for details."
      exit 1
    fi

    # Check if there are still commercial modules left
    ! has_commercial_modules && break

    # Timeout to avoid infinite loop
    if [[ $count -ge $max_tries ]]; then
      msg_warn "Failed to remove all commercial modules after $max_tries attempts, remove them manually in the web interface."
      break
    else
      msg_info "Removed commercial modules, retrying (attempt $count/$max_tries)..."
    fi
  done

  msg_info "Reloading FreePBX..."
  run_bin fwconsole reload
fi
msg_ok "Installed FreePBX completely"

motd_ssh
customize

msg_info "Cleaning up"
rm -f "$INSTALL_PATH"
run_bin apt-get -y autoremove
run_bin apt-get -y autoclean
msg_ok "Cleaned"
