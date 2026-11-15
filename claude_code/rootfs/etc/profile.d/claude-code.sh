# Loaded by every login shell: the browser terminal (ttyd -> tmux -> bash -l)
# and SSH sessions.

export HOME=/data/home
export PATH="/data/home/.local/bin:/opt/claude-code:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export EDITOR=nano
export VISUAL=nano
export HISTFILE=/data/home/.bash_history
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth

# Non-interactive shells stop here.
case $- in
    *i*) ;;
    *) return 0 2>/dev/null || exit 0 ;;
esac

shopt -s histappend checkwinsize
PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
PS1='\[\e[1;35m\]claude-code\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '

if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
fi

alias ll='ls -alF'
alias ha='cd /config'
alias ws='cd /data/workspace'
alias ha-claude='cd /config && claude'

if [ -z "${CLAUDE_HA_WELCOMED:-}" ]; then
    export CLAUDE_HA_WELCOMED=1
    /usr/local/bin/claude-ha-welcome
fi
