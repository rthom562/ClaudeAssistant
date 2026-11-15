# ClaudeAssistant — Claude Code for Home Assistant OS

A Home Assistant **app** (formerly "add-on") that runs Anthropic's
[Claude Code](https://code.claude.com) CLI in its own container inside your
existing Home Assistant OS VM — no extra VM, no Ubuntu, no external server.

- Browser terminal in the HA sidebar via **Ingress**, admin-only, with a
  browser-style tab bar: **+ → New session / Resume session / Shell**. Each tab
  is its own persistent session. Works remotely through **Home Assistant
  Cloud / Nabu Casa**.
- **SSH** on your LAN (public keys only, default port 2222), separate from HA's
  own SSH app.
- Your Home Assistant configuration mounted at **`/config`**.
- Claude login, settings, session history, workspace and git repos persisted in
  the app's `/data` volume.
- Tabs run `claude --dangerously-skip-permissions [--resume] --remote-control`
  (both flags switchable in the options).
- Safety: read-only guardrail by default, secrets protected, automatic
  pre-edit backups, no Home Assistant API access (it cannot restart HA).

## Repository layout

```
ClaudeAssistant/
├── repository.yaml                 app repository metadata
├── README.md                       this file
└── claude_code/                    the app
    ├── config.yaml                 app configuration (ingress, map, ports, options)
    ├── Dockerfile                  Debian (trixie) HA base + Claude Code native install
    ├── run.sh                      entry point: storage, settings, nginx/ttyd/sshd
    ├── DOCS.md                     full documentation (shown in the app's Documentation tab)
    ├── CHANGELOG.md
    ├── translations/en.yaml        option labels/descriptions
    └── rootfs/
        ├── etc/nginx/nginx.conf            Ingress front end (Supervisor IP only)
        ├── etc/tmux.conf                   persistent tab sessions
        ├── usr/share/claude-code-ha/www/index.html  tab bar page
        ├── usr/local/bin/claude-tabs-server tab service (list/create/close)
        ├── usr/local/bin/claude-tab-attach  ttyd -> attach to a tab session
        ├── etc/profile.d/claude-code.sh    shell environment
        ├── usr/local/bin/ha-backup-hook    Claude Code PreToolUse backup hook
        ├── usr/local/bin/ha-config-backups list/diff/restore pre-edit copies
        ├── usr/local/bin/ha-git-init       put /config under git (asks first)
        ├── usr/local/bin/ha-yaml-lint      YAML syntax check
        ├── usr/local/bin/claude-ha-welcome terminal banner
        └── usr/share/claude-code-ha/CLAUDE.md  default Home Assistant rules for Claude
```

## Quick install

1. Home Assistant → **Settings → Apps → Install app → ⋮ → Repositories** → add
   `https://github.com/rthom562/ClaudeAssistant`.
2. Refresh the app store; **Claude Code** appears under this repository.
3. Install **Claude Code** (the Supervisor builds it locally; takes a few
   minutes).
4. **Configuration**: add your SSH public key to `authorized_keys`; Save.
5. **Info**: enable *Start on boot*, *Watchdog*, *Show in sidebar*; **Start**.
6. Open **Claude Code** in the sidebar, click **New session**, and sign in
   with your Claude account.

No GitHub? Copy the `claude_code` folder to the local apps folder (`/addons`)
and install it from **Local apps**. Both methods are described step by step in
[`claude_code/DOCS.md`](claude_code/DOCS.md), together with authentication,
Nabu Casa remote access, SSH, permissions, backup/recovery and
troubleshooting.

## Requirements

- Home Assistant OS on amd64 with a current Supervisor (Core 2026.2+ uses the
  "Apps" naming; older versions say "Add-ons").
- A Claude Pro, Max, Team or Enterprise plan, or a Claude Console account.
- Internet access during the build and for Claude Code itself.
