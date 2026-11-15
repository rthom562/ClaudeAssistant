# Claude Code

[![GitHub](https://img.shields.io/badge/GitHub-rthom562%2FClaudeAssistant-181717?logo=github)](https://github.com/rthom562/ClaudeAssistant)
[![Version](https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2Frthom562%2FClaudeAssistant%2Fmain%2Fclaude_code%2Fconfig.yaml&query=%24.version&label=version&color=d97757&cacheSeconds=600)](https://github.com/rthom562/ClaudeAssistant/blob/main/claude_code/CHANGELOG.md)
![Supports amd64 Architecture][amd64-shield]
![Supports aarch64 Architecture][aarch64-shield]

Anthropic's Claude Code in your Home Assistant sidebar: a tabbed browser
terminal (works through Nabu Casa), key-only SSH, and guarded access to your
configuration.

## Supported systems

- **Home Assistant OS** (Supervised probably works but is unsupported)
- **amd64**: Intel/AMD PCs, mini PCs, and virtual machines
- **aarch64**: Raspberry Pi 4 (4 GB+) and 5, Home Assistant Green, and
  Home Assistant Yellow
- 32-bit systems (Raspberry Pi 3 and older, armv7, armhf, i386) are
  **not** supported

## Requirements

- About 4 GB RAM
- A Claude Pro, Max, Team, or Enterprise plan, or an Anthropic Console
  account

## Features

- **+** opens a new Claude session; **⌄** offers **Resume** or **Shell**
- Tabs keep running and sync across devices
- Text fits the window; there's a phone QR code and a phone key bar
- `/config` is read-only by default; secrets are protected and every file is
  backed up before Claude edits it
- Claude cannot restart Home Assistant

See the **Documentation** tab for setup, options, and safety details.
Source code, issues, and releases: [github.com/rthom562/ClaudeAssistant](https://github.com/rthom562/ClaudeAssistant).

[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
