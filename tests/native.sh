#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
[[ $(uname -s) == Linux ]] || { printf 'Execute no Arch Linux ou Zorin OS 18 com GNOME.\n' >&2; exit 1; }
(( EUID != 0 )) || { printf 'Execute como usuário comum.\n' >&2; exit 1; }
# Check the installed GNOME schemas/fonts without changing user preferences.
source "$ROOT/install.sh"
juno_preflight_base
juno_validate_gnome
juno_validate_installed_fonts
bash "$ROOT/tests/run.sh"
printf 'Schemas GNOME e fontes conferidos. Complete a aceitação gráfica em docs/VALIDACAO.md.\n'
