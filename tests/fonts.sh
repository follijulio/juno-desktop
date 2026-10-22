#!/usr/bin/env bash
# Real local checksums; fc-scan is mocked in portable tests, checked on Linux separately.
# shellcheck disable=SC2329
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
source "$ROOT/lib/common.sh"
source "$ROOT/lib/fonts.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
JUNO_ROOT=$ROOT
JUNO_PLATFORM=arch
txn_stage_for() { [[ $1 == .local/share/fonts/juno ]] && printf '%s\n' "$TEST_ROOT/stage"; }
fc-scan() { printf '%s\n' 'JetBrainsMono Nerd Font Mono'; }
juno_stage_fonts
[[ ! -e $TEST_ROOT/stage ]]
printf 'OK: Arch mantém as Nerd Fonts do pacote oficial.\n'
JUNO_PLATFORM=zorin
mkdir "$TEST_ROOT/stage"
printf 'existing space font\n' > "$TEST_ROOT/stage/SpaceMono-Regular.ttf"
juno_stage_fonts
for style in Regular Bold Italic BoldItalic; do
    cmp -- "$ROOT/assets/fonts/jetbrainsmono-nerd/JetBrainsMonoNerdFontMono-$style.ttf" "$TEST_ROOT/stage/JetBrainsMonoNerdFontMono-$style.ttf"
done
[[ $(cat "$TEST_ROOT/stage/SpaceMono-Regular.ttf") == 'existing space font' ]]
cmp -- "$ROOT/assets/fonts/jetbrainsmono-nerd/OFL.txt" "$TEST_ROOT/stage/JetBrainsMonoNerdFont-OFL.txt"
juno_stage_fonts
[[ $(find "$TEST_ROOT/stage" -name 'JetBrainsMonoNerdFontMono-*.ttf' | wc -l) == 4 ]]
printf 'OK: Zorin prepara quatro variantes verificadas e licença, sem duplicação.\n'
mkdir -p "$TEST_ROOT/corrupt/assets/fonts"
cp -R -- "$ROOT/assets/fonts/jetbrainsmono-nerd" "$TEST_ROOT/corrupt/assets/fonts/"
printf 'corruption\n' >> "$TEST_ROOT/corrupt/assets/fonts/jetbrainsmono-nerd/JetBrainsMonoNerdFontMono-Regular.ttf"
JUNO_ROOT="$TEST_ROOT/corrupt"
if (juno_stage_fonts) >"$TEST_ROOT/error" 2>&1; then exit 1; fi
grep -q 'integridade' "$TEST_ROOT/error"
cmp -- "$ROOT/assets/fonts/jetbrainsmono-nerd/JetBrainsMonoNerdFontMono-Regular.ttf" "$TEST_ROOT/stage/JetBrainsMonoNerdFontMono-Regular.ttf"
printf 'OK: fonte corrompida recusada antes de substituir o staging.\n'
JUNO_ROOT=$ROOT
fc-scan() { printf '%s\n' 'Wrong font'; }
if (juno_stage_fonts) >"$TEST_ROOT/error" 2>&1; then exit 1; fi
grep -q 'Família incorreta' "$TEST_ROOT/error"
printf 'OK: família inesperada recusada.\n'

JUNO_HOME="$TEST_ROOT/cache home"
font_dir="$JUNO_HOME/.local/share/fonts/juno"
mkdir -p -- "$font_dir"
cache_calls=0
cache_args=()
fc-cache() { cache_calls=$((cache_calls + 1)); cache_args=("$@"); }
juno_refresh_font_cache
[[ $cache_calls == 1 && ${#cache_args[@]} == 3 && ${cache_args[0]} == -f && ${cache_args[1]} == -- && ${cache_args[2]} == "$font_dir" ]]
printf 'OK: reconstrução forçada limitada às fontes gerenciadas, preservando caches do sistema.\n'
rmdir -- "$font_dir"
juno_refresh_font_cache
[[ $cache_calls == 2 && ${#cache_args[@]} == 0 ]]
printf 'OK: ausência do diretório após rollback usa descoberta incremental.\n'
