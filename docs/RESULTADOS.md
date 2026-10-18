# Resultados de valida??o ? 17/10/2026

Ambiente desta migra??o: Windows, PowerShell, Git Bash e Python 3.15. N?o h? WSL ou sess?o GNOME/Arch dispon?vel. Nenhum pacote Linux foi instalado neste Windows.

## Baseline e corre??es

A inspe??o inicial encontrou 32 arquivos Bash e 9 testes Python de marca. Nos testes anteriores informados nesta revis?o, transa??es tinham 18 cen?rios aprovados, multilib 14 e aplicativos 5; esses resultados pertencem ? baseline e n?o certificam a implementa??o GNOME.

`python -B tools/generate_wallpaper.py --check` falhava originalmente. O PNG distribu?do e o gerado possu?am pixels id?nticos, mas bytes IDAT diferentes por causa de zlib-ng. A verifica??o passou a comparar estrutura e pixels PNG e conte?do SVG, preservando o arquivo e seu checksum.

O empacotamento agora prepara o arquivo e SHA-256 em tempor?rios, recusa links simb?licos e preserva o pacote anterior em falhas de prepara??o ou publica??o do checksum. Os execut?veis GNOME recebem modo POSIX execut?vel.

## Executado nesta migra??o

| Comando/verifica??o | Resultado |
| --- | --- |
| `python -B tools/generate_wallpaper.py --check` | Aprovado ap?s corre??o; assets preservados |
| `python -B tools/catalog_wallpapers.py --check` | 32 arquivos, 31 imagens ?nicas; aprovado |
| `python -B -m unittest discover -s tests -p '*_test.py'` | 17 cen?rios: 16 aprovados, 1 ignorado por indisponibilidade de symlinks no Windows |
| Novos testes tooling | Compress?o PNG alternativa, corrup??o/truncamento, pixels alterados, LF/permiss?es, pacote reproduz?vel, falha de leitura, falha de publica??o de SHA e exclus?o de metadados |

Os demais resultados da su?te integrada devem ser conferidos ap?s a conclus?o dos m?dulos GNOME e do instalador. Este registro n?o apresenta os testes Hyprland antigos como valida??o do GNOME.

## Pendente no ambiente nativo

N?o foram executados GDM, GNOME Shell, PAM, systemd, portais, hardware, parsers/fontes reais do Kitty ou aceita??o gr?fica. Links POSIX, concorr?ncia real de `flock` e persist?ncia `sync -f` tamb?m exigem Linux.

Execute `bash tests/native.sh` no Arch e complete [o roteiro de aceita??o](VALIDACAO.md). Downloads e comandos simulados nos testes locais n?o certificam aplicativos, jogos, captura, bloqueio, ?udio, imagem AVIF ou suspens?o em uma sess?o real.
