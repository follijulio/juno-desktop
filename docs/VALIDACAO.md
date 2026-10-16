# Validação

## Verificações automáticas

`bash tests/run.sh` reúne sintaxe Bash, ShellCheck quando disponível, conformidade visual e integridade dos recursos, testes do instalador, transações e scripts de sessão. Python 3 é uma dependência de desenvolvimento; não é necessário para executar a sessão instalada.

As transações usam diretórios temporários e comandos simulados. No Windows, casos dependentes das permissões POSIX, links ou `flock` real podem ser marcados como não reproduzíveis; os testes registram esses limites explicitamente.

`bash tests/native.sh` exige Arch e usuário comum. Executa `Hyprland --verify-config` em diretório de runtime privado, sem iniciar uma sessão gráfica, e repete a suíte portável. Isso confirma o parser, mas não certifica hardware, serviços ou aparência.

## Aceitação em uma sessão real

Execute em um Arch de teste antes de usar como configuração principal:

- Instalar a partir de TTY e confirmar logs, backup, fontes e saída bem-sucedida. Reexecutar sem edições e conferir ausência de backup duplicado.
- Iniciar por `start-hyprland`; conferir ausência de erros de configuração e de processos duplicados após recarregar o compositor.
- Revisar Waybar, launcher, notificações, Kitty e bloqueio em 1366×768, 1920×1080 e monitor com escala maior. Verificar sombras sem corte, texto legível, foco e seleção por teclado.
- Testar todos os atalhos do README, teclado ABNT2, janelas flutuantes, tela cheia, múltiplos espaços e, quando disponível, múltiplos monitores.
- Confirmar áudio, mute, microfone, brilho e presença condicional de bateria. Em máquina sem esses dispositivos, verificar ausência de controles quebrados.
- Salvar região e tela inteira, copiar região e cancelar seleção; conferir nomes únicos e tratamento de diretório de imagens com espaços.
- Testar seleção de arquivos e compartilhamento de tela em um aplicativo Wayland compatível, verificando os backends dos portais.
- Bloquear manualmente, aguardar 5/10 minutos, suspender pelo sistema e retomar. Confirmar que autenticação precede o retorno ao conteúdo.
- Cancelar todas as confirmações do menu de sessão e verificar que nenhuma ação ocorre. Confirmar saída/reinício/desligamento somente quando apropriado.
- Restaurar um backup após editar um arquivo; conferir retorno ao estado original e preservação das edições no backup recém-criado.
- Conferir Steam, Discord, Spotify, Firefox e VS Code no launcher. Executar `code --version`, `python --version`, `node --version`, `gcc --version`, `go version` e `cargo --version` na sessão Juno. Confirmar nome Visual Studio Code e acesso ao Marketplace original.
- Verificar multilib habilitado, backup do pacman e escolha correta do provider Vulkan de 32 bits. Validar instalação/atualização Flatpak sem alterar remotes de outro endereço.
- Abrir `Super + W`, selecionar diferentes imagens, cancelar, reiniciar a sessão e bloquear. Conferir persistência e foto correta; escolher AVIF e confirmar fallback JPG no bloqueio. Galeria indisponível deve preservar o bloqueio com fundo creme.

## Estado da validação

A implementação foi preparada em Windows com Git Bash. O arquivo `RESULTADOS.md` registra os comandos efetivamente executados e seus resultados. Testes gráficos e de serviços no Arch precisam de execução no sistema alvo; sua ausência não deve ser apresentada como sessão homologada.
