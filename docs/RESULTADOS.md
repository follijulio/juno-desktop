# Resultados de validação — 15/10/2026

Ambiente: Windows, Git Bash 5.3.15, Python 3.14.5, ShellCheck 0.11.0 e jq 1.8.2. Ferramentas auxiliares de QA estão em `.cache/`, fora da distribuição; a sessão instalada não depende delas.

## Executado

| Verificação | Resultado |
| --- | --- |
| Sintaxe Bash de instalador, bibliotecas, scripts e testes | Aprovada |
| ShellCheck de todos os arquivos Bash | Aprovado, sem diagnósticos |
| Conformidade de paleta, fontes, raios, opacidade e sombras | Aprovada |
| Fontes originais, licenças, revisão e checksums | Aprovados |
| Reprodução exata do PNG/SVG pelo gerador | Aprovada |
| Testes de marca e corrupção de recursos | 9 passaram |
| Testes de instalador e dependências | 9 passaram |
| Integração: simulação sem gravação e recuperação antes de falha de rede | 2 passaram |
| Transações: backup, aplicação, falhas, rollback e diário | 18 passaram; 6 casos dependentes de links POSIX foram ignorados |
| Scripts de captura, bloqueio, energia, áudio e brilho | 18 passaram |
| Derivação real de módulos Waybar e inicialização com serviços simulados | 5 passaram |
| Carregamento Lua com Fengari 0.1.0 e API simulada | Aprovado |
| Distribuição: arquivos, checksum, modos executáveis e finais de linha | Aprovada |

Total: **61 cenários automatizados aprovados**, além das verificações de sintaxe, identidade, Lua e distribuição. Os testes incluem caminhos com espaços, cancelamento, comandos injetados como texto, falhas de pacman, recursos corrompidos, falhas de renomeação, recuperação ambígua e preservação de edições em restaurações.

Comando agregado usado:

```bash
bash tests/run.sh
```

O teste Lua carrega todos os módulos, confere atalhos e argumentos com aspas e confirma que carregar a configuração não dispara autostart. Ele usa uma API simulada e não equivale ao parser real do Hyprland.

## Pendente de ambiente nativo

Não há WSL, Hyprland ou sessão Arch neste computador. **Não foram executados** o parser real do compositor, os parsers gráficos de GTK/Rofi/Mako/Kitty, concorrência real de `flock`, persistência real de `sync -f`, os seis casos de links POSIX ou aceitação com hardware.

Os comandos `flock` e `sync` são simulados nos testes de transação. Processos gráficos, PAM, D-Bus e serviços systemd são simulados nos testes de runtime. Portanto, os resultados locais não certificam bloqueio, áudio, portais ou aparência em uma sessão real.

Execute `bash tests/native.sh` no Arch e complete [o roteiro de aceitação](VALIDACAO.md) antes de considerar a sessão homologada. Nenhum pacote Linux foi instalado neste Windows, e nenhum dos outros projetos do workspace foi modificado.
