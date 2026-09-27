#!/usr/bin/env bash
# Gebouwd op het community-scripts framework (MIT) | https://github.com/community-scripts/ProxmoxVE
# Source: https://github.com/teamspeak/teamspeak6-server

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y xz-utils
msg_ok "Installed Dependencies"

msg_info "Creating service user"
useradd --system --user-group --home /opt/teamspeak6-server --shell /usr/sbin/nologin tsserver
msg_ok "Created service user"

fetch_and_deploy_gh_release "teamspeak6-server" "teamspeak/teamspeak6-server" "prebuild" "latest" "/opt/teamspeak6-server" "teamspeak6-server-linux-$(arch_resolve).tar.xz"
chown -R tsserver:tsserver /opt/teamspeak6-server

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/teamspeak6-server.service
[Unit]
Description=TeamSpeak 6 Server
Wants=network-online.target
After=network-online.target

[Service]
User=tsserver
Group=tsserver
WorkingDirectory=/opt/teamspeak6-server
Environment=TSSERVER_LICENSE_ACCEPTED=accept
ExecStart=/opt/teamspeak6-server/tsserver
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now teamspeak6-server
msg_ok "Created Service"

msg_info "Waiting for ServerAdmin token"
TOKEN=""
for _ in {1..30}; do
  TOKEN=$(grep -ho 'token=[^ ]*' /opt/teamspeak6-server/logs/*.log 2>/dev/null | head -1 | cut -d= -f2- || true)
  [[ -n "$TOKEN" ]] && break
  sleep 2
done
if [[ -n "$TOKEN" ]]; then
  echo "$TOKEN" >/root/teamspeak6.token
  chmod 600 /root/teamspeak6.token
  msg_ok "Saved ServerAdmin token to /root/teamspeak6.token"
else
  msg_warn "Token not found yet, check: grep token= /opt/teamspeak6-server/logs/*.log"
fi

motd_ssh
customize
cleanup_lxc
