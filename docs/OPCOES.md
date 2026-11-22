# Referência de opções

Todos os core options dos três implementos, com valores e padrões.

---

# Project Genesis (GPGX e PicoDrive)

As duas variantes do Project Genesis compartilham o **mesmo renderizador** e o
**mesmo namespace de opções** (`project_genesis_*`), na mesma categoria
*"Project Genesis (Voxel 3D)"*. As opções abaixo valem para as duas.

> As opções do core de GPGX não foram lidas do binário — o patch dele não está
> publicado. O que se sabe é que o namespace e a categoria são os mesmos, e que o
> renderizador é idêntico. Ver [PROJECT-GENESIS-GPGX.md](PROJECT-GENESIS-GPGX.md).

19 opções na categoria **Project Genesis (Voxel 3D)** do menu do core. Todas prefixadas
com `project_genesis_`.

| Chave | Rótulo | Valores | Padrão |
|---|---|---|---|
| `project_genesis_voxel` | Voxel 3D | `Ligado` · `Desligado` | **Ligado** |
| `project_genesis_mode` | Modo 3D | `Relevo` · `Plano` · `Diorama` · `Neon` · `Cor para altura` | **Relevo** |
| `project_genesis_palette` | Paleta | `Original` · `Mega azul` · `Fosforo verde` · `Sunset` · `Noir` | **Original** |
| `project_genesis_camera` | Camera | `Frontal` · `Isometrica` · `Cinema` · `Baixa (diorama)` · `Lateral` · `Orbita automatica` | **Isometrica** |
| `project_genesis_zoom` | Zoom | `70%` · `80%` · `90%` · `100%` · `110%` · `120%` · `135%` · `150%` | **100%** |
| `project_genesis_depth` | Profundidade | `2` · `4` · `6` · `8` · `10` · `14` · `18` · `24` · `32` · `40` | **14** |
| `project_genesis_gap` | Espaco entre voxels | `0%` · `4%` · `8%` · `15%` · `25%` · `35%` | **8%** |
| `project_genesis_step` | Tamanho do voxel | `1x (detalhado)` · `2x` · `4x (rapido)` | **1x** |
| `project_genesis_resolution` | Resolucao de saida | `1x (320x224)` · `1.5x (480x336)` · `2x (640x448)` · `3x (960x672)` | **1.5x** |
| `project_genesis_light_angle` | Direcao da luz | `0` · `45` · `90` · `135` · `180` · `225` · `270` · `315` graus | **45** |
| `project_genesis_light` | Intensidade da luz | `0%` · `25%` · `50%` · `75%` · `100%` · `125%` · `150%` · `200%` | **100%** |
| `project_genesis_ambient` | Luz ambiente | `20%` · `30%` · `40%` · `45%` · `55%` · `65%` · `80%` | **45%** |
| `project_genesis_saturation` | Saturacao | `60%` · `80%` · `100%` · `115%` · `130%` · `150%` · `180%` | **115%** |
| `project_genesis_contrast` | Contraste | `70%` · `85%` · `100%` · `115%` · `130%` · `160%` | **100%** |
| `project_genesis_glow` | Brilho (glow) | `0%` · `20%` · `40%` · `60%` · `100%` · `150%` | **40%** |
| `project_genesis_scanlines` | Scanlines | `Desligado` · `Ligado` | **Desligado** |
| `project_genesis_floor` | Chao | `Ligado` · `Desligado` | **Ligado** |
| `project_genesis_background` | Fundo | `Preto` · `Azul-marinho` · `Cinza` · `Claro` | **Preto** |
| `project_genesis_stick` | Analogico direito orbita | `Ligado` · `Desligado` | **Ligado** |

> Os rótulos acima reproduzem os textos do core. O código-fonte original usa acentos
> corretos (`Relevo`, `Isométrica`, `Fósforo verde`, `Órbita automática`, etc.); alguns
> frontends exibem sem acento por causa da codificação das opções.

## Detalhes de cada opção

**Voxel 3D** — o interruptor geral. Desligado, o core entrega o quadro 2D normal do
PicoDrive e o renderizador não roda.

**Modo 3D** — como a altura de cada bloco é determinada:

| Modo | Regra |
|---|---|
| `Relevo` | Altura = brilho do pixel. É o modo mais fiel à leitura da imagem. |
| `Plano` | Altura constante. Todos os blocos ficam na mesma laje. |
| `Diorama` | Altura em 5 degraus discretos — visual de maquete. |
| `Neon` | Altura = brilho, mas a cor é escurecida e o glow é 4,5× mais forte. |
| `Cor para altura` | Altura pela cor dominante: vermelho = mais alto, azul = mais baixo. |

**Paleta** — remapeia a imagem por luminância, em três paradas (sombra → meio-tom →
destaque). Não mexe na altura, só na cor.

**Camera** — a posição inicial da câmera. `Orbita automatica` gira continuamente em
38° de amplitude.

**Zoom** — escala da cena. Acima de 100% a câmera se aproxima do jogo.

**Profundidade** — altura máxima dos blocos, em pixels de mundo. Valores grandes
deixam a cena "espetada" e se combinam bem com `Relevo`.

**Espaco entre voxels** — fração do bloco que fica como fresta escura. `0%` deixa os
blocos colados (sem o dilation que evita frestas, aparecem linhas pretas finas);
`35%` separa bastante e deixa a cena com cara de voxel art.

**Tamanho do voxel** — quantos pixels de origem formam um bloco. `1x` = 1 voxel por
pixel. `2x` e `4x` reduzem o número de células em 4× e 16× — é o controle de
desempenho mais efficace.

**Resolução de saida** — resolução do quadro 3D entregue ao frontend. Não muda o
número de voxels (que vem do tamanho do quadro do emulador), só o tamanho da imagem
final. Menor é mais leve.

**Direcao da luz** — ângulo da luz direcional em graus.

**Intensidade da luz** — força da luz direcional.

**Luz ambiente** — luz mínima em todas as faces. `0%` (não disponível na lista, mínimo
20%) deixa as faces opostas pretas.

**Saturacao** e **Contraste** — correções de cor aplicadas antes de tudo.

**Brilho (glow)** — luz aditiva nos blocos. No modo `Neon` o efeito é 4,5× maior.

**Scanlines** — escurece as linhas alternadas da grade em 28%, simulando monitor CRT.

**Chao** — mostra a base escura sob a cena.

**Fundo** — a cor do gradiente atrás da cena.

**Analogico direito orbita** — habilita o controle de câmera pelo analógico direito do
controle 1. `R3` reseta a câmera para a posição do modo selecionado.

---

# Retro8 Voxel

15 opções, todas prefixadas com `r8v_`.

| Chave | Rótulo | Valores |
|---|---|---|
| `r8v_modo` | Modo de renderização | `Voxel 3D` · `Voxel espaçado` · `Plano 2D` |
| `r8v_altura` | Altura dos voxels | `Média` · `Baixa` · `Alta` · `Extrema` |
| `r8v_fonte` | Altura calculada por | `Brilho` · `Saturação` · `Uniforme` |
| `r8v_fundo` | Piso (cor que fica rente) | `Lilás` · `Preto` · `Branco` · `Vermelho` · `Azul` · `Verde` |
| `r8v_inclin` | Inclinação inicial da câmera | `30°` · `15°` · `45°` · `60°` |
| `r8v_balanco` | Balanço automático da câmera | `Ligado` · `Desligado` |
| `r8v_analog` | Velocidade do analógico direito | `Normal` · `Lenta` · `Rápida` |
| `r8v_zoom` | Zoom da câmera | `Normal` · `Perto` · `Longe` |
| `r8v_suaviza` | Suavização das alturas | `Normal` · `Desligada` · `Suave` · `Lenta` |
| `r8v_luz` | Sombreamento das faces | `Normal` · `Forte` · `Suave` · `Sem sombreamento` |
| `r8v_carcaca` | Carcaça do videogame | `Completa` · `Só a tela` |
| `r8v_cor` | Cor da carcaça | `Cor mais comum` · `Preto` · `Nenhum (tudo sobe)` |
| `r8v_cena` | Fundo da cena | `Gradiente escuro` · `Preto` · `Cinza` · `Azul` |
| `r8v_qualidade` | Qualidade do render (desempenho) | `100%` · `75%` · `50%` · `200% (suavizado)` |
| `r8v_resolucao` | Resolução da imagem | `640x480` · `960x720` · `1280x960` |

> **Origem desta tabela:** o código-fonte *deste* conjunto de opções não está
> publicado. A versão base do wrapper está em
> [`xmyguel-x/retro8_voxel`](https://github.com/xmyguel-x/retro8_voxel) e **não tem
> opções** — ela fixa resolução, câmera e iluminação no código. O binário com as 15
> opções `r8v_*` é uma evolução posterior, e as listas de valores foram extraídas do
> binário por leitura da tabela de literais. O pareamento entre chave e lista foi
> confirmado pelo posicionamento contíguo das strings no arquivo.

## Detalhes de cada opção

**Modo de renderização** — `Voxel 3D` é o modo completo; `Voxel espaçado` aumenta o
espaçamento entre os blocos; `Plano 2D` desliga o 3D e volta ao quadro plano.

**Altura dos voxels** — o quanto os blocos sobem. `Extrema` é o cenário mais
"escultura".

**Altura calculada por** — de onde vem a altura:
- `Brilho` — luminância do pixel (mais fiel);
- `Saturação` — quanto mais saturada a cor, mais alto (destaça áreas coloridas);
- `Uniforme` — todas as células com a mesma altura.

**Piso** — cor da base rente ao chão da cena. O padrão `Lilás` é a cor de borda
clássica do PICO-8.

**Inclinação inicial da câmera** — o ângulo de partida da câmera.

**Balanço automático da câmera** — a câmera se move sozinha, oscilando.

**Velocidade do analógico direito** — quão rápido o analógico move a câmera.

**Zoom da câmera** — `Perto` e `Longe` deslocam a cena.

**Suavização das alturas** — suaviza os degraus entre células, formando terreno
contínuo em vez de ruído. **É a opção que mais muda o resultado visual.** `Desligada`
mostra a altura crua.

**Sombreamento das faces** — a força do contraste entre as faces iluminadas e as
escuras. `Sem sombreamento` deixa tudo com a mesma cor (estilo flat).

**Carcaça do videogame** — desenha um modelo 3D de console em volta da tela. `Completa`
mostra o console inteiro; `Só a tela` mostra apenas o painel.

**Cor da carcaça** — `Cor mais comum` usa a cor dominante da imagem do jogo, o que faz
a carcaça "combinar" com o jogo. `Nenhum (tudo sobe)` faz a carcaça subir em direção
à tela.

**Fundo da cena** — cor ou gradiente atrás da cena.

**Qualidade do render** — escala de Supersampling. `50%` é o mais leve; `200%
(suavizado)` renderiza em dobro da resolução e reduz, com bordas mais suaves.

**Resolução da imagem** — resolução do quadro final entregue ao frontend.
