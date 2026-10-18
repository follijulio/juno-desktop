# Identidade visual ? Juno Desktop

O Juno aplica a refer?ncia editorial Netuno aos recursos que controla: wallpaper original, terminal, prompt e configura??es tipogr?ficas. O GNOME conserva Adwaita e seus componentes nativos.

| Cor | sRGB | Aplica??o nos recursos Juno |
| --- | --- | --- |
| Papel creme | `#FFFDF5` | Texto do terminal e fundo editorial |
| Tinta | `#111111` | Fundo do terminal e contornos |
| Branco | `#FFFFFF` | Texto e cart?es do wallpaper |
| Bege | `#F4EDDB` | Apoios neutros |
| Terracota | `#FF5B35` | ?nfases e cursor |
| Amarelo marca | `#FFCC00` | Sele??o |
| Amarelo suave | `#FFE066` | Apoio e aten??o |
| Menta | `#B8F2E6` | Confirma??o |
| Coral | `#FF9B85` | Urg?ncia e erro |

Roboto organiza a interface GNOME. JetBrains Mono ? a fam?lia de c?digo; Kitty e o terminal integrado do VS Code usam JetBrainsMono Nerd Font Mono para os s?mbolos do prompt. Kitty define as quatro variantes reais e tamanho 12. Space Mono original permanece vendorizada para compatibilidade com recursos e backups anteriores.

Kitty mant?m a variante t?cnica editorial: fundo tinta, texto papel, superf?cie opaca e cores ANSI da paleta. Programas que emitem truecolor e interfaces internas de aplicativos t?m seus pr?prios temas.

O wallpaper editorial tem microtextura creme/bege e uma ficha geom?trica de cantos retos, com sombra s?lida e sem desfoque. PNG indexado, SVG e checksums acompanham o projeto. O gerador confere estrutura e pixels PNG e conte?do SVG; diferen?as no compressor n?o alteram a identidade.

A galeria fotogr?fica e ilustrada fornecida pelo usu?rio preserva pixels e cores originais. Ghibli ? Vale tranquilo ? o padr?o inicial. O bloqueio nativo do GNOME acompanha o fundo do desktop e aplica seu pr?prio desfoque.

O projeto n?o promete que painel, notifica??es, bloqueio ou todos os aplicativos GNOME obede?am ? paleta, aos raios ou ?s sombras do ambiente Hyprland anterior. N?o instala extens?es de tema nem CSS global para modificar esses componentes. As anima??es s?o desativadas pela prefer?ncia nativa.

`tools/check_brand.py` confere configura??es ativas Juno/Kitty, cores dos recursos editoriais, fontes autorizadas e integridade dos arquivos vendorizados. Configura??es Hyprland hist?ricas n?o fazem parte dessa valida??o da distribui??o GNOME.
