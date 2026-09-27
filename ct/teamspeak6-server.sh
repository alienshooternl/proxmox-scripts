#!/usr/bin/env bash
_CS_DEFAULT_URL="https://raw.githubusercontent.com/alienshooternl/proxmox-scripts/main"
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")

# Gebouwd op het community-scripts framework (MIT) | https://github.com/community-scripts/ProxmoxVE
# Source: https://github.com/teamspeak/teamspeak6-server

APP="Teamspeak6-Server"
var_tags="${var_tags:-voice;communication}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_arm64="${var_arm64:-yes}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -f /opt/teamspeak6-server/tsserver ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  # Beta -> stabiel: "6.0.0-beta13" telt voor de versievergelijking als nieuwer dan "6.0.0",
  # dus forceer de update zodra er een stabiele release is.
  if [[ "$(cat ~/.teamspeak6-server 2>/dev/null)" == *beta* ]]; then
    LATEST_TAG=$(curl -fsSL https://api.github.com/repos/teamspeak/teamspeak6-server/releases/latest 2>/dev/null | grep -m1 '"tag_name"' | cut -d'"' -f4 || true)
    if [[ -n "$LATEST_TAG" && "$LATEST_TAG" != *beta* ]]; then
      echo "0.0.0" >~/.teamspeak6-server
    fi
  fi

  if check_for_gh_release "teamspeak6-server" "teamspeak/teamspeak6-server"; then
    msg_info "Stopping Service"
    systemctl stop teamspeak6-server
    msg_ok "Stopped Service"

    msg_info "Backing up database"
    mkdir -p /opt/teamspeak6-server-backup
    cp -a /opt/teamspeak6-server/tsserver.sqlitedb* /opt/teamspeak6-server-backup/
    msg_ok "Backed up database to /opt/teamspeak6-server-backup"

    # Geen CLEAN_INSTALL: database, bestanden en logs in /opt/teamspeak6-server blijven staan
    fetch_and_deploy_gh_release "teamspeak6-server" "teamspeak/teamspeak6-server" "prebuild" "latest" "/opt/teamspeak6-server" "teamspeak6-server-linux-$(arch_resolve).tar.xz"
    chown -R tsserver:tsserver /opt/teamspeak6-server

    msg_info "Starting Service"
    systemctl start teamspeak6-server
    msg_ok "Started Service"
    msg_ok "Updated successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Connect with your TeamSpeak client to:${CL}"
echo -e "${GATEWAY}${BGN}${IP}:9987${CL}"
echo -e "${INFO}${YW}ServerAdmin token (one-time use):${CL}"
echo -e "${TAB}${BGN}pct exec ${CTID} -- cat /root/teamspeak6.token${CL}"
