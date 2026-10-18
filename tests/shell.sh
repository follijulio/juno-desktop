#!/usr/bin/env bash
set -euo pipefail

TEST_REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/juno-shell-tests.XXXXXXXX")
trap '[[ -n "$TEST_ROOT" && "$TEST_ROOT" != / && "${TEST_ROOT##*/}" == juno-shell-tests.* ]] && rm -rf -- "$TEST_ROOT"' EXIT
export PATH="$TEST_REPO/.cache/qa/bin:$PATH"
export HOME="$TEST_ROOT/home with spaces"
export TEST_POSH_LOG="$TEST_ROOT/invocations"
mkdir -p -- "$HOME/.config/juno-gnome/shell" "$HOME/.local/share/juno-apps/oh-my-posh/current"
cp -- "$TEST_REPO/config/juno-gnome/shell/bash.sh" "$HOME/.config/juno-gnome/shell/bash.sh"
cp -- "$TEST_REPO/config/juno-gnome/oh-my-posh.json" "$HOME/.config/juno-gnome/oh-my-posh.json"
cat >"$HOME/.local/share/juno-apps/oh-my-posh/current/oh-my-posh" <<'MOCK'
#!/usr/bin/env bash
[[ $1 == init && $2 == bash && $3 == --config && $4 == "$HOME/.config/juno-gnome/oh-my-posh.json" ]] || exit 64
printf 'init\n' >>"$TEST_POSH_LOG"
[[ ${TEST_POSH_FAIL:-0} == 0 ]] || exit 1
printf 'JUNO_TEST_INIT_COUNT=$(( ${JUNO_TEST_INIT_COUNT:-0} + 1 ))\n'
MOCK
chmod +x -- "$HOME/.local/share/juno-apps/oh-my-posh/current/oh-my-posh"
: >"$TEST_POSH_LOG"

TERM=xterm-256color bash --noprofile --norc -c 'source "$HOME/.config/juno-gnome/shell/bash.sh"'
[[ ! -s $TEST_POSH_LOG ]]
for terminal in dumb linux ''; do
    TERM=$terminal bash --noprofile --norc -ic 'source "$HOME/.config/juno-gnome/shell/bash.sh"' 2>/dev/null
    [[ ! -s $TEST_POSH_LOG ]]
done

cat >"$TEST_ROOT/interactive.sh" <<'CHECK'
source "$HOME/.config/juno-gnome/shell/bash.sh"
source "$HOME/.config/juno-gnome/shell/bash.sh"
[[ $JUNO_TEST_INIT_COUNT == 1 && $_JUNO_POSH_INITIALIZED_BASHPID == "$BASHPID" ]] || exit 1
[[ $(export -p) != *'_JUNO_POSH_INITIALIZED_BASHPID'* ]] || exit 2
bash --noprofile --norc -ic '[[ -z ${_JUNO_POSH_INITIALIZED_BASHPID:-} ]]; source "$HOME/.config/juno-gnome/shell/bash.sh"; [[ $JUNO_TEST_INIT_COUNT == 1 ]]' || exit 3
CHECK
TERM=xterm-256color bash --noprofile --norc -i "$TEST_ROOT/interactive.sh" 2>/dev/null
[[ $(wc -l <"$TEST_POSH_LOG") == 2 ]]

TERM=xterm-256color TEST_POSH_FAIL=1 bash --noprofile --norc -ic 'PS1=original; source "$HOME/.config/juno-gnome/shell/bash.sh"; [[ $PS1 == original && -z ${_JUNO_POSH_INITIALIZED_BASHPID:-} ]]' 2>/dev/null
rm -- "$HOME/.local/share/juno-apps/oh-my-posh/current/oh-my-posh"
TERM=xterm-256color bash --noprofile --norc -ic 'PS1=original; source "$HOME/.config/juno-gnome/shell/bash.sh"; [[ $PS1 == original ]]' 2>/dev/null

node "$TEST_REPO/tests/vscode_settings_test.cjs"

# Run the actual staging boundary too: helpers must not change or execute user
# configuration, and the distributed JSONC parser must pass integrity checks.
JUNO_ROOT=$TEST_REPO
JUNO_HOME=$HOME
source "$TEST_REPO/lib/common.sh"
source "$TEST_REPO/lib/shell.sh"
mkdir -p -- "$HOME/.config/Code/User" "$TEST_ROOT/stage"
printf '# user rc\nexport EDITOR=vim\nprintf executed > %q\n' "$TEST_ROOT/never-execute" >"$HOME/.bashrc"
printf '{\n  // Keep user settings.\n  "editor.fontSize": 15,\n}\n' >"$HOME/.config/Code/User/settings.json"
cp -- "$HOME/.bashrc" "$TEST_ROOT/original-rc"
cp -- "$HOME/.config/Code/User/settings.json" "$TEST_ROOT/original-settings"
txn_stage_for() {
    case $1 in
        .bashrc) printf '%s\n' "$TEST_ROOT/stage/bashrc" ;;
        .config/Code/User/settings.json) printf '%s\n' "$TEST_ROOT/stage/settings.json" ;;
        *) return 1 ;;
    esac
}
txn_stage_input_for() {
    case $1 in
        .bashrc) printf '%s\n' "$TEST_ROOT/original-rc" ;;
        .config/Code/User/settings.json) printf '%s\n' "$TEST_ROOT/original-settings" ;;
        *) return 1 ;;
    esac
}
juno_stage_terminal
[[ ! -e $TEST_ROOT/never-execute ]]
cmp -- "$HOME/.bashrc" "$TEST_ROOT/original-rc"
cmp -- "$HOME/.config/Code/User/settings.json" "$TEST_ROOT/original-settings"
cp -- "$TEST_ROOT/stage/bashrc" "$TEST_ROOT/staged-rc"
cp -- "$TEST_ROOT/stage/settings.json" "$TEST_ROOT/staged-settings"
juno_stage_terminal
cmp -- "$TEST_ROOT/stage/bashrc" "$TEST_ROOT/staged-rc"
cmp -- "$TEST_ROOT/stage/settings.json" "$TEST_ROOT/staged-settings"
# Concurrent live edits cannot change the merge input. Transaction backup owns
# refusing to apply this stale merge, while this helper preserves live files.
printf '# concurrent edit\n' >>"$HOME/.bashrc"
printf 'concurrent invalid JSONC\n' >"$HOME/.config/Code/User/settings.json"
juno_stage_terminal
cmp -- "$TEST_ROOT/stage/bashrc" "$TEST_ROOT/staged-rc"
cmp -- "$TEST_ROOT/stage/settings.json" "$TEST_ROOT/staged-settings"
[[ $(cat "$HOME/.config/Code/User/settings.json") == 'concurrent invalid JSONC' ]]
grep -q '^# concurrent edit$' "$HOME/.bashrc"
# A baseline captured from invalid JSONC must fail before replacing staging.
printf 'invalid JSONC\n' >"$HOME/.config/Code/User/settings.json"
cp -- "$HOME/.config/Code/User/settings.json" "$TEST_ROOT/original-settings"
if juno_stage_terminal; then
    printf 'FALHOU: staging aceitou JSONC inválido.\n' >&2
    exit 1
fi
[[ $(cat "$HOME/.config/Code/User/settings.json") == 'invalid JSONC' ]]
cmp -- "$TEST_ROOT/stage/settings.json" "$TEST_ROOT/staged-settings"
printf 'Bash: guardas interativas, subshell, init único e fallback validados.\n'
printf 'Staging terminal: preservação, ausência de execução, idempotência e JSONC inválido validados.\n'
