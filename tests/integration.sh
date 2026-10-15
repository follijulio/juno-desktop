#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export TEST_ROOT ROOT
mkdir -p "$TEST_ROOT/mock-bin"
if ! command -v flock >/dev/null 2>&1; then
    printf '#!/usr/bin/env bash\nexit 0\n' > "$TEST_ROOT/mock-bin/flock"
    chmod +x "$TEST_ROOT/mock-bin/flock"
fi
# sync -f does not support the Windows filesystem. Native durability has its own QA.
if [[ $(uname -s) != Linux ]]; then
    printf '#!/usr/bin/env bash\nexit 0\n' > "$TEST_ROOT/mock-bin/sync"
    chmod +x "$TEST_ROOT/mock-bin/sync"
fi
export PATH="$TEST_ROOT/mock-bin:$PATH"

cat > "$TEST_ROOT/harness.sh" <<'HARNESS'
#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/install.sh"
juno_preflight_base() {
    JUNO_HOME=$(realpath -e "$TEST_ROOT/home")
    JUNO_STATE="$JUNO_HOME/.local/state/juno-desktop"
}
juno_preflight_terminal() { :; }
juno_begin_log() { :; }
fc-cache() { :; }
juno_preflight_base
juno_define_targets
case "$1" in
    pending)
        txn_lock
        for target in "${JUNO_TARGETS[@]}"; do
            mkdir -p "$JUNO_HOME/$target"
            printf 'original\n' > "$JUNO_HOME/$target/original.txt"
        done
        txn_prepare
        txn_backup
        txn_apply
        # Exit without finalizing: simulates process loss after the directory swaps.
        ;;
    offline)
        juno_preflight_install() { printf 'offline simulado\n' >&2; return 23; }
        juno_main
        ;;
    dry)
        juno_preflight_install() { [[ $1 == readonly ]]; }
        juno_main --dry-run
        ;;
esac
HARNESS
mkdir "$TEST_ROOT/home"
bash "$TEST_ROOT/harness.sh" dry > "$TEST_ROOT/dry.log"
[[ -z $(find "$TEST_ROOT/home" -mindepth 1 -print -quit) ]] || { printf 'Simulação gravou arquivos.\n' >&2; exit 1; }
printf 'OK: dry-run integrado sem gravações\n'
bash "$TEST_ROOT/harness.sh" pending > "$TEST_ROOT/pending.log"
[[ -f "$TEST_ROOT/home/.local/state/juno-desktop/pending.tsv" ]]
if bash "$TEST_ROOT/harness.sh" offline > "$TEST_ROOT/offline.log" 2>&1; then
    printf 'Esperava falha de conexão.\n' >&2
    exit 1
fi
[[ ! -f "$TEST_ROOT/home/.local/state/juno-desktop/pending.tsv" ]]
grep -q 'Transação interrompida recuperada' "$TEST_ROOT/offline.log"
grep -q 'offline simulado' "$TEST_ROOT/offline.log"
for target in .config/hypr .config/waybar .config/rofi .config/mako .config/kitty .config/juno .config/xdg-desktop-portal .local/share/fonts/juno .local/share/juno-desktop; do
    [[ $(cat "$TEST_ROOT/home/$target/original.txt") == original ]]
done
printf 'OK: recuperação integrada ocorre antes de verificar rede\n'
printf '2 cenários de integração passaram.\n'
