#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd -- "$ROOT"
export PYTHONDONTWRITEBYTECODE=1
while IFS= read -r -d '' file; do
    bash -n "$file"
done < <(find install.sh lib tests config/juno config/juno-gnome -type f \( -name '*.sh' -o -path '*/bin/*' \) -print0)
if command -v shellcheck >/dev/null 2>&1; then
    mapfile -d '' -t scripts < <(find install.sh lib tests config/juno config/juno-gnome -type f \( -name '*.sh' -o -path '*/bin/*' \) -print0)
    shellcheck -x "${scripts[@]}"
else
    printf 'AVISO: ShellCheck ausente no PATH; execute-o antes de publicar.\n' >&2
fi
python3 tools/check_brand.py
python3 tools/generate_wallpaper.py --check
python3 tools/catalog_wallpapers.py --check
python3 tools/generate_icons.py --check
python3 tools/check_icons.py
python3 -m unittest discover -s tests -p '*_test.py'
bash tests/installer.sh
bash tests/integration.sh
bash tests/transaction.sh
bash tests/transaction_gnome.sh
bash tests/gnome.sh
bash tests/posh.sh
bash tests/shell.sh
# Preserve regression coverage for the legacy scripts kept for old sessions.
bash tests/runtime.sh
bash tests/session.sh
bash tests/multilib.sh
bash tests/applications.sh
bash tests/vscode.sh
bash tests/wallpaper.sh
printf 'Verificações locais concluídas. A sessão gráfica exige aceitação nativa no Arch.\n'
