#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd -- "$ROOT"
while IFS= read -r -d '' file; do
    bash -n "$file"
done < <(find install.sh lib tests config/juno -type f \( -name '*.sh' -o -path '*/bin/*' \) -print0)
if command -v shellcheck >/dev/null 2>&1; then
    mapfile -d '' -t scripts < <(find install.sh lib tests config/juno -type f \( -name '*.sh' -o -path '*/bin/*' \) -print0)
    shellcheck -x "${scripts[@]}"
else
    printf 'AVISO: ShellCheck ausente no PATH; execute-o antes de publicar.\n' >&2
fi
python3 tools/check_brand.py
python3 tools/generate_wallpaper.py --check
python3 -m unittest discover -s tests -p '*_test.py'
if command -v lua >/dev/null 2>&1; then
    lua tests/config.lua "$ROOT"
elif command -v fengari >/dev/null 2>&1; then
    fengari tests/config.lua "$ROOT"
else
    printf 'AVISO: Lua/Fengari ausente; smoke test Lua não executado. O parser nativo continua obrigatório.\n' >&2
fi
bash tests/installer.sh
bash tests/integration.sh
bash tests/transaction.sh
bash tests/runtime.sh
bash tests/session.sh
printf 'Verificações locais concluídas. A sessão gráfica exige aceitação nativa no Arch.\n'
