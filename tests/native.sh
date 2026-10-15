#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
[[ $(uname -s) == Linux && -f /etc/arch-release ]] || { printf 'Execute no Arch Linux.\n' >&2; exit 1; }
(( EUID != 0 )) || { printf 'Execute como usuário comum.\n' >&2; exit 1; }
command -v Hyprland >/dev/null
runtime=$(mktemp -d)
trap 'rm -rf -- "$runtime"' EXIT
chmod 700 "$runtime"
XDG_RUNTIME_DIR="$runtime" Hyprland --verify-config -c "$ROOT/config/hypr/hyprland.lua"
for file in "$ROOT"/assets/fonts/spacemono/*.ttf; do
    fc-scan --format '%{family}: %{style}\n' "$file"
done
bash "$ROOT/tests/run.sh"
printf 'Parser nativo aprovado. Complete a revisão gráfica descrita em docs/VALIDACAO.md.\n'
