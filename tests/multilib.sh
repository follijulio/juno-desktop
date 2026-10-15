#!/usr/bin/env bash
# Os mocks são chamados pelos módulos sob teste.
# shellcheck disable=SC2329,SC2032
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=../lib/multilib.sh
source "$ROOT/lib/multilib.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
passed=0
ok() { passed=$((passed + 1)); printf 'OK: %s\n' "$1"; }
expect_failure() {
    if ( "$@" ) > "$TEST_ROOT/error.log" 2>&1; then
        printf 'FALHOU: erro esperado em %s\n' "$*" >&2
        exit 1
    fi
}

cat > "$TEST_ROOT/original.conf" <<'CONFIG'
[options]
Architecture = auto
SigLevel = Required DatabaseOptional
[core]
Include = /etc/pacman.d/mirrorlist
#[multilib]
#Include = /etc/pacman.d/mirrorlist
[custom]
Server = https://example.invalid/$repo/os/$arch
CONFIG
juno_multilib_render "$TEST_ROOT/original.conf" "$TEST_ROOT/prepared.conf"
[[ $(awk '/^\[multilib\]$/ { count++ } END { print count+0 }' "$TEST_ROOT/prepared.conf") == 1 ]]
head -c "$(wc -c < "$TEST_ROOT/original.conf")" "$TEST_ROOT/prepared.conf" > "$TEST_ROOT/prefix.conf"
cmp "$TEST_ROOT/original.conf" "$TEST_ROOT/prefix.conf"
ok 'habilita apenas multilib e preserva opções, comentários e repositórios personalizados'

juno_multilib_render "$TEST_ROOT/prepared.conf" "$TEST_ROOT/second.conf"
cmp "$TEST_ROOT/prepared.conf" "$TEST_ROOT/second.conf"
ok 'transformação idempotente preserva o arquivo já habilitado'

printf '[core]\nInclude = /etc/pacman.d/mirrorlist' > "$TEST_ROOT/no-newline.conf"
juno_multilib_render "$TEST_ROOT/no-newline.conf" "$TEST_ROOT/newline.conf"
grep -qx '\[multilib\]' "$TEST_ROOT/newline.conf"
grep -qx 'Include = /etc/pacman.d/mirrorlist' "$TEST_ROOT/newline.conf"
ok 'arquivo sem quebra de linha final recebe seção separada corretamente'

printf '[multilib-testing]\nServer = https://example.invalid/testing\n' > "$TEST_ROOT/testing.conf"
juno_multilib_render "$TEST_ROOT/testing.conf" "$TEST_ROOT/with-testing.conf"
grep -qx '\[multilib-testing\]' "$TEST_ROOT/with-testing.conf"
grep -qx '\[multilib\]' "$TEST_ROOT/with-testing.conf"
[[ $(grep -c '^\[multilib-testing\]$' "$TEST_ROOT/with-testing.conf") == 1 ]]
ok 'multilib-testing existente permanece intacto e não substitui multilib'

printf ' [multilib] # personalizado\nServer = https://example.invalid/custom\n' > "$TEST_ROOT/custom-active.conf"
juno_multilib_render "$TEST_ROOT/custom-active.conf" "$TEST_ROOT/custom-copy.conf"
cmp "$TEST_ROOT/custom-active.conf" "$TEST_ROOT/custom-copy.conf"
ok 'seção ativa personalizada não recebe duplicata nem troca de servidores'

mkdir "$TEST_ROOT/com espacos"
juno_multilib_render "$TEST_ROOT/original.conf" "$TEST_ROOT/com espacos/prepared.conf"
cmp "$TEST_ROOT/prepared.conf" "$TEST_ROOT/com espacos/prepared.conf"
ok 'caminhos de staging com espaços são suportados'

expect_failure juno_multilib_render "$TEST_ROOT/original.conf" "$TEST_ROOT/original.conf"
cmp "$TEST_ROOT/original.conf" "$TEST_ROOT/prefix.conf"
ln -s "$TEST_ROOT/original.conf" "$TEST_ROOT/link.conf"
if [[ -L $TEST_ROOT/link.conf ]]; then
    expect_failure juno_multilib_render "$TEST_ROOT/link.conf" "$TEST_ROOT/from-link.conf"
    expect_failure juno_multilib_render "$TEST_ROOT/prepared.conf" "$TEST_ROOT/link.conf"
else
    printf 'SKIP: links simbólicos reais exigem Linux ou suporte a symlinks no Windows.\n'
fi
ok 'origem igual ao destino é rejeitada sem alterar a origem; links reais são verificados quando suportados'

pacman-conf() { printf 'core\nextra\nmultilib-testing\n'; }
expect_failure _juno_multilib_validate_stage "$TEST_ROOT/prepared.conf"
grep -q 'não habilita multilib' "$TEST_ROOT/error.log"
ok 'validador não aceita multilib-testing como falso positivo'

pacman-conf() {
    [[ $1 == --config && $2 == "$TEST_ROOT/prepared.conf" && $3 == --repo-list ]] || return 20
    printf 'core\nextra\nmultilib\n'
}
_juno_multilib_validate_stage "$TEST_ROOT/prepared.conf"
ok 'validação usa pacman-conf com o staging explícito'

pacman-conf() { return 27; }
expect_failure _juno_multilib_validate_stage "$TEST_ROOT/prepared.conf"
grep -q 'pacman-conf rejeitou' "$TEST_ROOT/error.log"
ok 'falha de parsing interrompe a habilitação'

pacman-conf() { printf 'core\nextra\nmultilib\n'; }
sudo() { printf 'sudo inesperado\n' >&2; return 30; }
juno_enable_multilib > "$TEST_ROOT/enabled.log"
grep -q 'já está ativo' "$TEST_ROOT/enabled.log"
ok 'repositório já ativo dispensa sudo, backup e substituição'

pacman-conf() { printf 'core\nextra\n'; }
juno_multilib_plan > "$TEST_ROOT/plan.log"
grep -q 'será criado um backup' "$TEST_ROOT/plan.log"
[[ ! -e $TEST_ROOT/.local ]]
ok 'simulação informa backup e atualização completa sem gravar estado'

JUNO_STATE="$TEST_ROOT/state"
mkdir -p "$JUNO_STATE/packages"
workdir=$(mktemp -d "$JUNO_STATE/packages/.multilib-stage.XXXXXXXX")
printf 'temporário\n' > "$workdir/pacman.conf"
_juno_multilib_cleanup "$workdir"
[[ ! -e $workdir ]]
ok 'limpeza remove somente o staging com nome validado'

mkdir "$JUNO_STATE/packages/preserve"
printf 'preservar\n' > "$JUNO_STATE/packages/preserve/original"
sudo() { printf '%s\n' "$*" >> "$TEST_ROOT/unexpected-sudo.log"; }
_juno_multilib_cleanup "$JUNO_STATE/packages/.multilib-stage.12345678/../preserve" '/etc/.juno-pacman.12345678/../../preserve' > "$TEST_ROOT/cleanup.log" 2>&1
[[ -f $JUNO_STATE/packages/preserve/original && ! -e $TEST_ROOT/unexpected-sudo.log ]]
ok 'limpeza rejeita caminhos com travessia e não executa sudo em destinos inesperados'
printf '%s cenários de multilib passaram.\n' "$passed"
