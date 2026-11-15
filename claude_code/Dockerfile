#
# Claude Code app for Home Assistant OS (amd64).
#
# Debian (glibc) base image maintained by Home Assistant. It includes
# s6-overlay v3 (/init as ENTRYPOINT), bashio and tzdata.
# Published as a multi-arch image since docker-base 2026.03.1, so no
# per-arch image name or build.yaml is needed.
FROM ghcr.io/home-assistant/base-debian:trixie

# Supplied by the Supervisor / builder; kept for labels.
ARG BUILD_ARCH=amd64
# Channel passed to Anthropic's official native installer:
# "stable" (about a week behind, skips releases with regressions),
# "latest", or an exact version such as "2.1.89".
ARG CLAUDE_CODE_CHANNEL=stable
# ttyd is not packaged in Debian trixie (only in unstable), so the official
# static release binary from https://github.com/tsl0922/ttyd is used.
ARG TTYD_VERSION=1.7.7

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TERM=xterm-256color

# ---------------------------------------------------------------------------
# System packages (all from Debian trixie main):
#   nginx           Ingress front end; only accepts the Supervisor's IP
#   tmux            one persistent session per browser tab
#   python3         small local tab service (stdlib only)
#   qrencode        QR code for "Open on your phone"
#   openssh-server  key-only SSH into this container
#   git, openssh-client  version control and pushing over SSH
#   yamllint, jq, ripgrep, nano, vim-tiny, less  editing and troubleshooting
# ---------------------------------------------------------------------------
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash-completion \
        ca-certificates \
        curl \
        file \
        git \
        jq \
        less \
        nano \
        nginx \
        openssh-client \
        openssh-server \
        procps \
        python3 \
        qrencode \
        ripgrep \
        tmux \
        unzip \
        vim-tiny \
        yamllint \
    && rm -rf /var/lib/apt/lists/* \
    # No package-default site, no image-baked SSH host keys.
    && rm -f /etc/nginx/sites-enabled/default /etc/ssh/ssh_host_* \
    # Root's home lives in persistent storage. "*" = no password, but the
    # account is not "locked", so sshd still accepts public-key logins.
    # (Edited directly: usermod refuses to change root's home during a build
    # because root is "currently used by process 1".)
    && sed -i -E 's#^root:([^:]*):0:0:([^:]*):[^:]*:[^:]*$#root:\1:0:0:\2:/data/home:/bin/bash#' /etc/passwd \
    && sed -i -E 's#^root:[^:]*:#root:*:#' /etc/shadow \
    && grep -q '^root:[^:]*:0:0:[^:]*:/data/home:/bin/bash$' /etc/passwd \
    && mkdir -p /run/sshd

# ---------------------------------------------------------------------------
# ttyd (browser terminal, xterm.js over WebSocket): official static amd64
# release, verified against the release's SHA256SUMS file.
# ---------------------------------------------------------------------------
RUN mkdir -p /tmp/ttyd && cd /tmp/ttyd \
    && curl -fsSL -o ttyd.x86_64 \
        "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64" \
    && curl -fsSL -o SHA256SUMS \
        "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/SHA256SUMS" \
    && grep -E '[[:space:]]\*?ttyd\.x86_64$' SHA256SUMS | sha256sum -c - \
    && install -m 0755 ttyd.x86_64 /usr/local/bin/ttyd \
    && /usr/local/bin/ttyd --version \
    && cd / && rm -rf /tmp/ttyd

# ---------------------------------------------------------------------------
# Claude Code, installed with Anthropic's official native installer.
# The binary is kept in /opt/claude-code as a seed / fallback. On first start
# run.sh runs "claude install" so the real installation lives in persistent
# storage (/data/home/.local) where auto-updates survive restarts.
# ---------------------------------------------------------------------------
RUN mkdir -p /tmp/claude-install \
    && HOME=/tmp/claude-install bash -c \
        'curl -fsSL https://claude.ai/install.sh | bash -s "${CLAUDE_CODE_CHANNEL}"' \
    && install -D -m 0755 \
        "$(readlink -f /tmp/claude-install/.local/bin/claude)" \
        /opt/claude-code/claude \
    && /opt/claude-code/claude --version | tee /opt/claude-code/VERSION \
    && rm -rf /tmp/claude-install

# App files
COPY rootfs/ /
COPY run.sh /run.sh
RUN chmod 0755 /run.sh /usr/local/bin/* \
    && chmod 0644 /etc/nginx/nginx.conf /etc/tmux.conf /etc/profile.d/claude-code.sh \
        /usr/share/claude-code-ha/www/index.html

# Docker-level health check: Ingress front end -> ttyd.
HEALTHCHECK --interval=60s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -fsS -o /dev/null --max-time 5 http://127.0.0.1:8099/ || exit 1

LABEL \
    io.hass.type="addon" \
    io.hass.arch="${BUILD_ARCH}" \
    org.opencontainers.image.title="Claude Code for Home Assistant" \
    org.opencontainers.image.description="Claude Code CLI with Ingress browser terminal and SSH" \
    org.opencontainers.image.licenses="MIT"

CMD ["/run.sh"]
