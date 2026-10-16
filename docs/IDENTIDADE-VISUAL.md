# Identidade visual — Juno Desktop

Adaptação do manual Netuno para os componentes gerenciados da sessão. O nome do produto é Juno Desktop. A referência editorial usa fichas, hierarquia tipográfica e contornos precisos.

| Cor | sRGB | Aplicação |
| --- | --- | --- |
| Papel creme | `#FFFDF5` | Fundo principal, launcher e bloqueio |
| Tinta | `#111111` | Texto, contornos e sombras sólidas |
| Branco | `#FFFFFF` | Cartões e notificações |
| Bege | `#F4EDDB` | Apoios e estados neutros |
| Terracota | `#FF5B35` | Ênfases |
| Amarelo marca | `#FFCC00` | Seleção e identificação |
| Amarelo suave | `#FFE066` | Apoio editorial e atenção |
| Menta | `#B8F2E6` | Hover e confirmação |
| Coral | `#FF9B85` | Urgência e erro |

Roboto 400/700/900 organiza títulos, controles e texto. Space Mono 400/700 identifica dados e o terminal; os estilos itálicos originais acompanham as fontes. Não há dependência de fontes de ícones.

Cantos têm raio zero. Controles e cartões recebem contorno tinta de 2 px, painéis principais de 4 px. Sombras permitidas são sólidas, deslocadas 4 px e sem desfoque. O compositor usa janelas planas, sem sombras nativas, blur, transparência ou animação. Waybar reserva margem para as sombras; Rofi usa uma caixa de apoio tinta. Mako usa cartões planos por limitação da sua API de estilo.

O foco e a seleção usam cor contrastante e rótulos persistentes. Texto pequeno fica em tinta sobre fundos claros. Kitty adota a variante técnica editorial com fundo tinta para manter legibilidade das cores ANSI da mesma paleta. Aplicativos que emitem truecolor e interfaces internas de terceiros mantêm seus próprios temas.

O wallpaper original tem microtextura creme/bege e uma ficha geométrica no canto inferior direito. A fonte SVG, o PNG indexado e seus checksums são reproduzidos por `tools/generate_wallpaper.py`; não dependem de download durante a instalação.

A galeria fornecida pelo usuário também está disponível, com Ghibli · Vale tranquilo como padrão. Imagens mantêm seus pixels e suas cores originais; essa exceção aplica-se aos fundos fotográficos e ilustrados. Os controles continuam restritos à paleta. O bloqueio usa um cartão creme opaco de 520 × 500, contorno de 4 px, sombra sólida de 8 px e faixa menta. Relógio/data usam Space Mono; identificação, senha e mensagens usam Roboto. Fotografias ficam atrás dos painéis, sem blur ou sobreposições translúcidas.

Mensagens são curtas, em português brasileiro, identificando a ação, o resultado e a recuperação disponível. A interface evita animações e preserva contraste sem depender de cor como único sinal.
