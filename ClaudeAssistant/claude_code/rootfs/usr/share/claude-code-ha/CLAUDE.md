# Working in this Home Assistant environment

You are running inside a Home Assistant OS app container (not on the HA host).

## Layout
- `/config` is the LIVE Home Assistant configuration directory. Changes take
  effect the next time Home Assistant reloads or restarts.
- `/data/workspace` (also `~/workspace`) is for other projects and repositories.
- There is no `ha` CLI, no Supervisor API and no Home Assistant API in this
  container. You cannot restart Home Assistant, reload YAML, call services or
  read entity states. Do not try to work around this.

## Rules
- Never restart or reload Home Assistant. When a change is ready, tell the user
  to run Developer tools > YAML > Check configuration and then reload the
  relevant YAML (or restart) themselves.
- Explain what you intend to change and show the diff before editing files in
  `/config`. Prefer small, targeted edits over rewriting whole files.
- Before larger or multi-file changes, recommend a git commit
  (`ha-git-init` once, then `git -C /config commit -am "..."`).
- Never edit anything under `/config/.storage/` or `/config/.cloud/`; these are
  managed by Home Assistant at runtime (this includes UI/storage-mode dashboards
  `lovelace*`, integrations and the entity registry).
- Never print, copy or move secret values. Reference them with `!secret name`.
- Check YAML syntax with `ha-yaml-lint <file>` after editing.

## Home Assistant conventions
- `automations.yaml`, `scripts.yaml` and `scenes.yaml` are also written by the
  HA UI editors. Keep every existing `id:` unchanged; give new automations a
  unique `id:` so they stay editable in the UI.
- Use the current syntax: `triggers:` / `conditions:` / `actions:`,
  `trigger: state` (not `platform: state`), and `action: light.turn_on`
  (not `service:`).
- Templates use Jinja2; prefer `states('sensor.x') | float(0)` style defaults.
- YAML-mode dashboards: create files such as `/config/dashboards/<name>.yaml`
  and register them under `lovelace: dashboards:` in `configuration.yaml`.
- ESPHome device configurations live in `/config/esphome/`; compiling and
  flashing is done by the ESPHome app, not here.
- Packages, if used, live under the directory referenced by
  `homeassistant: packages:` in `configuration.yaml`.
