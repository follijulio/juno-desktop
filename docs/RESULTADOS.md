# Resultados de validação — 18/10/2026

Ambiente desta revisão: Windows, PowerShell, Git Bash 5.3.15, Python 3.15, Node.js, jq 1.8.2 e ShellCheck 0.11.0. Não há sessão GNOME/Arch disponível. Nenhum pacote Linux foi instalado neste Windows.

## Baseline e correções

O registro anterior informava 32 arquivos Bash, 9 testes Python de marca, 18 cenários de transação, 14 de multilib e 5 de aplicativos aprovados na baseline. Esses resultados históricos não certificam a implementação GNOME.

O PNG distribuído e o gerado tinham pixels idênticos, mas bytes IDAT diferentes por causa da compressão zlib. A reprodução passou a comparar estrutura e pixels PNG e conteúdo SVG, preservando os assets e seus checksums.

O empacotamento prepara e valida arquivo e SHA-256 em temporários, recusa links simbólicos antes dos filtros e preserva a distribuição anterior diante de falhas cobertas pelos testes. Executáveis recebem modo POSIX e textos usam LF.

A revisão também corrigiu a leitura indevida de caches Python como texto pelo verificador de identidade e a corrupção de acentos em README e documentação. A arquitetura e o roteiro de aceitação descrevem o perfil GNOME real, sem prometer alterações de teclado, tema ou suspensão que o instalador não aplica.

## Executado nesta revisão

| Comando/verificação | Resultado |
| --- | --- |
| `python -B tools/check_brand.py` | Aprovado |
| `python -B tools/generate_wallpaper.py --check` | Aprovado; estrutura/pixels PNG e SVG conferidos, sem regravar assets |
| `python -B tools/catalog_wallpapers.py --check` | Aprovado; 32 arquivos e 31 imagens únicas |
| `python -B -m unittest discover -s tests -p '*_test.py'` | 37 cenários: 35 aprovados e 2 ignorados por indisponibilidade de symlinks no Windows |
| Testes de tooling | Compressão alternativa, corrupção/truncamento PNG, pixels alterados, LF/permissões, pacote reproduzível, falhas de leitura/validação/publicação e exclusão de metadados |
| Testes de marca | Paleta/fontes, recursos vendorizados, PNG inválido e presença de cache Python sem ocultar erros reais |
| `bash tests/run.sh` | Aprovado, incluindo sintaxe Bash, ShellCheck, recursos, testes Python e suites de instalação/sessão |
| Instalador e integração | 10 + 2 cenários aprovados; simulação sem gravação e recuperação v1 antes de falha de rede |
| Transações de arquivos e GNOME | 18 + 9 cenários aprovados; 6 casos de links POSIX ignorados no Windows |
| GNOME | 13 cenários de GDM/logind aprovados; 11 testes Python do helper incluídos nos 37 acima |
| Oh My Posh, Bash e VS Code JSONC | Download, SHA-256, seis fixtures ELF, versão divergente, atualização, retenção, init único, fallback, staging e preservação de comentários/perfis aprovados |
| Multilib e aplicativos | 14 + 5 cenários aprovados; links reais continuam pendentes no Linux |
| Instalador VS Code original | 14 cenários aprovados; 1 cenário de ancestral com symlink pendente no Linux |
| Regressões dos scripts legados | 18 cenários de runtime, 5 de sessão e 19 de wallpaper/bloqueio aprovados; verificações de links reais pendentes |

A revisão confirmou instalação nova com arquivos individuais, backup/restauração v2, recuperação parcial de preferências, recusa de diário truncado e preservação de edições concorrentes. O merge Bash/JSONC usa inputs congelados e os confere antes do backup e da aplicação. Os testes históricos Hyprland são mantidos como regressão dos arquivos preservados e não apresentados como homologação do GNOME.

## Pendente no ambiente nativo

Não foram executados GDM, GNOME Shell, PAM, systemd, portais, hardware, fontes reais do Kitty ou aceitação gráfica. Links POSIX, concorrência real de `flock` e persistência `sync -f` também exigem Linux.

Execute `bash tests/native.sh` no Arch e complete [o roteiro de aceitação](VALIDACAO.md). Downloads e comandos simulados não certificam aplicativos, jogos, capturas, bloqueio, áudio, imagem AVIF ou suspensão em uma sessão real.
