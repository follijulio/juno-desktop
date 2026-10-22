# Identidade visual — Juno Desktop

O Juno aplica a referência editorial Netuno ao wallpaper original, terminal, prompt e configurações tipográficas. O GNOME usa seus componentes nativos, com tema escuro e animações ativadas no perfil inicial, mantendo backup dos valores anteriores. Os ícones dos aplicativos têm uma linguagem própria baseada na referência de cartões coloridos e ilustrações com contorno.

| Cor | sRGB | Aplicação nos recursos Juno |
| --- | --- | --- |
| Papel creme | `#FFFDF5` | Texto do terminal e fundo editorial |
| Tinta | `#111111` | Fundo do terminal e contornos |
| Branco | `#FFFFFF` | Texto e cartões do wallpaper |
| Bege | `#F4EDDB` | Apoios neutros |
| Terracota | `#FF5B35` | Ênfases e cursor |
| Amarelo marca | `#FFCC00` | Seleção |
| Amarelo suave | `#FFE066` | Apoio e atenção |
| Menta | `#B8F2E6` | Confirmação |
| Coral | `#FF9B85` | Urgência e erro |

Roboto organiza interface e documentos GNOME. Space Mono é a fonte monoespaçada do perfil GNOME e permanece vendorizada com licença e checksums. JetBrains Mono é a família do editor VS Code; Kitty e seu terminal integrado usam JetBrainsMono Nerd Font Mono para os símbolos do prompt. Kitty define quatro variantes reais e tamanho 12.

Kitty mantém fundo tinta, texto papel, superfície opaca e cores ANSI da paleta. Programas que emitem truecolor e interfaces internas de aplicativos têm seus próprios temas. Oh My Posh usa a mesma paleta em um tema local simples.

O wallpaper editorial tem microtextura creme/bege e ficha geométrica de cantos retos, com sombra sólida e sem desfoque. PNG indexado, SVG e checksums acompanham o projeto. O gerador confere estrutura e pixels PNG e conteúdo SVG; diferenças no compressor não alteram a identidade.

A galeria fotográfica e ilustrada preserva pixels e cores originais. Ghibli · Vale tranquilo é o padrão inicial. A aparência do bloqueio pertence ao GNOME e às preferências da conta.

Painel, notificações, bloqueio e aplicativos GNOME não recebem CSS global ou extensões de tema. Recursos históricos Hyprland não são aplicados pela instalação GNOME.

O tema de ícones **Juno** usa cartões arredondados coloridos, desenhos creme, contornos escuros e pequenas sombras. São 105 desenhos e variantes e 227 nomes SVG, incluindo aplicativos, pastas, categorias e ações. Pastas especiais têm emblemas próprios. As variantes simbólicas preservam os traços sem fundo opaco, permitindo ao GNOME manter contraste em menus claros ou escuros. SVGs locais CC0 não usam fontes, recursos externos ou filtros; nomes não cobertos herdam Adwaita/hicolor.

`tools/check_brand.py` confere configurações ativas Juno/Kitty, cores dos recursos editoriais, fontes autorizadas e integridade dos arquivos vendorizados. Configurações Hyprland históricas não fazem parte dessa validação da distribuição GNOME.

A camada `Juno-Auto` aplica aos lançadores não cobertos a mesma paleta da base, símbolo creme/tinta e cartão colorido com borda escura. O símbolo original é mantido na composição; não se usa geração por IA nem download de temas. Os desenhos curados continuam prioritários. Pastas e ícones simbólicos usam diretamente as variantes vetoriais da base Juno.
