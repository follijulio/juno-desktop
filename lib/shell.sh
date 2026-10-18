#!/usr/bin/env bash
# Stage additive Bash integration and JSONC editor settings; never execute user rc.

_terminal_error() { printf '[Juno · terminal] %s\n' "$*" >&2; return 1; }

_terminal_input() {
    local path=$1
    [[ ! -e $path && ! -L $path ]] && return 0
    [[ -f $path && ! -L $path && $(stat -c %h -- "$path") == 1 && $(stat -c %u -- "$path") == "$(id -u)" ]] || {
        _terminal_error "Configuração precisa ser arquivo regular próprio, sem links: $path"; return 1;
    }
}

_terminal_mode() {
    local source=$1 stage=$2
    if [[ -f $source ]]; then
        chmod --reference="$source" -- "$stage"
    else
        chmod 600 -- "$stage"
    fi
}

juno_stage_terminal() {
    local bash_stage code_stage bash_input code_input
    juno_require python3 node sha256sum
    _terminal_input "$JUNO_HOME/.bashrc" || return 1
    _terminal_input "$JUNO_HOME/.config/Code/User/settings.json" || return 1
    # Merge the immutable transaction baseline, never a concurrently edited rc.
    bash_input=$(txn_stage_input_for '.bashrc') || return 1
    code_input=$(txn_stage_input_for '.config/Code/User/settings.json') || return 1
    _terminal_input "$bash_input" || return 1
    _terminal_input "$code_input" || return 1
    bash_stage=$(txn_stage_for '.bashrc') || return 1
    code_stage=$(txn_stage_for '.config/Code/User/settings.json') || return 1
    (cd -- "$JUNO_ROOT/vendor/jsonc-parser" && sha256sum --check --strict SHA256SUMS) || {
        _terminal_error 'Integridade do parser JSONC não confirmada.'; return 1;
    }
    python3 "$JUNO_ROOT/tools/stage_bashrc.py" "$bash_input" "$bash_stage" || return 1
    bash -n "$bash_stage" || { _terminal_error 'Bash recusou o rc preparado; arquivo existente preservado.'; return 1; }
    node "$JUNO_ROOT/tools/vscode_settings.cjs" "$code_input" "$code_stage" \
        "$JUNO_ROOT/config/juno-gnome/terminal-settings.json" || return 1
    _terminal_mode "$bash_input" "$bash_stage" || return 1
    _terminal_mode "$code_input" "$code_stage" || return 1
}
