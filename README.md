# ClaudeAssistant

**Run Anthropic's [Claude Code](https://code.claude.com) inside Home Assistant OS.**

ClaudeAssistant is a Home Assistant app (formerly "add-on") that puts Claude Code
in your Home Assistant sidebar, with a tabbed browser terminal, SSH access, and
direct access to your configuration. Ask Claude to explain your automations, fix
broken YAML, build dashboards, write templates, or review ESPHome configs, all
without leaving Home Assistant.

No extra VM, no separate server: it runs in its own container on your existing
Home Assistant OS install.

[![Add repository to my Home Assistant](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Frthom562%2FClaudeAssistant)

---

## Features

- **In the sidebar**: a browser terminal through Home Assistant Ingress.
  Admin only, and it works remotely through Home Assistant Cloud (Nabu Casa).
- **Tabs like Windows Terminal**
  - **+** starts a new Claude session; **⌄** offers **New**, **Resume**, or **Shell**
  - Double-click to rename, drag to reorder, middle-click to close
  - Every tab keeps running when you close the page, and the same tabs show
    up on every device
- **Fits any screen**: text auto-sizes to the window, with A− / A+ overrides.
- **Phone friendly**
  - A QR code opens the panel on your phone
  - A key bar adds Esc, Tab, ⇧Tab, arrows, Enter, and Ctrl-C
  - Works even if your phone uses a different Claude account
- **Remote Control**: sessions also appear at claude.ai/code and in the Claude
  app (same Claude account).
- **SSH**: key-only access on your local network (default port 2222).
- **Persistent**
  - Your Claude login, settings, conversations, and workspace survive
    restarts, updates, and reboots
  - Resume any earlier conversation
- **Guardrails**
  - Read-only access to `/config` by default
  - `secrets.yaml` and `.storage` protected
  - Automatic backup of every file before Claude edits it
  - No access to the Home Assistant API, so it can never restart Home
    Assistant
- **Helpers**
  - `ha-git-init` puts your config under git
  - `ha-yaml-lint` checks YAML syntax
  - `ha-config-backups` lists and restores pre-edit copies

## Requirements

| | |
|---|---|
| **Installation** | Home Assistant **OS** (Supervised probably works but is unsupported; Container and Core can't run apps) |
| **Hardware** | 64-bit: **amd64** (Intel/AMD PCs, VMs) or **aarch64** (Raspberry Pi 4/5, Home Assistant Green/Yellow) |
| **Memory** | About 4 GB RAM total; about 1.5 GB free disk for the build |
| **Claude** | A Claude **Pro, Max, Team or Enterprise** plan, or an **Anthropic Console** account |
| **Network** | Internet access during the build and while using Claude |

## Installation

1. Click the **Add repository** button above, or go to
   **Settings → Apps → Install app → ⋮ → Repositories** and add:
   ```
   https://github.com/rthom562/ClaudeAssistant
   ```
2. Find **Claude Code** in the app store and click **Install**.
   Home Assistant builds it on your machine. This takes about 5–15 minutes,
   or longer on a Raspberry Pi.
3. On the **Info** tab, turn on **Start on boot**, **Watchdog**, and
   **Show in sidebar**, then click **Start**.
4. Open **Claude Code** from the sidebar and click **New session**.
5. Choose **Claude account with subscription** and open the sign-in link.
   Sign in, then paste the code back into the terminal. You only do this once.

> **Tip:** the sign-in link is long. If the browser shows *"Missing state
> parameter"*, the link was cut off when you copied it. Sign in over SSH from
> your computer's terminal instead (see below) and Cmd/Ctrl-click the link.

## Configuration

| Option | Default | What it does |
|---|---|---|
| `claude_config_access` | `read_only` | `read_write` lets Claude edit `/config` |
| `skip_permissions` | `true` | Tabs run `claude --dangerously-skip-permissions` (see **Safety**) |
| `remote_control` | `true` | Tabs run with `--remote-control` (claude.ai/code and the Claude app) |
| `protect_secrets` | `true` | Hides `secrets.yaml`, auth and cloud files from Claude's read tools |
| `backup_before_edit` | `true` | Copies each file before Claude's edit tools change it |
| `backup_retention_days` | `30` | How long pre-edit copies are kept |
| `auto_update_claude` | `true` | Claude Code keeps itself up to date |
| `phone_url` | empty | Your Nabu Casa URL, so the phone QR code works away from home |
| `terminal_font_size` | `15` | Starting font size (Auto-fit normally takes over) |
| `ssh_enabled` | `true` | Starts SSH when at least one key is set |
| `authorized_keys` | `[]` | Your SSH public keys |
| `ssh_allow_forwarding` | `false` | Needed for VS Code Remote-SSH |
| `git_user_name` / `git_user_email` | empty | Git identity for commits |

Example:

```yaml
claude_config_access: read_write
skip_permissions: true
remote_control: true
phone_url: https://abc123.ui.nabu.casa
authorized_keys:
  - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... me@laptop
```

## Using it

| In the panel | |
|---|---|
| **+** | New Claude session |
| **⌄ → Resume session** | Pick an earlier conversation |
| **⌄ → Shell** | Plain terminal |
| **A− / A+ / Auto** | Text size |
| Phone icon | QR code for your phone |
| Keyboard icon | Show or hide the phone key bar |

Good first prompts:

- *"Explain what my automations do."*
- *"Check configuration.yaml for problems."*
- *"Create an automation that turns on the porch light at sunset."*
- *"Build a YAML dashboard for my living room."*

Claude can't reload or restart Home Assistant. When a change is ready, go to
**Developer tools → YAML → Check configuration**, then reload or restart
yourself.

### SSH (local network)

Add your public key (`cat ~/.ssh/id_ed25519.pub`) to `authorized_keys`, restart
the app, then connect:

```bash
ssh -p 2222 root@homeassistant.local
tmux ls                         # list the browser tabs' sessions
tmux attach -t cc-xxxxxxxxxx    # join one (Ctrl-b d to leave)
```

SSH is for your home network only. Nabu Casa doesn't forward SSH, and you
shouldn't open port 2222 on your router.

## Safety

> ⚠️ **By default, Claude tabs run with `--dangerously-skip-permissions`.**
> Claude edits files and runs commands **without asking**.

What still protects your setup:

- `/config` starts **read-only** for Claude's edit tools. Set
  `claude_config_access: read_write` when you're ready.
- `.storage` and `.cloud` can never be edited by Claude's tools; secrets are
  hidden from its read tools.
- Every file Claude's edit tools change is backed up first. Restore one with
  `ha-config-backups`.
- The app has **no Home Assistant or Supervisor API access**, so Claude can't
  restart Home Assistant, call services, or touch other apps.

What doesn't: shell commands Claude runs aren't covered by those rules or by
the backups. **Run `ha-git-init` before letting Claude make big changes**, and
set `skip_permissions: false` if you'd rather approve every action.

Anyone who can open the panel (Home Assistant admins), or who is signed in to
your Claude account while Remote Control is on, can control this terminal.
Use strong passwords and multi-factor authentication.

## Updating

- **The app:** Home Assistant shows **Update** when a new version is
  published here.
- **Claude Code:** updates itself (`auto_update_claude`), or run
  `claude update`.

Your login, settings, conversations, and `/config` are kept across updates.

## Documentation

The full guide is in [`claude_code/DOCS.md`](claude_code/DOCS.md), and it's
also shown in the app's **Documentation** tab. It covers:

- architecture and the three permission layers
- Nabu Casa security
- SSH setup
- persistent storage
- backup and recovery
- troubleshooting

## Repository layout

```
ClaudeAssistant/
├── repository.yaml            Home Assistant repository metadata
├── README.md
└── claude_code/               the app
    ├── config.yaml            app definition (ingress, /config mapping, ports, options)
    ├── Dockerfile             Debian base + Claude Code native installer + ttyd
    ├── run.sh                 startup: storage, guardrails, services
    ├── DOCS.md                full documentation
    ├── CHANGELOG.md
    ├── translations/en.yaml
    └── rootfs/                nginx, tmux, tab bar page, tab service, helper scripts
```

## Disclaimer

ClaudeAssistant is a community project. It is not affiliated with or endorsed
by Anthropic or Home Assistant / Nabu Casa. "Claude" and "Claude Code" are
trademarks of Anthropic. Use of Claude Code is subject to Anthropic's terms.

## License

[MIT](LICENSE)
