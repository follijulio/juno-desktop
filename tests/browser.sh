#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
source "$ROOT/lib/common.sh"
source "$ROOT/lib/applications.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
JUNO_HOME="$TEST_ROOT/home"
JUNO_STATE="$JUNO_HOME/.local/state/juno-desktop"
JUNO_PLATFORM=zorin
mkdir -p "$JUNO_STATE" "$JUNO_HOME/.local/share/flatpak/exports/share/applications"
CALLS="$TEST_ROOT/calls"
: > "$CALLS"
BRAVE=1 DEFAULT_DESKTOP=org.mozilla.firefox.desktop EXTRA_REMOVE=0 FAIL_INSTALL=0 HAS_FIREFOX=0
BROWSER_DESKTOP=org.mozilla.firefox.desktop ARCH_BRAVE=1
juno_browser_desktop() { printf '%s\n' "$BROWSER_DESKTOP"; }
juno_require() { :; }
juno_check_flathub() { return 0; }
flatpak() {
    printf 'flatpak %s\n' "$*" >> "$CALLS"
    if [[ $1 == info ]]; then
        [[ $HAS_FIREFOX == 1 ]] || return 1
        [[ $* != *--show-commit* ]] || printf '%064d\n' 1
    elif [[ $1 == install ]]; then
        [[ $FAIL_INSTALL == 0 ]] || return 1
        HAS_FIREFOX=1
        printf '[Desktop Entry]\nType=Application\nName=Firefox\n' > "$JUNO_HOME/.local/share/flatpak/exports/share/applications/org.mozilla.firefox.desktop"
    fi
}
xdg-mime() { printf '%s\n' "$DEFAULT_DESKTOP"; }
dpkg-query() { [[ $BRAVE == 1 ]] && printf installed || printf 'config-files'; }
# sudo is a shell mock in this fixture, including its pacman branch.
# shellcheck disable=SC2032
pacman() { [[ $ARCH_BRAVE == 1 && $* == '-Q -- brave-bin' ]]; }
sudo() {
    printf 'sudo %s\n' "$*" >> "$CALLS"
    if [[ $1 == pacman ]]; then
        [[ $* == 'pacman -R -- brave-bin' ]] || return 1
        ARCH_BRAVE=0
        return 0
    fi
    [[ $1 == apt-get ]] || return 1
    if [[ $* == *--simulate* ]]; then
        printf 'Remv brave-browser [1]\n'
        [[ $EXTRA_REMOVE == 0 ]] || printf 'Remv zorin-os-desktop [1]\n'
    else
        [[ $* == *--no-auto-remove* && $* != *purge* ]] || return 1
        BRAVE=0
    fi
}
FAIL_INSTALL=1
if (juno_configure_zorin_browser) > "$TEST_ROOT/error" 2>&1; then exit 1; fi
[[ $BRAVE == 1 && ! -s $JUNO_STATE/browser/firefox.commit ]]
if grep -q '^sudo ' "$CALLS"; then exit 1; fi
FAIL_INSTALL=0
juno_configure_zorin_browser
[[ -s $JUNO_STATE/browser/firefox.commit && $BRAVE == 1 ]]
DEFAULT_DESKTOP=other.desktop
if (juno_finalize_browser) > "$TEST_ROOT/error" 2>&1; then exit 1; fi
if grep -q '^sudo ' "$CALLS"; then exit 1; fi
DEFAULT_DESKTOP=org.mozilla.firefox.desktop EXTRA_REMOVE=1
if (juno_finalize_browser) > "$TEST_ROOT/error" 2>&1; then exit 1; fi
if grep -q '^sudo apt-get remove ' "$CALLS"; then exit 1; fi
EXTRA_REMOVE=0
juno_finalize_browser
[[ $BRAVE == 0 ]]
count=$(wc -l < "$CALLS")
juno_finalize_browser
[[ $(wc -l < "$CALLS") == "$count" ]]
BROWSER_DESKTOP=firefox.desktop
count=$(wc -l < "$CALLS")
juno_configure_zorin_browser
[[ $(wc -l < "$CALLS") == "$count" ]]
JUNO_PLATFORM=arch DEFAULT_DESKTOP=firefox.desktop
juno_finalize_browser
[[ $ARCH_BRAVE == 0 ]]
grep -q '^sudo pacman -R -- brave-bin$' "$CALLS"
printf 'Firefox: instalação verificada, falhas preservam Brave, remoção adicional recusada e reinstalação estável.\n'
