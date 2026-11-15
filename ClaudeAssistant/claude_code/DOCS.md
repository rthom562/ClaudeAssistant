# Claude Code for Home Assistant — Documentation

This app runs Anthropic's **Claude Code** CLI in its own container inside your
existing Home Assistant OS VM. You reach it two ways:

- **Browser** — a terminal in the Home Assistant sidebar (Ingress). Works
  locally and remotely through Home Assistant Cloud (Nabu Casa).
- **SSH** — key-only SSH into the container on your local network.

Claude Code sees your Home Assistant configuration at `/config` and keeps its
login, settings, session history and your projects in the app's persistent
storage.

---

## Contents

1. [How it fits together](#1-how-it-fits-together)
2. [Before you start](#2-before-you-start)
3. [Installation](#3-installation)
4. [Configuration](#4-configuration)
5. [Signing in to Claude](#5-signing-in-to-claude)
6. [Daily use](#6-daily-use)
7. [Working on your Home Assistant configuration](#7-working-on-your-home-assistant-configuration)
8. [Permissions: Claude Code vs Home Assistant vs the filesystem](#8-permissions-claude-code-vs-home-assistant-vs-the-filesystem)
9. [Remote browser access through Nabu Casa](#9-remote-browser-access-through-nabu-casa)
10. [SSH on your local network](#10-ssh-on-your-local-network)
11. [Persistent storage](#11-persistent-storage)
12. [Backup and recovery](#12-backup-and-recovery)
13. [Troubleshooting](#13-troubleshooting)
14. [Updating and uninstalling](#14-updating-and-uninstalling)
15. [Compatibility notes and limitations](#15-compatibility-notes-and-limitations)
16. [Audit checklist](#16-audit-checklist)

---

## 1. How it fits together

```
Browser (LAN or Nabu Casa Remote UI)
   │  HTTPS + your Home Assistant login (admins only)
   ▼
Home Assistant Core frontend ──► Supervisor Ingress proxy (172.30.32.2)
                                          │  internal hassio network
                                          ▼
                       ┌──────────── Claude Code app container ───────────┐
                       │ nginx :8099  (accepts only 172.30.32.2)          │
                       │   ├─► /          tab bar page (+ New/Resume/Shell)│
                       │   ├─► /api/      tab service 127.0.0.1:7682      │
                       │   └─► /terminal/ ttyd 127.0.0.1:7681, one per tab│
                       │         └─► tmux session cc-xxxx ─► claude ...   │
                       │                                                  │
LAN SSH client ───────►│ sshd :22  (published as host port 2222, keys only)│
                       │                                                  │
                       │ /config  ◄── Home Assistant configuration (rw)   │
                       │ /data    ◄── persistent app storage              │
                       └──────────────────────────────────────────────────┘
```

- Base image: `ghcr.io/home-assistant/base-debian:trixie` (glibc, s6-overlay v3,
  bashio), maintained by Home Assistant.
- No privileged mode, no host network, no Docker socket, no `/dev` access, no
  Supervisor API, no Home Assistant API.

## 2. Before you start

- **Claude subscription.** Claude Code requires a Pro, Max, Team or Enterprise
  plan, or a Claude Console (API) account. The free Claude.ai plan does not
  include Claude Code.
- **Check your versions.** Settings → About shows Core, Supervisor and
  Operating System. Core versions look like `2026.11.x`; a number such as
  `3.24.3` is not a Core version, so read the "Core" line specifically. This
  repository targets HA OS 18.x on amd64 with a current Supervisor. On Core
  2026.2 or newer the menu is called **Apps** (it was **Add-ons** before).
- **Resources.** Claude Code typically uses a few hundred MB of RAM per
  session. Give the HA OS VM at least 4 GB RAM (2 GB free) and about 1.5 GB of
  free disk for the image build.
- **Internet during the build.** The Supervisor builds the image on your VM and
  downloads Debian packages and Claude Code (`claude.ai`, `downloads.claude.ai`).

## 3. Installation

The Supervisor builds this app locally from the Dockerfile; there is no
prebuilt image to pull. Choose one method.

### Method A — GitHub repository (recommended, easy updates)

The app is published at <https://github.com/rthom562/ClaudeAssistant>
(public repository; it contains no secrets).

1. In Home Assistant: **Settings → Apps → Install app** (app store), open the
   **⋮** menu (top right) → **Repositories**, paste
   `https://github.com/rthom562/ClaudeAssistant`, click **Add**, close.
2. Refresh the store page; **Claude Code** appears under your repository.
   Open it and click **Install**. The first build takes several minutes; watch
   progress in **Settings → System → Logs → Supervisor**.

### Method B — Local app (no GitHub)

1. Install the official **Terminal & SSH** app or the **Samba share** app so you
   can reach the local apps folder (shown as `/addons` in Terminal & SSH, or the
   `addons` share in Samba).
2. Copy the `claude_code` folder into it, so you have
   `/addons/claude_code/config.yaml`.
3. **Settings → Apps → Install app → ⋮ → Check for updates**.
4. **Claude Code** appears under **Local apps**. Open it and **Install**.

### After installing

1. **Configuration** tab: review options (see below), add your SSH public key,
   **Save**.
2. **Info** tab: enable **Start on boot**, **Watchdog** and **Show in sidebar**.
3. Click **Start**, then check the **Log** tab for `Ready`.
4. Click **Claude Code** in the sidebar (or **Open web UI**).

## 4. Configuration

| Option | Default | Meaning |
|---|---|---|
| `claude_config_access` | `read_only` | `read_only`: Claude Code's file-edit tools are denied for `/config`. `read_write`: edits allowed, each one needs your approval. |
| `protect_secrets` | `true` | Deny Claude's read tools for `secrets.yaml`, `.storage/auth*`, `.cloud/`. |
| `backup_before_edit` | `true` | Save a copy of each `/config` file before Claude's edit tools change it. |
| `backup_retention_days` | `30` | Delete pre-edit copies older than this at start. |
| `auto_update_claude` | `true` | Let Claude Code update itself (persistent). Off: use `claude update`. |
| `skip_permissions` | `true` | New/Resume tabs run Claude with `--dangerously-skip-permissions` (no approval prompts). See [section 8](#8-permissions-claude-code-vs-home-assistant-vs-the-filesystem). |
| `remote_control` | `true` | New/Resume tabs run Claude with `--remote-control` (also usable from claude.ai/code and the Claude app). |
| `phone_url` | empty | Your Nabu Casa URL (e.g. `https://abc123.ui.nabu.casa`) so the "Open on your phone" QR code works away from home. |
| `terminal_font_size` | `15` | Starting font size; the tab bar normally fits text to the window (Auto). |
| `ssh_enabled` | `true` | Start sshd (only if at least one key is configured). |
| `authorized_keys` | `[]` | SSH public keys, one per list entry. |
| `ssh_allow_forwarding` | `false` | Allow TCP/agent forwarding (VS Code Remote-SSH needs it). |
| `git_user_name` / `git_user_email` | empty | Optional git identity. |

**Network** section: `22/tcp` → host port, default `2222`. Change it here; clear
it to disable SSH at the network level.

Example (YAML mode of the Configuration tab):

```yaml
claude_config_access: read_write
protect_secrets: true
backup_before_edit: true
backup_retention_days: 30
auto_update_claude: true
skip_permissions: true
remote_control: true
phone_url: https://abc123.ui.nabu.casa
terminal_font_size: 15
ssh_enabled: true
authorized_keys:
  - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKeyOnlyReplaceMe me@laptop
ssh_allow_forwarding: false
git_user_name: Your Name
git_user_email: you@example.com
```

Restart the app after changing options.

**Recommended rollout:** keep `read_only` for the first sessions (let Claude
read and explain your configuration and propose changes), run `ha-git-init`,
then switch to `read_write`.

## 5. Signing in to Claude

No API key or credential is ever put in the Dockerfile, `config.yaml` or the
options. You sign in interactively once; the login is stored in
`/data/home/.claude/` and survives app restarts, rebuilds and HA reboots.

1. Open the **Claude Code** panel and click **New session** (or use **+ → Shell**
   and type `claude`).
2. Choose your theme, then the login method:
   - **Claude account with subscription** (Pro/Max/Team/Enterprise), or
   - **Anthropic Console account** (API billing).
3. The container has no browser, so Claude Code prints a sign-in URL. Open it
   in a browser on your phone or computer, sign in, and approve.
4. Copy the code shown and paste it into the terminal, press Enter.
5. Run `/status` inside Claude Code to confirm the account.
6. With `skip_permissions: true`, Claude Code shows a one-time warning about
   bypass mode and asks you to accept it. It may also ask once whether you
   trust the `/config` folder; Remote Control needs that trust.

**Copying the long URL from the browser terminal:** hold **Shift** while
dragging to select (tmux has mouse mode on). If a wrapped URL copies with
line breaks, sign in from an SSH session on your computer instead (`ssh -p
2222 root@homeassistant.local`, then `claude`); it uses the same login
storage.

**Sign out / switch account:** `/logout` inside Claude Code, or delete
`/data/home/.claude/.credentials.json`.

## 6. Daily use

### Tabs

The panel works like Windows Terminal:

- **+** opens a **New session** straight away:
  `claude --dangerously-skip-permissions --remote-control`
- **⌄** (next to +) opens the menu:
  - **New session**
  - **Resume session**:
    `claude --dangerously-skip-permissions --resume --remote-control`,
    showing the list of earlier conversations to pick from
  - **Shell**: a plain terminal (helpers, git, yamllint, …)
  (the two flags follow the `skip_permissions` / `remote_control` options)
- Click a tab to switch; **✕** (shown on hover) or middle-click closes it.
  Claude tabs ask first; Shell tabs close at once.
- **Double-click** a tab to rename it; **drag** tabs to reorder them; the mouse
  wheel scrolls the tab strip when there are many.
- **Text size:** **Auto** (default) fits the text to the window, so phones and
  wide monitors both get a sensible number of columns. **A− / A+** set a fixed
  size. Each device remembers its own choice.
- Every tab is its own independent session, started in `/config`.
- Tabs keep running when you close the page, lock your phone or lose the
  connection, and the same tabs appear on every device you open the panel on.
- When Claude exits inside a tab, the tab becomes a shell; type `exit` to
  close it.
- Tabs end when the app restarts (or HA OS reboots). Conversations do not:
  use **+ → Resume session** to pick them up again.

### On your phone

Click the **phone icon** (top right) for a QR code that opens this panel on
your phone. Sign in to **Home Assistant** with an administrator account (in
the browser or the Home Assistant Companion app). **The Claude account on your
phone doesn't matter**: the sessions run in this app with the Claude login
stored here, so a phone signed in to a different Claude account, or none,
works the same. Set `phone_url` to your Nabu Casa address so the QR code works
away from home; otherwise it uses the address you opened the panel with.

On touch screens a **key bar** appears with Esc, Tab, ⇧Tab, arrows, Enter
and Ctrl‑C. These are the keys Claude Code needs that phone keyboards lack
(Esc interrupts, ⇧Tab switches mode, arrows pick menu items). Toggle it with
the keyboard icon.

**Remote Control.** With `remote_control: true`, each Claude tab is also
listed at **claude.ai/code** and in the Claude mobile app under your account,
so you can follow or steer it from there. It needs a Claude subscription login
(not an API key); on Team/Enterprise an admin must allow it. Remote Control
only shows sessions to the **same Claude account** they are signed in with;
for a phone on another account, use the panel as described above.

### Commands

| Command | What it does |
|---|---|
| `claude` | Start an interactive session in the current directory |
| `ha-claude` | `cd /config && claude` |
| `claude --continue` (`-c`) | Continue the most recent session in this directory |
| `claude --resume` (`-r`) | Choose an earlier session to resume |
| `/resume` | Same, from inside Claude Code |
| `/init` | Create a project `CLAUDE.md` describing the current directory |
| `/permissions` | View permission rules (managed rules are listed too) |
| `claude doctor` | Check the installation |
| `claude update` | Update Claude Code now |

**Sessions.** Conversations are saved per directory in `~/.claude/projects/`
(persistent), so `--continue` and `--resume` work after restarts.

**Scrolling and copying.** Mouse wheel scrolls; hold Shift and drag to select
text.

**Project context.** `~/.claude/CLAUDE.md` (created on first start) holds
Home Assistant working rules that apply to every session; edit it freely.
Run `/init` in `/config` or any repo to create a project-specific `CLAUDE.md`.

**Git repositories.** Clone into `/data/workspace` (`~/workspace`). For SSH
remotes create a key once:
```bash
ssh-keygen -t ed25519 -C "claude-assistant"
cat ~/.ssh/id_ed25519.pub   # add to GitHub/GitLab as a deploy or user key
```
Keys in `/data/home/.ssh` persist.

## 7. Working on your Home Assistant configuration

Suggested workflow:

1. `ha-git-init` once (creates a safe `.gitignore`, initial commit).
2. `ha-claude`, then ask, for example:
   - "Explain how my automations for the living room work."
   - "Why does my `configuration.yaml` fail with *mapping values are not allowed*?"
   - "Create an automation that dims the living room lights when the TV turns on after sunset."
   - "Build a YAML dashboard for the home theater in `/config/dashboards/theater.yaml`."
   - "Write a template sensor for average indoor temperature."
   - "Review `/config/esphome/garage.yaml`."
3. Approve or reject each edit Claude proposes (you will see a diff).
4. `ha-yaml-lint <file>` for a quick syntax check.
5. In Home Assistant: **Developer tools → YAML → Check configuration**, then
   reload the relevant section (Automations, Scripts, Template entities …) or
   restart. This app never does that for you.
6. `git -C /config commit -am "describe change"`.

Notes:

- UI-created automations live in `automations.yaml` with an `id:`; Claude is
  told to keep IDs so they stay editable in the UI.
- Storage-mode (UI) dashboards are stored in `.storage/` and are deliberately
  protected from edits. Ask Claude for a YAML dashboard, or for card YAML you
  paste into the dashboard's raw configuration editor.

## 8. Permissions: Claude Code vs Home Assistant vs the filesystem

Three separate layers decide what can happen:

**1. Home Assistant permissions — who can open the terminal.**
Your Home Assistant user account and its admin flag decide who sees the
**Claude Code** panel (`panel_admin: true` → administrators only). HA
permissions do *not* limit what happens inside the terminal: anyone who can
open it is root in this container.

**2. Container and filesystem — the hard limits.**
The container sees only:
- `/config` — your HA configuration, read/write (or read-only if you change
  the map, below),
- `/data` — this app's own storage.
It cannot see the HA OS host filesystem, other apps' data, `/ssl`, `/share`,
`/media`, `/backup`, Docker, or hardware devices. It has **no Supervisor API
and no Home Assistant API**, so nothing in it — including Claude — can restart
Home Assistant, call services, read entity states or change integrations.
These limits are enforced by Docker and the Supervisor and cannot be changed
from inside the container.

**3. Claude Code permissions — what Claude does on your behalf.**
Claude Code asks before running shell commands and before editing files. On
top of that, this app writes **managed settings**
(`/etc/claude-code/managed-settings.json`) that take priority over user and
project settings:
- `read_only`: deny Claude's edit tools for `/config/**`.
- `read_write`: allow edits, but always **ask** for every `/config` change, even
  in "accept edits" mode or with an "always allow" rule.
- Always deny edits to `/config/.storage/**` and `/config/.cloud/**`.
- `protect_secrets`: deny Claude's read tools for secrets and auth storage.
- A pre-edit backup hook runs before each edit tool.
- With `skip_permissions: false`, "bypass permissions" mode is disabled
  entirely.

**`skip_permissions: true` (the default for tabs).** New and Resume tabs run
`--dangerously-skip-permissions`: Claude edits files and runs shell commands
**without asking**, including in your live `/config`. What still protects you:
- **deny** rules still apply, so in `read_only` mode Claude's edit tools still
  cannot change `/config`, `.storage`/`.cloud` stay protected, and secrets stay
  hidden from its read tools; switch to `read_write` to let tabs edit;
- the pre-edit backup hook still copies every file Claude's edit tools touch;
- the container limits (layer 2) are unchanged: still no HA restart, no
  Supervisor/HA API, no host filesystem.
What it no longer does: ask before shell commands, which run as root and can
change `/config` too (`sed -i`, `rm`, `git checkout` …) without the backup
hook. Commit with git before handing Claude large tasks. To be asked before
each action, set `skip_permissions: false` and restart the app.

**Important:** layer 3 is a guardrail on Claude's *built-in tools*. A shell
command (`sed -i …`, `cat secrets.yaml`, `git checkout …`) runs as root and is
not stopped by these rules or covered by the backup hook.

**Filesystem-level read-only** (strongest option): in `claude_code/config.yaml`
change

```yaml
map:
  - type: homeassistant_config
    read_only: true
    path: /config
```

bump `version:` (e.g. `1.0.1`), push / copy, then **Rebuild** (or update) the
app. Nothing in the container can then write to your configuration.

## 9. Remote browser access through Nabu Casa

Nothing extra to configure. If Home Assistant Cloud **Remote UI** works, the
Claude Code panel works:

1. Open your `https://<id>.ui.nabu.casa` address (or the Companion app).
2. Sign in with your Home Assistant user (with multi-factor authentication if
   enabled).
3. Click **Claude Code** in the sidebar.

How the browser path is protected:

- **Transport.** Remote UI traffic is TLS-encrypted end to end between your
  browser and your Home Assistant instance; the TLS certificate and key live on
  your instance, and Nabu Casa's relay forwards the encrypted stream without
  being able to read it.
- **Authentication.** Every request must belong to a logged-in Home Assistant
  session. Ingress panels are opened through the HA frontend, which asks the
  Supervisor for an Ingress session tied to your authenticated user; the
  Supervisor checks that session on every request (including the terminal's
  WebSocket) before proxying it. Because `panel_admin: true`, non-admin users
  get no access.
- **No other path in.** The app's web port (8099) is not published on the VM's
  network. nginx inside the container accepts only the Supervisor's proxy
  address (`172.30.32.2`), and ttyd listens on the container's loopback only,
  so neither the LAN nor other apps can reach the terminal directly.

Recommendations: enable MFA for every admin user, keep the number of admin
accounts small, and remember that opening this panel gives root in the app
container with access to your configuration.

**Remote Control is a second, separate path.** With `remote_control: true`,
your Claude tabs can also be reached through claude.ai/code and the Claude
mobile app. That path is protected by your **Claude account** login, not by
Home Assistant, so protect that account too (strong password / SSO, MFA where
available). Combined with `skip_permissions: true`, anyone signed in to your
Claude account can make Claude change your HA configuration.

**SSH is not available through Nabu Casa.** Remote UI relays only the Home
Assistant web interface (HTTPS/WebSocket). It does not forward SSH or other
TCP ports. Remote access is browser-only by design here; SSH is for your LAN.

## 10. SSH on your local network

SSH is separate from Home Assistant's own Terminal & SSH app: different
container, different host port (default **2222**), different keys, and it lands
in *this* container with Claude Code.

1. On your computer, create a key if you do not have one:
   ```bash
   ssh-keygen -t ed25519 -C "me@laptop"
   cat ~/.ssh/id_ed25519.pub
   ```
2. Paste the single `ssh-ed25519 AAAA… me@laptop` line into
   `authorized_keys` in the app Configuration, Save, restart the app. The log
   should say `SSH enabled with 1 authorized key(s)`.
3. Connect (use your HA OS VM's LAN IP or `homeassistant.local`):
   ```bash
   ssh -p 2222 root@homeassistant.local
   ```
   Join a browser tab's session from SSH:
   ```bash
   tmux ls                       # lists cc-xxxxxxxxxx sessions
   tmux attach -t cc-xxxxxxxxxx  # Ctrl-b d to detach again
   ```
4. Optional `~/.ssh/config` entry:
   ```
   Host ha-claude
       HostName homeassistant.local
       Port 2222
       User root
       IdentityFile ~/.ssh/id_ed25519
   ```
   then `ssh ha-claude`.

Security properties: password and keyboard-interactive login are disabled;
only `root` with a listed key may log in; host keys are generated once and kept
in `/data/ssh` (no "host key changed" warnings after restarts); forwarding is
off unless `ssh_allow_forwarding: true`.

**Do not** forward port 2222 on your router or expose it to the internet. For
VS Code Remote-SSH on the LAN, set `ssh_allow_forwarding: true`.

## 11. Persistent storage

Everything below lives in the app's `/data` volume, which survives restarts,
image rebuilds, app updates and Home Assistant reboots:

| Path | Contents |
|---|---|
| `/data/home` | root's home directory |
| `/data/home/.claude/` | Claude login (`.credentials.json`), settings, `CLAUDE.md`, session history (`projects/`), todos |
| `/data/home/.claude.json` | Claude Code preferences and project state |
| `/data/home/.local/` | Claude Code binary and versions (auto-updates land here) |
| `/data/home/.ssh/` | your git SSH keys, extra `authorized_keys` |
| `/data/home/.gitconfig`, `.bash_history` | git identity, shell history |
| `/data/workspace/` | your projects and git repositories |
| `/data/ssh/` | SSH host keys, `authorized_keys` generated from options |
| `/data/backups/config/` | pre-edit copies of `/config` files; `backup.log` |

Container files outside `/data` and `/config` (including `/etc`) are
re-created from the image on every start.

## 12. Backup and recovery

**Home Assistant backups.** A full backup includes this app's `/data` (login,
settings, workspace, pre-edit copies) and, separately, your `/config`. A
partial backup can include just this app. Large caches and the Claude Code
binary are excluded (they are re-downloaded automatically). Because backups
contain your Claude login token, store them securely and keep backup
encryption enabled.

**Before a big change.**
```bash
git -C /config add -A && git -C /config commit -m "before refactor"
```
and/or create a manual HA backup (Settings → System → Backups).

**Undo one file Claude edited.**
```bash
ha-config-backups list automations.yaml
ha-config-backups diff 20261114-154512-123456789 automations.yaml
ha-config-backups restore 20261114-154512-123456789 automations.yaml
```
or with git: `git -C /config checkout -- automations.yaml`.

**Home Assistant won't start after a change.** The Ingress panel needs a
running Home Assistant Core, but this app keeps running independently. Use
SSH (`ssh -p 2222 root@<VM IP>`), restore the file (git or
`ha-config-backups`), then start Core from the HA OS console or the official
Terminal & SSH app (`ha core start` / `ha core restart`). This is the main
reason to set up SSH even if you prefer the browser.

**Restore the app itself.** Restore the app from an HA backup (Settings →
System → Backups → select backup → choose the Claude Code app). Login,
settings, sessions and workspace come back with it.

**Start fresh with Claude login.** Delete `/data/home/.claude/.credentials.json`
and run `claude` again.

**Push your config to a private remote (optional).**
```bash
cd /config
git ls-files | grep -i secret   # must print nothing
git remote add origin git@github.com:YOUR_USER/ha-config-private.git
git push -u origin main
```

## 13. Troubleshooting

| Symptom | What to check |
|---|---|
| Install/build fails | **Settings → System → Logs → Supervisor**. Usually a network/DNS problem reaching `deb.debian.org` or `claude.ai`, or low disk space. Retry with **Rebuild**. |
| Panel shows *502* / blank | App **Log** tab: did nginx and ttyd start? Restart the app. Check that the Watchdog isn't looping (look for repeated `exited` lines). |
| Terminal connects then drops via Nabu Casa | Usually network changes on mobile; reopen the panel. With tmux nothing is lost. |
| Text is read-only / can't type | Hard-refresh the page; ttyd is started with `--writable`. |
| `claude: command not found` | `ls -l ~/.local/bin/claude`; run `/opt/claude-code/claude install stable`, or restart the app (it re-installs if missing). |
| Asked to sign in after every restart | Check `ls -la /data/home/.claude/.credentials.json` and `echo $HOME` (must be `/data/home`). |
| Login URL won't copy cleanly | See [section 5](#5-signing-in-to-claude): Shift+drag, or sign in over SSH. |
| "+ New session" does nothing / "Could not start session" | App log for `tab-service` errors; try **+ → Shell** to check the terminal works. |
| Tab says "This session has ended" | Claude/shell exited or the app restarted; close the tab (it also disappears within a few seconds). |
| `--dangerously-skip-permissions cannot be used with root/sudo privileges` | A Claude Code update changed the root check. Set `skip_permissions: false` and restart the app; tabs then run normally with prompts. |
| Remote Control not offered / error | Needs a Claude subscription login (not API key), a recent Claude Code (`claude update`), and on Team/Enterprise the admin toggle. Set `remote_control: false` to start tabs without it. |
| Claude says it can't edit `/config` | `claude_config_access` is `read_only` (see banner). Switch to `read_write`, restart, start a new Claude session. |
| Edits fail with "read-only file system" | You set `read_only: true` in the map (hard read-only). |
| Changes have no effect in HA | You must reload YAML or restart HA yourself; check *Check configuration* output. |
| `ssh: connect … Connection refused` | `ssh_enabled` on? At least one key? Port mapped under Network? Log should show `Starting sshd`. Correct port (`-p 2222`)? |
| `Permission denied (publickey)` | User must be `root`; key line complete (one line, `ssh-ed25519 …`); `ssh -v -p 2222 root@host` shows which key is offered. |
| *REMOTE HOST IDENTIFICATION HAS CHANGED* | Only after reinstalling (host keys deleted with `/data`): `ssh-keygen -R "[homeassistant.local]:2222"`. |
| Port 2222 already in use | Change the host port in the Network section. |
| Claude Code very slow / killed | VM low on RAM; check **Settings → System → Hardware**; close extra sessions. |
| Check the installation | `claude doctor`; `cat /etc/claude-code/managed-settings.json`; inside Claude, `/status` and `/permissions`. |

## 14. Updating and uninstalling

**Claude Code** updates itself in `/data/home/.local` when
`auto_update_claude: true`, or run `claude update`. The copy baked into the
image is only a fallback for first start.

**The app** (Dockerfile, scripts): bump `version:` in `config.yaml`, push to
GitHub (Method A) — HA offers the update — or copy the folder again and use
**Rebuild** (Method B). `/data` and `/config` are untouched.

**Uninstalling** the app can delete its `/data` volume (login, workspace,
pre-edit backups). Take a backup of the app or copy `/data/workspace` first.
Your `/config` is not affected.

## 15. Compatibility notes and limitations

- **Native installer at build time.** The image runs Anthropic's official
  `curl -fsSL https://claude.ai/install.sh | bash` during the Supervisor's
  local build, and `claude install stable` on first start to place the
  managed installation in persistent storage. Both need internet access.
- **Runs as root in the container.** Home Assistant app containers run as
  root and HA's own config files are owned by root, so file ownership and
  permissions in `/config` are preserved. Claude Code refuses
  `--dangerously-skip-permissions` as root; tabs set `IS_SANDBOX=1` (only
  inside tab sessions) to allow it. That variable is not an official,
  documented setting and a future Claude Code release could stop honouring
  it — see Troubleshooting.
- **No HA API by design.** Claude cannot validate the configuration with Home
  Assistant itself, reload YAML or restart. This keeps the "never restart
  automatically" guarantee hard rather than a promise. You run Check
  configuration and reloads.
- **Guardrails vs hard limits.** `read_only` and `protect_secrets` limit
  Claude's tools, not shell commands you approve. Use the read-only map for a
  hard guarantee.
- **Tabs end on app restart.** Conversations do not — use **Resume session**.
- **amd64 only** as configured. Claude Code also supports aarch64; add it to
  `arch:` if you ever move to an ARM device.
- **Resource limits.** Home Assistant apps cannot set CPU/RAM limits in
  `config.yaml`; usage is mostly idle except while Claude is working.
- **Default AppArmor profile** from the Supervisor applies; no custom profile is
  shipped.

## 16. Audit checklist

| Item | How it is met |
|---|---|
| AMD64 | `arch: [amd64]`; multi-arch Debian base resolves to amd64; Claude Code native linux-x64 build. |
| HA OS 18.x | Supervisor-built local app; no deprecated `build.yaml`; current map type `homeassistant_config`; `init: false` for s6-overlay v3. |
| Ingress | `ingress: true`, port 8099, nginx proxies WebSockets; ttyd uses relative URLs so it works under the Ingress path. |
| Nabu Casa | Uses the standard Ingress panel, so it rides on Remote UI with HA authentication; no extra ports. |
| Persistent authentication | `HOME=/data/home`; `~/.claude/.credentials.json` and `~/.claude.json` in `/data`. |
| Persistent workspace | `/data/workspace`, session history in `~/.claude/projects`. |
| Secure SSH | Keys only, root only, no passwords, persistent host keys, forwarding off, LAN port, separate from HA's SSH app. |
| Filesystem mappings | Only `/config` (HA config) and `/data`; no Docker socket, devices, host FS or privileged flags. |
| No auto overwrite / restart | Default read-only guardrail; pre-edit backups; no HA/Supervisor API, so no restarts. With `skip_permissions: true` (your choice) edits in read/write mode are applied without asking; set it to `false` to restore per-edit approval. |
| No credentials in logs | Options are never echoed; nginx access log off; Supervisor token dropped before services start. |
