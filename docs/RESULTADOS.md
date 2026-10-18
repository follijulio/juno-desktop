# Resultados de validação — 18/10/2026

Ambiente desta revisão: Windows, PowerShell, Git Bash 5.3.15, Python 3.15, Node.js, jq 1.8.2 e ShellCheck 0.11.0. A inspeção posterior acessou uma VM Arch/GNOME pelo VirtualBox. Nenhum pacote Linux foi instalado neste Windows.

## Baseline e correções

O registro anterior informava 32 arquivos Bash, 9 testes Python de marca, 18 cenários de transação, 14 de multilib e 5 de aplicativos aprovados na baseline. Esses resultados históricos não certificam a implementação GNOME.

O PNG distribuído e o gerado tinham pixels idênticos, mas bytes IDAT diferentes por causa da compressão zlib. A reprodução passou a comparar estrutura e pixels PNG e conteúdo SVG, preservando os assets e seus checksums.

O empacotamento prepara e valida arquivo e SHA-256 em temporários, recusa links simbólicos antes dos filtros e preserva a distribuição anterior diante de falhas cobertas pelos testes. Executáveis recebem modo POSIX e textos usam LF.

A revisão também corrigiu a leitura indevida de caches Python como texto pelo verificador de identidade e a corrupção de acentos em README e documentação. A arquitetura e o roteiro de aceitação descrevem o perfil GNOME real, sem prometer alterações de teclado, tema ou suspensão que o instalador não aplica.

## Verificações portáteis no Windows

| Comando/verificação | Resultado |
| --- | --- |
| `python -B tools/check_brand.py` | Aprovado |
| `python -B tools/generate_wallpaper.py --check` | Aprovado; estrutura/pixels PNG e SVG conferidos, sem regravar assets |
| `python -B tools/catalog_wallpapers.py --check` | Aprovado; 32 arquivos e 31 imagens únicas |
| `python -B -m unittest discover -s tests -p '*_test.py'` | 37 cenários: 35 aprovados e 2 ignorados por indisponibilidade de symlinks no Windows |
| Testes de tooling | Compressão alternativa, corrupção/truncamento PNG, pixels alterados, LF/permissões, pacote reproduzível, falhas de leitura/validação/publicação e exclusão de metadados |
| Testes de marca | Paleta/fontes, recursos vendorizados, PNG inválido e presença de cache Python sem ocultar erros reais |
| `bash tests/run.sh` | Aprovado, incluindo sintaxe Bash, ShellCheck, recursos, testes Python e suites de instalação/sessão |
| Instalador e integração | 10 + 3 cenários aprovados; simulação sem gravação, recuperação v1 antes de falha de rede e aplicação completa após recusa do Spotify |
| Transações de arquivos e GNOME | 18 + 9 cenários aprovados; 6 casos de links POSIX ignorados no Windows |
| GNOME | 13 cenários de GDM/logind aprovados; 11 testes Python do helper incluídos nos 37 acima |
| Oh My Posh, Bash e VS Code JSONC | Download, SHA-256, seis fixtures ELF, versão divergente, atualização, retenção, init único, fallback, staging e preservação de comentários/perfis aprovados |
| Multilib e aplicativos | 14 + 10 cenários aprovados; cancelamento/falha do Spotify não bloqueia o perfil, origem insegura continua recusada e falha do VS Code continua obrigatória; links reais não cobertos no Windows |
| Instalador VS Code original | 14 cenários aprovados; 1 cenário de ancestral com symlink ignorado no Windows |
| Regressões dos scripts legados | 18 cenários de runtime, 5 de sessão e 19 de wallpaper/bloqueio aprovados; links reais não cobertos no Windows |

A revisão confirmou instalação nova com arquivos individuais, backup/restauração v2, recuperação parcial de preferências, recusa de diário truncado e preservação de edições concorrentes. O merge Bash/JSONC usa inputs congelados e os confere antes do backup e da aplicação. Os testes históricos Hyprland são mantidos como regressão dos arquivos preservados e não apresentados como homologação do GNOME.

## Testes na VM Arch/GNOME

A VM `JUNO`, no VirtualBox 7.2.20, usa o disco `D:\VMS\JUNO\JUNO.vdi`; `D:\testejuno.vdi` é outro disco cadastrado e não estava conectado a ela. A tela da sessão conferia com o relato do usuário: GNOME em Wayland. O console confirmou Arch x86_64, kernel 7.2.11, raiz ext4 em `/dev/sda2`, GNOME Shell 51.1, GDM 51.1 e rede NAT conectada.

O log da instalação anterior mostrou GNOME Shell 51.1 e a causa da configuração ausente: a recusa do runtime Flatpak do Spotify abortou a execução antes de instalar VS Code/Oh My Posh e aplicar os arquivos e preferências. A correção torna essa etapa opcional, mantém a verificação da origem e avisa novamente ao final. A regressão integrada usa a transação real para conferir que arquivos e preferências são aplicados e o diário é finalizado após essa falha.

Após a VM deixar de responder durante a tentativa de snapshot ao vivo, ela foi desligada e recebeu um snapshot offline antes da reinstalação. Para reduzir a pressão de memória no host, os testes seguintes usaram 4 GiB de RAM e 2 CPUs, com boot pelo disco.

| Comando/verificação real | Resultado |
| --- | --- |
| `bash install.sh --dry-run` | Aprovado; comparação por hash confirmou arquivos gerenciados e estado do instalador sem alterações |
| `bash install.sh` pelo TTY | Aprovado, saída 0; recusar o runtime do Spotify gerou aviso e permitiu concluir a configuração |
| Downloads oficiais | VS Code 1.142.0 e Oh My Posh 31.8.0 instalados após as verificações de integridade e versão |
| Aplicação do perfil | Arquivos e seis preferências GNOME aplicados, fontes validadas e backup v2 criado |
| Gerenciador de login | GDM existente e `graphical.target` preservados; o instalador não iniciou nem reiniciou serviços de login |
| `bash tests/native.sh` | Aprovado, saída 0; schemas e fontes reais conferidos, sintaxe/ShellCheck e suite completa executados no Linux |
| Casos indisponíveis no Windows | 37 testes Python aprovados sem casos ignorados; 24 cenários de transação de arquivos, 15 de VS Code e 21 de wallpaper aprovados, incluindo links POSIX |
| Demais suites no Linux | Instalador 9, integração 3, transações GNOME 9, GDM/logind 12, multilib 14, aplicativos 10, runtime 18 e sessão 5; Oh My Posh e Bash/JSONC aprovados |
| Estado instalado | Leitura real das seis preferências pelo helper aprovada; `fc-match` resolveu Roboto, Space Mono, JetBrains Mono e JetBrainsMono Nerd Font Mono corretamente |
| Fontes e preferências do VS Code | Arquivos de fontes resolvidos existem nos destinos finais, sem dependência do staging; editor usa JetBrains Mono, terminal usa Nerd Font Mono e perfil Juno Bash aponta para `/usr/bin/bash` |
| Prompt | Versão real do Oh My Posh conferida; hook testado em Bash isolado com inicialização única e somente um bloco no `.bashrc` |
| Reinstalação completa | Aprovada, saída 0; bytes e modos dos arquivos gerenciados e quantidade de backups permaneceram iguais, sem diário pendente |
| Login gráfico | Autenticação no GDM e entrada no GNOME Wayland aprovadas; wallpaper Ghibli visível após login |
| Kitty e terminal integrado | Aplicativos abertos na sessão GNOME; Kitty exibiu diretório e branch Git. Bash/Oh My Posh nos dois terminais exibiu indicação vermelha `[1]` após executar `false` |
| Sessão aberta em outro TTY | Aplicação recusada com a sessão GNOME real ainda aberta; logout gráfico concluído antes dos testes de restauração |
| `bash install.sh --rollback ID` e reaplicação | Aprovados, saída 0; presença, conteúdo e modos originais dos arquivos e seis valores GNOME restaurados, incluindo ausência explícita/null. O estado substituído recebeu backup; a reinstalação recuperou exatamente o perfil gerenciado |
| Concorrência real de `flock` | Segundo processo recusado enquanto o primeiro mantinha o bloqueio; aquisição permitida após sua liberação |
| Interrupção e recuperação reais | Processo encerrado com SIGKILL após gravar arquivo e preferências dconf; diário persistiu. Novo processo restaurou SHA-256/modos dos arquivos e seis valores GNOME, removeu o marcador de teste e finalizou o diário |

As suites mantêm seus serviços, downloads, backend GNOME, `flock` e `sync` simulados mesmo quando executadas no Linux. Os testes separados de instalação, restauração e recuperação acima usaram pacman, downloads oficiais, dconf, `flock` e `sync` reais. O teste GDM/logind omitiu o caso de ausência de sessão por depender dos processos reais em `/proc`; a detecção de sessão inativa em outro TTY foi testada com logind simulado, além da recusa com uma sessão GNOME real aberta.

## Pendente no ambiente nativo

Ainda não foram certificados bloqueio/desbloqueio, suspensão, portais, capturas, áudio, AVIF, jogos ou hardware físico. Esta VM já tinha GNOME e os pacotes principais; não representa uma instalação limpa nem uma migração de sessão Hyprland ativa.

Complete os casos restantes [do roteiro de aceitação](VALIDACAO.md) no ambiente alvo. Os resultados acima cobrem somente as operações efetivamente executadas; os demais casos não devem ser considerados aprovados por consequência.
