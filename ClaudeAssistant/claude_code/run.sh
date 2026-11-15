#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Claude Code app for Home Assistant OS - main entry point.
#
# Started by s6-overlay (/init) as the container's CMD. It:
#   1. reads the app options (once, while the Supervisor token is available)
#   2. drops the Supervisor token so nothing launched later can use it
#   3. prepares persistent storage under /data
#   4. installs/locates Claude Code and writes managed (non-overridable)
#      Claude Code settings: guardrails for /config, pre-edit backups
#   5. starts nginx (Ingress front end + tab bar page), the tab service,
#      ttyd (browser terminals) and sshd, restarting any of them if it exits
#
# It never edits Home Assistant configuration and never restarts Home
# Assistant. It never prints option values that could contain secrets.
# ==============================================================================
set -o pipefail

readonly DATA_DIR=/data
readonly HOME_DIR=/data/home
readonly WORKSPACE_DIR=/data/workspace
readonly SSH_DIR=/data/ssh
readonly BACKUP_DIR=/data/backups
readonly MANAGED_DIR=/etc/claude-code
readonly SEED_CLAUDE=/opt/claude-code/claude
readonly TTYD_PORT=7681

export HOME="${HOME_DIR}"
export PATH="${HOME_DIR}/.local/bin:/opt/claude-code:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export LANG=C.UTF-8 LC_ALL=C.UTF-8 TERM=xterm-256color
umask 022

bashio::log.info "Starting Claude Code app"

# ------------------------------------------------------------------------------
# 1. Options
# ------------------------------------------------------------------------------
CONFIG_ACCESS="$(bashio::config 'claude_config_access' 'read_only')"
PROTECT_SECRETS="$(bashio::config 'protect_secrets' 'true')"
BACKUP_BEFORE_EDIT="$(bashio::config 'backup_before_edit' 'true')"
BACKUP_RETENTION_DAYS="$(bashio::config 'backup_retention_days' '30')"
AUTO_UPDATE="$(bashio::config 'auto_update_claude' 'true')"
SKIP_PERMISSIONS="$(bashio::config 'skip_permissions' 'true')"
REMOTE_CONTROL="$(bashio::config 'remote_control' 'true')"
PHONE_URL=""
if bashio::config.has_value 'phone_url'; then PHONE_URL="$(bashio::config 'phone_url')"; fi
FONT_SIZE="$(bashio::config 'terminal_font_size' '15')"
SSH_ENABLED="$(bashio::config 'ssh_enabled' 'true')"
SSH_FORWARDING="$(bashio::config 'ssh_allow_forwarding' 'false')"
GIT_NAME=""
GIT_EMAIL=""
AUTHORIZED_KEYS=""
if bashio::config.has_value 'git_user_name'; then GIT_NAME="$(bashio::config 'git_user_name')"; fi
if bashio::config.has_value 'git_user_email'; then GIT_EMAIL="$(bashio::config 'git_user_email')"; fi
if bashio::config.has_value 'authorized_keys'; then AUTHORIZED_KEYS="$(bashio::config 'authorized_keys')"; fi

# ------------------------------------------------------------------------------
# 2. Drop the Supervisor token. Everything we need from the Supervisor has
#    been read; ttyd, tmux, sshd and Claude Code must not inherit it.
# ------------------------------------------------------------------------------
unset SUPERVISOR_TOKEN HASSIO_TOKEN
rm -f /run/s6/container_environment/SUPERVISOR_TOKEN \
      /run/s6/container_environment/HASSIO_TOKEN 2>/dev/null || true

# ------------------------------------------------------------------------------
# 3. Persistent storage layout
#    /data/home        root's HOME: ~/.claude (auth, settings, sessions),
#                      ~/.claude.json, ~/.local (Claude Code binary),
#                      ~/.ssh, ~/.gitconfig, shell history
#    /data/workspace   your own projects and git repositories
#    /data/ssh         SSH host keys + authorized_keys from the options
#    /data/backups     pre-edit copies of /config files
# ------------------------------------------------------------------------------
mkdir -p "${HOME_DIR}/.claude" "${HOME_DIR}/.local/bin" "${HOME_DIR}/.ssh" \
         "${WORKSPACE_DIR}" "${SSH_DIR}" "${BACKUP_DIR}/config" "${MANAGED_DIR}"
chmod 700 "${HOME_DIR}" "${HOME_DIR}/.ssh" "${HOME_DIR}/.claude" "${SSH_DIR}"
chmod 755 "${DATA_DIR}"

link_if_free() {
    # Create symlink $2 -> $1 unless a real file/directory already sits at $2.
    if [[ -L "$2" || ! -e "$2" ]]; then ln -sfn "$1" "$2"; fi
}
link_if_free "${WORKSPACE_DIR}" "${HOME_DIR}/workspace"
link_if_free /config "${HOME_DIR}/homeassistant"

if [[ -f /config/configuration.yaml ]]; then
    bashio::log.info "Home Assistant configuration found at /config"
else
    bashio::log.warning "/config/configuration.yaml not found - check the app's 'map' setting"
fi

# ------------------------------------------------------------------------------
# 4a. Claude Code binary (persistent, official native install)
# ------------------------------------------------------------------------------
if [[ ! -x "${HOME_DIR}/.local/bin/claude" ]]; then
    bashio::log.info "Installing Claude Code into persistent storage (claude install stable)..."
    if timeout 300 "${SEED_CLAUDE}" install stable >/tmp/claude-install.log 2>&1 \
        && [[ -x "${HOME_DIR}/.local/bin/claude" ]]; then
        bashio::log.info "Claude Code installed to ${HOME_DIR}/.local/bin/claude"
    else
        bashio::log.warning "Persistent install failed; using the copy bundled in the image."
        bashio::log.warning "Run 'claude install stable' in the terminal later to retry."
        tail -n 5 /tmp/claude-install.log 2>/dev/null | sed 's/^/  install: /' || true
    fi
fi
CLAUDE_VERSION="$(claude --version 2>/dev/null | head -n 1 || true)"
bashio::log.info "Claude Code version: ${CLAUDE_VERSION:-unknown}"
bashio::log.info "Bundled image version: $(cat /opt/claude-code/VERSION 2>/dev/null || echo unknown)"

if [[ -f "${HOME_DIR}/.claude/.credentials.json" ]]; then
    bashio::log.info "Claude login found in persistent storage"
else
    bashio::log.info "Not logged in yet - open the terminal and run 'claude' to sign in"
fi

# ------------------------------------------------------------------------------
# 4b. Managed Claude Code settings (/etc/claude-code/managed-settings.json).
#     Managed settings take precedence over user and project settings, so
#     Claude cannot loosen these rules from inside a session.
# ------------------------------------------------------------------------------
to_json_bool() { [[ "$1" == "true" ]] && echo true || echo false; }

jq -n \
    --argjson read_only "$([[ "${CONFIG_ACCESS}" == "read_only" ]] && echo true || echo false)" \
    --argjson secrets "$(to_json_bool "${PROTECT_SECRETS}")" \
    --argjson backup "$(to_json_bool "${BACKUP_BEFORE_EDIT}")" \
    --argjson autoupdate "$(to_json_bool "${AUTO_UPDATE}")" \
    --argjson allow_bypass "$(to_json_bool "${SKIP_PERMISSIONS}")" \
'{
  permissions: ((if $allow_bypass then {} else { disableBypassPermissionsMode: "disable" } end) + {
    deny: (
      # Home Assistant runtime state: never edit while HA is running.
      [ "Edit(//config/.storage/**)", "Edit(//config/.cloud/**)" ]
      + (if $secrets then [
          "Read(//config/secrets.yaml)",
          "Read(//config/**/secrets.yaml)",
          "Read(//config/.storage/auth)",
          "Read(//config/.storage/auth_provider.homeassistant)",
          "Read(//config/.cloud/**)"
        ] else [] end)
      + (if $read_only then [ "Edit(//config/**)" ] else [] end)
    ),
    # In read/write mode every change under /config needs your approval,
    # even if "accept edits" mode or an allow rule is active.
    ask: (if $read_only then [] else [ "Edit(//config/**)" ] end)
  }),
  env: (if $autoupdate then {} else { DISABLE_AUTOUPDATER: "1" } end),
  hooks: (if $backup then {
    PreToolUse: [ {
      matcher: "Edit|Write|MultiEdit|NotebookEdit",
      hooks: [ { type: "command", command: "/usr/local/bin/ha-backup-hook", timeout: 30 } ]
    } ]
  } else {} end)
}' > "${MANAGED_DIR}/managed-settings.json"
chmod 644 "${MANAGED_DIR}/managed-settings.json"
echo "${CONFIG_ACCESS}" > "${MANAGED_DIR}/ha-config-access"
bashio::log.info "Claude Code access to /config: ${CONFIG_ACCESS} (secrets protected: ${PROTECT_SECRETS}, pre-edit backups: ${BACKUP_BEFORE_EDIT})"
bashio::log.info "New tabs: skip permissions=${SKIP_PERMISSIONS}, remote control=${REMOTE_CONTROL}"
if [[ "${SKIP_PERMISSIONS}" == "true" ]]; then
    bashio::log.warning "skip_permissions is ON: Claude Code will not ask before running commands or editing files in tabs."
fi
printf 'skip_permissions=%s\nremote_control=%s\n' "${SKIP_PERMISSIONS}" "${REMOTE_CONTROL}" > "${MANAGED_DIR}/ha-tab-flags"

# User-level CLAUDE.md with Home Assistant working rules (only if missing,
# so your own edits are never overwritten).
if [[ ! -f "${HOME_DIR}/.claude/CLAUDE.md" ]]; then
    cp /usr/share/claude-code-ha/CLAUDE.md "${HOME_DIR}/.claude/CLAUDE.md"
    bashio::log.info "Created default ~/.claude/CLAUDE.md (edit it freely)"
fi

# Git defaults (identity only if set in the options).
git config --global init.defaultBranch main
git config --global core.editor nano
git config --global --replace-all safe.directory /config
[[ -n "${GIT_NAME}" ]] && git config --global user.name "${GIT_NAME}"
[[ -n "${GIT_EMAIL}" ]] && git config --global user.email "${GIT_EMAIL}"

# Prune old pre-edit backups.
find "${BACKUP_DIR}/config" -mindepth 1 -maxdepth 1 -type d \
    -mtime "+${BACKUP_RETENTION_DAYS}" -exec rm -rf {} + 2>/dev/null || true

# ------------------------------------------------------------------------------
# 5a. SSH
# ------------------------------------------------------------------------------
START_SSH=false
if [[ "${SSH_ENABLED}" == "true" ]]; then
    mkdir -p /run/sshd && chmod 755 /run/sshd
    for type in ed25519 rsa; do
        key="${SSH_DIR}/ssh_host_${type}_key"
        if [[ ! -f "${key}" ]]; then
            bashio::log.info "Generating persistent SSH host key (${type})"
            if [[ "${type}" == "rsa" ]]; then
                ssh-keygen -q -t rsa -b 4096 -N '' -f "${key}"
            else
                ssh-keygen -q -t ed25519 -N '' -f "${key}"
            fi
        fi
    done
    chmod 600 "${SSH_DIR}"/ssh_host_*_key

    # authorized_keys from the app options (rewritten on every start).
    printf '%s\n' "${AUTHORIZED_KEYS}" | sed '/^[[:space:]]*$/d' > "${SSH_DIR}/authorized_keys"
    chmod 600 "${SSH_DIR}/authorized_keys"
    touch "${HOME_DIR}/.ssh/authorized_keys"
    chmod 600 "${HOME_DIR}/.ssh/authorized_keys"
    KEY_COUNT=$(( $(grep -c . "${SSH_DIR}/authorized_keys" || true) \
                + $(grep -c '^ssh-\|^ecdsa-\|^sk-' "${HOME_DIR}/.ssh/authorized_keys" || true) ))

    FORWARDING=no
    [[ "${SSH_FORWARDING}" == "true" ]] && FORWARDING=yes

    cat > /etc/ssh/sshd_config <<EOF
# Generated by run.sh on every start - do not edit (changes are lost).
Port 22
HostKey ${SSH_DIR}/ssh_host_ed25519_key
HostKey ${SSH_DIR}/ssh_host_rsa_key

# Public-key authentication only.
PermitRootLogin prohibit-password
AllowUsers root
PubkeyAuthentication yes
AuthenticationMethods publickey
AuthorizedKeysFile ${SSH_DIR}/authorized_keys .ssh/authorized_keys
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
UsePAM no
StrictModes yes
MaxAuthTries 3
LoginGraceTime 30

# Forwarding (needed for VS Code Remote-SSH) is off unless enabled.
AllowTcpForwarding ${FORWARDING}
AllowAgentForwarding ${FORWARDING}
AllowStreamLocalForwarding no
X11Forwarding no
PermitTunnel no
GatewayPorts no
PermitUserEnvironment no

ClientAliveInterval 60
ClientAliveCountMax 3
PrintMotd no
LogLevel INFO
AcceptEnv LANG LC_*
Subsystem sftp internal-sftp
EOF

    if [[ "${KEY_COUNT}" -gt 0 ]]; then
        if /usr/sbin/sshd -t -f /etc/ssh/sshd_config; then
            START_SSH=true
            bashio::log.info "SSH enabled with ${KEY_COUNT} authorized key(s); container port 22 (host port: see Network settings, default 2222)"
        else
            bashio::log.error "sshd configuration test failed; SSH not started"
        fi
    else
        bashio::log.warning "SSH enabled but no authorized_keys configured - SSH not started"
    fi
else
    bashio::log.info "SSH disabled in options"
fi

# ------------------------------------------------------------------------------
# 5b. Services
# ------------------------------------------------------------------------------
supervise() {
    # supervise <name> <command...> : run forever, restart on exit.
    local name="$1"; shift
    (
        while true; do
            bashio::log.info "Starting ${name}"
            "$@"
            rc=$?
            bashio::log.warning "${name} exited (code ${rc}); restarting in 5 seconds"
            sleep 5
        done
    ) &
}

# Tab service: lists/creates/closes the tmux session behind each browser tab.
# It also owns the tmux server, so sessions inherit this clean environment
# (HOME=/data/home, no Supervisor token).
export CC_SKIP_PERMISSIONS="${SKIP_PERMISSIONS}" CC_REMOTE_CONTROL="${REMOTE_CONTROL}" CC_PHONE_URL="${PHONE_URL}"
supervise tab-service /usr/bin/python3 -I /usr/local/bin/claude-tabs-server

# ttyd listens on the loopback interface only; nginx is the only way in.
# Each browser tab opens its own ttyd connection; --url-arg passes the tab
# name (validated by claude-tab-attach, which only attaches to sessions).
supervise ttyd ttyd \
    --interface lo \
    --port "${TTYD_PORT}" \
    --writable \
    --url-arg \
    --cwd /config \
    --ping-interval 30 \
    --max-clients 40 \
    --client-option "fontSize=${FONT_SIZE}" \
    --client-option "titleFixed=Claude Code" \
    --client-option "disableLeaveAlert=true" \
    /usr/local/bin/claude-tab-attach

# nginx on :8099 accepts only the Supervisor's Ingress proxy (172.30.32.2)
# and the local health check.
supervise nginx nginx -c /etc/nginx/nginx.conf

if [[ "${START_SSH}" == "true" ]]; then
    supervise sshd /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
fi

shutdown() {
    bashio::log.info "Stopping Claude Code app"
    tmux kill-server 2>/dev/null || true
    pkill -TERM -x ttyd 2>/dev/null || true
    pkill -TERM -x nginx 2>/dev/null || true
    pkill -TERM -x sshd 2>/dev/null || true
    pkill -TERM -f claude-tabs-server 2>/dev/null || true
    # shellcheck disable=SC2046
    kill $(jobs -p) 2>/dev/null || true
    exit 0
}
trap shutdown SIGTERM SIGINT

bashio::log.info "Ready: open 'Claude Code' in the Home Assistant sidebar"
while true; do
    wait
done
