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

## Ícones e versão Zorin — 21/10/2026

Esta revisão conclui o tema de ícones iniciado em 20/10 e acrescenta o perfil para Zorin OS 18.x Core/Pro, base Ubuntu 24.04, x86_64. Os resultados de 18/10 acima permanecem históricos: o perfil atual possui oito destinos e sete preferências GNOME. Não houve instalação do Zorin nesta máquina ou na VM Arch.

| Verificação executada | Resultado |
| --- | --- |
| Gerador e validador de ícones | 49 desenhos originais, 142 SVGs incluindo aliases; reprodução, SHA-256, índice, fallback e rejeição de conteúdo ativo conferidos |
| Testes Python | 49 casos: todos aprovados no Linux; no Windows, 47 aprovados e dois casos de symlink ignorados |
| Aplicação real dos ícones na VM Arch | Tema Juno e oitavo destino aplicados com backup; lançador Arch do VS Code passou a usar nome temático com PNG original em hicolor; nenhum pacote ou binário foi atualizado nesta etapa |
| GTK/GdkPixbuf reais | Todos os 142 nomes resolvidos em 32 e 64 px: 284 renderizações aprovadas; os 48 lançadores visíveis da VM resolveram SVGs Juno |
| Fallback real | Ação simbólica resolveu Adwaita; VS Code resolveu o PNG original ao selecionar Adwaita na consulta GTK |
| Aceitação visual | Login no GDM e grade/dock GNOME conferidos com os novos ícones; captura local da sessão arquivada entre os registros de QA |
| Rollback real de ícones | Backup novo restaurou a ausência original do tema e as sete preferências; backup antigo de seis chaves preservou `icon-theme`. Restauração de retorno conferiu hashes/modos dos oito destinos e os sete valores |
| Interrupção e concorrência reais | `flock` entre dois processos, SIGKILL após gravar arquivo e `icon-theme`, recuperação em novo processo e remoção do diário aprovados; arquivos e sete valores restaurados |
| Reaplicação real | Perfil sem alterações reconhecido sem novo backup; preferências anteriores da VM foram restauradas ao concluir os testes |
| `bash tests/native.sh` no Arch | Aprovado com os novos testes Zorin simulados, 49 casos Python sem ignorados, 24 transações de arquivos, 12 transações GNOME, 29 cenários VS Code e 21 de wallpaper |
| Isolamento da plataforma nos testes | Suíte completa repetida no Linux com `JUNO_PLATFORM=zorin` herdado: aprovada. Fixtures escolhem a plataforma sem depender da distribuição do host |
| Zorin: plataforma/APT/GDM | 17 cenários simulados aprovados: identificação sem executar `os-release`, rejeição de bases incompatíveis, instalação somente de dependências ausentes, falhas, inventários, dry-run e GDM3 sem início/reinício |
| Zorin: fontes e integração | Quatro cenários de fontes e cinco de integração aprovados; recursos corrompidos recusados, staging sem duplicação e perfil aplicado apesar da recusa dos aplicativos opcionais |
| Fontes oficiais locais | Arquivo Nerd Fonts 3.5.1 verificado pelo SHA-256 publicado; quatro TTFs, licença e metadados incluídos. Fontconfig real no Linux reconheceu as quatro variantes como JetBrainsMono Nerd Font Mono |
| Aplicativos e VS Code | 18 cenários de aplicativos e 29 de VS Code aprovados; instalações existentes preservadas, falhas SHA/identidade/arquitetura/APT e conflitos de lançadores cobertos. Links reais conferidos no Linux |
| Pacotes Zorin | Os 59 nomes APT existem nos índices oficiais Ubuntu Noble; listas oficiais Zorin 18.1 Core/Pro incluem os componentes mínimos GNOME/GDM exigidos |
| Pacote Microsoft real | Download oficial 1.143.0 verificado por SHA-256 e inspecionado sem instalar: pacote `code`, versão `1.143.0-1792533444`, amd64, ícone `vscode` coberto pelo tema e entrada nativa preservada |
| Compatibilidade de configuração | JSONC passou também no Node 18.19.1 oficial verificado. Opções Kitty conferidas com a definição oficial 0.32.2; removida `cursor_trail`, indisponível nessa versão |
| `bash tests/run.sh` no Windows, revisão final | Aprovado; sintaxe, ShellCheck, 49 casos Python (dois ignorados por links), recursos e todas as suites Bash concluídos |
| Pacote final | 298 arquivos, 201 checksums de recursos, LF e modos executáveis conferidos; geração repetida produziu o mesmo SHA-256 |
| Projeto na VM | 187 arquivos atualizados após comparar com a versão anterior; cópias substituídas preservadas, sem sobrescrever divergências desconhecidas |

APT, scripts de manutenção de pacotes, AppArmor, Flatpak, autenticação e login gráfico ainda exigem aceitação em Zorin real. Testes executados no Arch com chamadas APT simuladas não certificam esses componentes do Zorin. A inspeção do `.deb` não equivale à sua instalação. A VM continua sem representar instalação limpa ou migração Hyprland ativa; os limites de hardware e serviços registrados acima permanecem.

## Otimização do perfil Zorin — 22/10/2026

O perfil Zorin passa a selecionar 39 dependências essenciais; 20 ferramentas adicionais ficam disponíveis com `--with-dev-tools`. A seleção não remove ferramentas existentes. O inventário DPKG é consultado em lote por operação, incluindo pacotes retidos válidos, e atualizado após APT. A instalação dispensa recomendações opcionais, mantendo `xdg-utils` explícito para a integração do VS Code.

O Zorin gerencia agora oito preferências GNOME, com `enable-animations=false`; o Arch mantém sete. O snapshot GNOME v3 inclui essa preferência booleana, enquanto snapshots anteriores de seis/sete chaves conservam seu próprio escopo. O formato do manifesto de arquivos continua v2. O prompt compartilhado exibe diretório, branch e erro sem varredura de alterações Git; o segmento Git tem timeout de 200 ms. A atualização de fontes força somente o diretório gerenciado e usa descoberta incremental quando ele está ausente ou restaurado como link.

| Verificação executada nesta revisão | Resultado |
| --- | --- |
| Sintaxe Bash, ShellCheck e recursos | Aprovados; marca, PNG, galeria, gerador de ícones, SVGs e checksums conferidos |
| Testes Python | 55 casos: 53 aprovados e dois ignorados por indisponibilidade de links simbólicos nativos no Windows; 22 testes do helper GNOME incluídos nesse total |
| Plataforma/APT | 21 cenários simulados aprovados; seleção essencial/completa, ausência de remoções, inventário fresco, arquitetura/estado, pacotes retidos, falhas e GDM3 |
| CLI e integração | Sete cenários aprovados; `--with-dev-tools` combinado com dry-run, combinações inválidas recusadas antes do preflight e aplicações opcionais sem bloquear o perfil |
| Fontes | Seis cenários aprovados; quatro variantes verificadas, corrupção/família inválida recusadas, cache forçado limitado ao destino gerenciado e ausência após rollback |
| GNOME e transações | 14 cenários de planejamento/GDM e 15 de transações aprovados; animações true/false/null restauradas, reinstalação sem diferenças, backups antigos preservando animações e conflito concorrente mantido |
| Regressões | Todos os demais componentes de `tests/run.sh` executados em grupos independentes e aprovados, incluindo instalação, transações de arquivos, Posh, Bash/JSONC, multilib, aplicativos, VS Code e scripts legados. As limitações de links/serviços do Windows permanecem |
| Distribuição | Pacote com 298 arquivos e 201 checksums de recursos; LF/modos executáveis e repetição com SHA-256 idêntico conferidos |

### Medição local do prompt

O teste usou Windows, Git e o [Oh My Posh oficial 31.8.0](https://github.com/JanDeDobbeleer/oh-my-posh/releases/tag/v31.8.0), com versão e SHA-256 do executável conferidos. Um repositório temporário continha alterações e 5.000 arquivos não rastreados. O teste não carregou configurações do usuário. Após cinco aquecimentos por configuração, foram coletadas 30 renderizações alternadas de cada tema; o rastreamento Git ficou desligado durante a medição de tempo.

| Métrica local | Antes | Depois |
| --- | --- | --- |
| Chamadas `git status` por renderização, em verificação separada com Git Trace | 1 | 0 |
| Mediana | 192,554 ms | 80,503 ms |
| Percentil 95 | 339,433 ms | 120,605 ms |

Diretório, branch e indicação `[7]` foram conferidos na saída real. Renomear a branch atualizou imediatamente o prompt; o comportamento fora de repositórios e após comando bem-sucedido também passou. A evidência local permanece em `.cache/perf-qa/prompt-result-final.json`, junto do script e do tema anterior usados no teste.

Esses tempos medem somente o prompt nesse ambiente Windows. Não foram medidos consumo de RAM, tempo de boot, desempenho gráfico ou economia de energia em Zorin. Esta revisão não acessou uma instalação Zorin real; serviços, dconf e APT dos testes portáteis continuam simulados. Os resultados Linux registrados em 21/10 são históricos e não certificam o novo snapshot v3 ou o cache de fontes no Zorin.

## Animações preservadas — 22/10/2026

O perfil atual mantém `enable-animations=true` no Zorin, conforme a preferência de preservar as animações. A revisão inicial de otimização descrita acima usava `false`; reinstalar agora reativa as animações e inclui o valor substituído no backup. Ícones, fontes, cores, wallpaper e as demais otimizações permanecem como preparados no perfil.

O snapshot continua v3 com oito chaves. Backups e diários anteriores com animações `false`, `true` ou sem valor explícito permanecem válidos e são restaurados fielmente. A recuperação usa os valores registrados no diário, independentemente do novo padrão. O Arch mantém suas sete chaves.

Após o ajuste, passaram 56 testes Python (54 aprovados e dois ignorados por links nativos no Windows), incluindo 23 do helper GNOME; 14 cenários GNOME; cinco cenários transacionais selecionados para os escopos antigos e o novo padrão; ShellCheck e `git diff --check`. Foram conferidos aplicação sobre `false`, reinstalação sem diferenças, rollback para o valor anterior, recuperação de diário v3 antigo e preservação de edições concorrentes. A aceitação gráfica no Zorin real continua pendente.
