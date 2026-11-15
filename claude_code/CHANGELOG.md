# Changelog

## 1.1.0

- **Live progress on tabs**, like Windows Terminal: a tab's icon pulses grey
  while Claude is working and turns orange when it's done (or needs you).
  Driven by Claude Code hooks, so it's accurate for background tabs too.
- **Tabs are named after the chat.** New tabs start as "Claude", resumed ones
  as "Resume", and switch to the conversation's name as soon as Claude names
  it (or you use /rename). No more "New 1", "Resume 2".
- Double-click a tab and clear the name to go back to automatic naming.
- Tab icons use the app's own mark; the "+" menu reads Claude / Resume / Shell.
- Stopping Claude with Ctrl-C leaves the tab open as a shell instead of
  closing it.
- The tab bar refreshes every 1.5 seconds.

## 1.0.0

First public release.

- Claude Code installed with Anthropic's official native installer and kept in
  persistent storage, so login, settings, sessions and updates survive
  restarts and reboots.
- Browser terminal through Home Assistant Ingress (admin only), works
  remotely through Home Assistant Cloud / Nabu Casa.
- Windows Terminal-style tab bar: "+" opens a new session, "⌄" offers
  New / Resume / Shell; hover close, middle-click close, double-click rename,
  drag to reorder. Every tab is its own persistent session, shared across
  devices.
- New tabs run `claude --dangerously-skip-permissions --remote-control`,
  Resume tabs add `--resume` (both flags switchable in the options).
- Text fits the window automatically (Auto) with A-/A+ overrides.
- "Open on your phone" QR code (`phone_url` option) and a phone key bar
  (Esc, Tab, Shift-Tab, arrows, Enter, Ctrl-C).
- Runs on 64-bit Intel/AMD (amd64) and ARM (aarch64: Raspberry Pi 4/5,
  Home Assistant Green/Yellow).
- Key-only SSH on a configurable host port (default 2222).
- Home Assistant configuration mapped at /config, with a read-only guardrail
  by default, protected secrets and .storage, and automatic pre-edit backups.
- Helper commands: ha-git-init, ha-yaml-lint, ha-config-backups.
