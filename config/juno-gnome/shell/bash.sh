#!/usr/bin/env bash
# Sourced only by an interactive Bash; keeps the user's login shell unchanged.
[[ $- == *i* && ${TERM:-dumb} != dumb && ${TERM:-dumb} != linux ]] || return 0
[[ ${_JUNO_POSH_INITIALIZED_BASHPID:-} != "$BASHPID" ]] || return 0
if [[ -x $HOME/.local/share/juno-apps/oh-my-posh/current/oh-my-posh && -r $HOME/.config/juno-gnome/oh-my-posh.json ]]; then
    if _juno_posh_init=$("$HOME/.local/share/juno-apps/oh-my-posh/current/oh-my-posh" init bash \
        --config "$HOME/.config/juno-gnome/oh-my-posh.json") && [[ -n $_juno_posh_init ]]; then
        if eval "$_juno_posh_init"; then
            _JUNO_POSH_INITIALIZED_BASHPID=$BASHPID
            export -n _JUNO_POSH_INITIALIZED_BASHPID
        fi
    fi
    unset _juno_posh_init
fi
