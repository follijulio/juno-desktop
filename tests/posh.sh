#!/usr/bin/env bash
set -euo pipefail

TEST_REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/juno-posh-tests.XXXXXXXX")
TEST_ROOT=$(realpath -e -- "$TEST_ROOT")
trap '[[ -n "$TEST_ROOT" && "$TEST_ROOT" != / && "${TEST_ROOT##*/}" == juno-posh-tests.* ]] && rm -rf -- "$TEST_ROOT"' EXIT
mkdir -- "$TEST_ROOT/mock-bin"
cat >"$TEST_ROOT/mock-bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
output=''
while (($#)); do
    case $1 in
        --output) output=$2; shift 2;;
        --) shift; break;;
        *) shift;;
    esac
done
[[ -n $output && $# == 1 ]] || exit 64
printf '%s\n' "$1" >>"$TEST_CURL_LOG"
case $1 in
    https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/releases/latest)
        [[ ${TEST_OFFLINE:-0} == 0 ]] || exit 6
        cp -- "$TEST_METADATA" "$output";;
    https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/*/posh-linux-amd64)
        [[ ${TEST_BINARY_FAIL:-0} == 0 ]] || exit 22
        cp -- "$TEST_BINARY" "$output";;
    *) exit 65;;
esac
MOCK
chmod +x -- "$TEST_ROOT/mock-bin/curl"
export PATH="$TEST_ROOT/mock-bin:$TEST_REPO/.cache/qa/bin:$PATH"
source "$TEST_REPO/lib/common.sh"
source "$TEST_REPO/lib/transaction.sh"
source "$TEST_REPO/lib/posh.sh"

# Exercise the production architecture guard without executing a Linux binary.
for format in amd64 arm64 elf32 bad-magic truncated shared; do
    python3 - "$TEST_ROOT/$format" "$format" <<'PY'
from pathlib import Path
import sys

header = bytearray(64)
header[:7] = b'\x7fELF\x02\x01\x01'
header[16:18] = (3 if sys.argv[2] == 'shared' else 2).to_bytes(2, 'little')
header[18:20] = (183 if sys.argv[2] == 'arm64' else 62).to_bytes(2, 'little')
header[20:24] = (1).to_bytes(4, 'little')
if sys.argv[2] == 'elf32':
    header[4] = 1
elif sys.argv[2] == 'bad-magic':
    header[0] = 0
elif sys.argv[2] == 'truncated':
    header = header[:20]
Path(sys.argv[1]).write_bytes(header)
PY
    if [[ $format == amd64 || $format == shared ]]; then
        _posh_architecture "$TEST_ROOT/$format"
    elif _posh_architecture "$TEST_ROOT/$format"; then
        printf 'FALHOU: arquitetura inválida aceita: %s\n' "$format" >&2
        exit 1
    fi
done
# Download fixtures are scripts on both Windows and Linux; only their ELF check
# is mocked below. SHA-256, version and metadata checks remain the real code.
_posh_architecture() { [[ -f $1 ]]; }

if [[ $(uname -s) == MINGW* || $(uname -s) == MSYS* ]]; then
    TEST_REAL_JQ=$(command -v jq)
    jq() {
        local argument
        local -a arguments=()
        for argument in "$@"; do
            if [[ $argument == /* && -d $(dirname -- "$argument") ]]; then argument=$(cygpath -m -- "$argument"); fi
            arguments+=("$argument")
        done
        MSYS2_ARG_CONV_EXCL='*' "$TEST_REAL_JQ" "${arguments[@]}"
    }
fi
TEST_NATIVE_LINKS=1
mkdir -- "$TEST_ROOT/link-target"
if MSYS=winsymlinks:nativestrict ln -s link-target "$TEST_ROOT/link-probe" 2>/dev/null && [[ -L $TEST_ROOT/link-probe ]]; then
    export MSYS=winsymlinks:nativestrict
else
    TEST_NATIVE_LINKS=0
    _posh_activate() { printf '%s\n' "$3" >"$1/.mock-current"; }
    printf 'AVISO: ativação por symlink simulada; validar no Arch.\n'
fi

fail() { printf 'FALHOU: %s\n' "$*" >&2; return 1; }
fixture() {
    CASE_ROOT=$(mktemp -d "$TEST_ROOT/case.XXXXXXXX")
    mkdir -- "$CASE_ROOT/home O'Neil % cash\$"
    JUNO_HOME=$(realpath -e -- "$CASE_ROOT/home O'Neil % cash\$")
    JUNO_STATE="$JUNO_HOME/.local/state/juno-desktop"
    JUNO_LOCK_HELD=1
    TEST_VERSION=1.2.3
    TEST_BINARY="$CASE_ROOT/posh-linux-amd64"
    TEST_METADATA="$CASE_ROOT/metadata.json"
    TEST_CURL_LOG="$CASE_ROOT/downloads"
    TEST_OFFLINE=0 TEST_BINARY_FAIL=0
    export TEST_BINARY TEST_METADATA TEST_CURL_LOG TEST_OFFLINE TEST_BINARY_FAIL
    : >"$TEST_CURL_LOG"
    make_release
}
make_release() {
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" %q\n' "$TEST_VERSION" >"$TEST_BINARY"
    chmod +x -- "$TEST_BINARY"
    local checksum
    checksum=$(sha256sum -- "$TEST_BINARY"); checksum=${checksum%% *}
    jq -n --arg version "$TEST_VERSION" --arg digest "sha256:$checksum" \
        '{tag_name:("v"+$version),draft:false,prerelease:false,assets:[{name:"posh-linux-amd64",digest:$digest,browser_download_url:("https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/v"+$version+"/posh-linux-amd64")}]}' \
        >"$TEST_METADATA"
}
current_version() {
    local app="$JUNO_HOME/.local/share/juno-apps/oh-my-posh"
    if ((TEST_NATIVE_LINKS)); then readlink -- "$app/current"; else cat -- "$app/.mock-current"; fi
}

fixture
juno_install_posh
[[ $(current_version) == *v1.2.3 ]]
[[ -x $JUNO_HOME/.local/share/juno-apps/oh-my-posh/releases/v1.2.3/oh-my-posh ]]
[[ $(wc -l <"$TEST_CURL_LOG") == 2 ]]
juno_install_posh
[[ $(wc -l <"$TEST_CURL_LOG") == 3 ]] || fail 'reinstalação baixou binário desnecessariamente'

TEST_VERSION=1.2.4; make_release
printf 'corrupted\n' >>"$TEST_BINARY"
if juno_install_posh; then fail 'checksum incorreto aceito'; fi
[[ $(current_version) == *v1.2.3 ]] || fail 'checksum inválido trocou versão anterior'
make_release
TEST_BINARY_FAIL=1; export TEST_BINARY_FAIL
if juno_install_posh; then fail 'download com falha aceito'; fi
[[ $(current_version) == *v1.2.3 ]]
TEST_BINARY_FAIL=0; export TEST_BINARY_FAIL
juno_install_posh
[[ $(current_version) == *v1.2.4 ]]
[[ -d $JUNO_HOME/.local/share/juno-apps/oh-my-posh/releases/v1.2.3 ]]

printf 'modified\n' >>"$JUNO_HOME/.local/share/juno-apps/oh-my-posh/releases/v1.2.4/oh-my-posh"
if juno_install_posh; then fail 'release instalada adulterada aceita'; fi

fixture
juno_install_posh
TEST_VERSION=1.2.4; make_release
printf '#!/usr/bin/env bash\nprintf "1.2.9\\n"\n' >"$TEST_BINARY"
checksum=$(sha256sum -- "$TEST_BINARY"); checksum=${checksum%% *}
jq --arg digest "sha256:$checksum" '.assets[0].digest=$digest' "$TEST_METADATA" >"$TEST_METADATA.tmp"
mv -- "$TEST_METADATA.tmp" "$TEST_METADATA"
if juno_install_posh; then fail 'versão divergente aceita'; fi
[[ $(current_version) == *v1.2.3 ]] || fail 'versão divergente substituiu a instalação anterior'

for filter in '.draft=true' '.prerelease=true' '.assets[0].digest=""' \
    '.assets[0].browser_download_url="https://example.com/posh"' \
    '.assets += [.assets[0]]' '.tag_name="../../escape"'; do
    fixture
    jq "$filter" "$TEST_METADATA" >"$TEST_METADATA.tmp"
    mv -- "$TEST_METADATA.tmp" "$TEST_METADATA"
    if juno_install_posh; then fail "metadados inválidos aceitos: $filter"; fi
    [[ $(wc -l <"$TEST_CURL_LOG") == 1 ]] || fail 'baixou binário com metadados inválidos'
done
fixture
TEST_OFFLINE=1; export TEST_OFFLINE
if juno_install_posh; then fail 'falha de rede ignorada'; fi
printf 'Oh My Posh: download, SHA-256, identidade, atualização, retenção e idempotência validados.\n'
