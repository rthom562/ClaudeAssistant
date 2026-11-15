# Changelog

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
- Key-only SSH on a configurable host port (default 2222).
- Home Assistant configuration mapped at /config, with a read-only guardrail
  by default, protected secrets and .storage, and automatic pre-edit backups.
- Helper commands: ha-git-init, ha-yaml-lint, ha-config-backups.
