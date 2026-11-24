# Como o renderizador voxel funciona

Documento de referência do renderizador 3D usado no Project Voxel. O código descrito
aqui é o `platform/libretro/voxel.c` (441 linhas) e o `voxel.h` (23 linhas) que o
[patch do Project Genesis 32X](../patches/project-genesis-32x.patch) adiciona ao
PicoDrive. O wrapper do Retro8 Voxel carrega um renderizador equivalente, com mais
recursos de cena.

**Natureza:** software puro. C99, sem OpenGL, sem shaders, sem dependências além de
`libm` (`-lm`). Tudo acontece na CPU, o que torna o core portável para qualquer
plataforma onde o emulador já compile — incluindo Android/Termux.

> **Este documento descreve o renderizador do Project Genesis 32X** (o `voxel.c` do
> patch). O wrapper do Retro8 Voxel usa um **renderizador diferente**, com z-buffer e
> rasterização de triângulos — veja [RETRO8-VOXEL.md](RETRO8-VOXEL.md). Os dois
> compartilham a mesma ideia central: transformar cada pixel do jogo em um bloco com
> altura, cor, luz e sombra.

---

## Constantes do renderizador

| Constante | Valor | Significado |
|---|---|---|
| `VOX_MAX_W` | 960 | Largura máxima do quadro de saída (RGB565) |
| `VOX_MAX_H` | 672 | Altura máxima do quadro de saída (RGB565) |
| `MAXGRID_W` | 720 | Largura máxima da grade de células lida da origem |
| `MAXGRID_H` | 576 | Altura máxima da grade de células lida da origem |
| `MAXCELLS` | 130.000 | Teto de células por quadro |
| `DEG2RAD` | 0,017453292519943295 | Conversão grau → radiano |

Memória estática alocada: `outbuf` (RGB565, 960×672×2 = **1,29 MB**) + `cells`
(130.000 × 4 bytes = **520 KB**).

---

## Etapa 1 — Amostragem: do quadro 2D para a grade de células

O framebuffer que o emulador entrega (RGB565) é lido em blocos de `step`×`step`
pixels. Cada bloco vira **uma célula** com quatro campos:

```c
typedef struct { uint8_t r, g, b, h; } cell_t;   /* cor + altura (0..255) */
```

Para cada célula o renderizador:

1. **Faz a média** dos `step²` pixels (em RGB de 8 bits) e joga o resultado em
   `r`, `g`, `b`.
2. **Saturação** — mistura a cor com sua luminância:
   ```c
   l = 0.299*r + 0.587*g + 0.114*b;
   r = l + (r - l) * sat;   /* idem para g e b */
   ```
   Com `sat = 1` não muda nada; acima de 1 intensifica, abaixo de 1 lava a cor.
3. **Contraste** — aplica `(c - 128) * con + 128`, centrando em 128 (meio-cinza).
4. **Recalcula a luminância** normalizada (0..1) depois das correções.
5. **Paleta** (se `pal > 0`) — remapeia por luminância através de uma rampa de
   3 paradas (sombra → meio-tom → destaque) definida em `pal_tab[5][9]`:

   | Paleta | Sombra | Meio-tom | Destaque |
   |---|---|---|---|
   | Original | — | — | — (sem remapeamento) |
   | Mega azul | `0,16,48` | `26,92,255` | `232,242,255` |
   | Fósforo verde | `4,26,4` | `47,191,47` | `200,255,200` |
   | Sunset | `42,10,58` | `255,90,60` | `255,233,160` |
   | Noir | `0,0,0` | `120,120,120` | `255,255,255` |

   A rampa é interpolada em dois trechos: luminância abaixo de 0,5 usa sombra→meio-tom;
   acima, meio-tom→destaque.

6. **Altura** — calculada conforme o modo 3D:

   | Modo | Altura (`h`) |
   |---|---|
   | **Relevo** | luminância contínua (0..1) |
   | **Plano** | 0 fixo — todas as células com a mesma altura |
   | **Diorama** | `floor(l * 5) / 5` — cinco degraus discretos |
   | **Neon** | luminância contínua, mas a cor base é escurecida ×0,55 |
   | **Cor para altura** | 0,9 se o vermelho domina, 0,5 se o verde, 0,2 se o azul; 0,05 se a cor é acinzentada (`max - min ≤ 20`) |

   A altura é guardada como `uint8_t` (0..255), normalizada depois.

7. **Scanlines** — se ligado, as linhas ímpares da grade (`j & 1`) escurecem ×0,72.

**Custo:** uma passada linear pelo framebuffer por quadro.

---

## Etapa 2 — A câmera

A câmera é posicionada em coordenadas **esféricas** ao redor do centro da grade:

```
inclinação (tl): 0° .. 85°      ← quanto a câmera olha "para baixo"
azimute  (az): 0° .. 360°       ← giro em torno do eixo vertical
```

Cada modo de câmera define um par `(tl, az)` inicial:

| Câmera | Inclinação | Azimute |
|---|---|---|
| Frontal | 0° | 0° |
| Isométrica | 48° | 30° |
| Cinema | 28° | -18° |
| Baixa (diorama) | 68° | 0° |
| Lateral | 35° | 55° |
| Órbita automática | 40° | 0° + oscilação |

A **órbita automática** soma `38° × sin(frame × 0.012)` ao azimute, produzindo um giro
contínuo e lento.

### Suavização

A câmera nunca salta: azimute, inclinação e zoom são interpolados a cada quadro.

```c
cur_az   += (tt_az   - cur_az)   * 0.18f;   /* 18% por quadro  */
cur_tl   += (tt_tl   - cur_tl)   * 0.18f;
cur_zoom += (o.zoom/100.f - cur_zoom) * 0.25f;  /* 25% por quadro */
```

Isso dá a sensação de "peso" da câmera — movimento orgânico em vez de teleporte.

### Projeção

```c
fov = 40°;                    /* campo de visão fixo */
f   = (OH / 2) / tan(fov/2);  /* distância focal, derivada da altura de saída */
```

A distância da câmera (`dist`) é calculada para que a grade inteira caiba no quadro,
com uma margem de 6%:

```c
d1 = (gh/2) / tf;
d2 = (gw/2) / (tf * aspecto);
dist = max(d1, d2) * 1.06 / zoom;
```

O `zoom` (70% a 150%) é um divisor: acima de 100% a câmera se aproxima.

A posição e a orientação são então calculadas com a base vetorial usual:

```c
Cx = dist * sin(tl) * sin(az);
Cy = -dist * sin(tl) * cos(az);
Cz = dist * cos(tl) + hz_mid;   /* olhando para (0, 0, hz_mid) */
```

### Entrada do jogador

- **Analógico direito** → desloca azimute e inclinação, com zona morta de 6.500
  (de -32.768 a 32.767) e limites de ±85° na inclinação.
- **R3** → zera os deslocamentos e volta à câmera base.

---

## Etapa 3 — Cena: fundo, chão e luz

### Fundo

O fundo é um **gradiente vertical** de duas cores por opção (`bg_tab[4][6]`):

| Fundo | Topo | Base |
|---|---|---|
| Preto | `6,7,12` | `14,16,26` |
| Azul-marinho | `8,20,64` | `2,6,24` |
| Cinza | `40,40,46` | `16,16,20` |
| Claro | `200,204,214` | `120,124,136` |

### Chão

Um quadrilátero grande em `z = 0`, 16 unidades maior que a grade em cada lado, projetado
pela mesma câmera. Aparece sob a cena como uma base escura (`22,25,36`), ou cinza-claro
(`150,154,166`) quando o fundo é "Claro".

### Luz

A luz é **direcional**, definida pelo ângulo em graus (`0` a `315`):

```c
L = normalize(cos(la) * 0.55, sin(la) * 0.55, 0.85);
```

Cada orientação de face recebe um **fator de iluminação** combinando luz ambiente e
luz direcional:

```c
facTop = amb + li *  L.z;
facXp  = amb + li * max( L.x, 0);   /* face +X */
facXm  = amb + li * max(-L.x, 0);   /* face -X */
facYp  = amb + li * max( L.y, 0);   /* face +Y */
facYm  = amb + li * max(-L.y, 0);   /* face -Y */
```

Como o fator só usa a componente **positiva** da direção da luz, a face oposta à luz
fica iluminada apenas pela luz ambiente — é assim que nasce o contraste entre as faces.

---

## Etapa 4 — Desenho: painter's algorithm

O renderer **não usa z-buffer**. A ordem de desenho é calculada para que as células
mais distantes venham primeiro.

A função `make_order()` gera a ordem de linhas e colunas:

```c
/* c = índice da célula mais próxima da câmera naquela eixo */
for (i = 0;   i <= c; i++) out[k++] = i;        /* do fundo até a célula central */
for (i = n-1; i >  c; i--) out[k++] = i;        /* e de volta para a frente */
```

Ou seja: percorre-se a grade em zigue-zague, partindo da borda mais distante,
passando pela célula mais próxima da câmera e voltando. Como as células mais altas
também tendem a estar mais à frente, o resultado é visualmente correto na imensa
maioria dos casos.

### Faces de uma célula

Para cada célula visível, o renderizador calcula:

1. A posição projetada do centro da célula (`sx`, `sy`) e a escala `s = f / zc`.
2. **O topo** — um quadrado de lado `step`.
3. **Até 4 faces laterais** — cada uma só é desenhada se:
   - a face está virada para a câmera (teste do sinal de `Cx`/`Cy` vs. a posição da célula);
   - o **vizinho** naquela direção é mais baixo, com diferença `dh > 0,05`.

   A altura da parede é exatamente `dh` — a diferença entre o topo da célula e o topo
   do vizinho. Isso faz com que paredes só apareçam onde há degrau, como em um
   relieve de verdade, e não como uma caixa para cada pixel.

O "`Plano`" merece nota: a altura é 0, mas a espessura mínima é
`(0.6 + h * depth) * step`, ou seja `0.6 × step` — o resultado é uma **laje plana**,
não uma ausência de blocos.

### Cor final

```c
r = (int)(c->r * (fator_da_face + brilho));
```

O **brilho (glow)** é aditivo e depende do modo: `glow × 1.6` no modo Neon e
`glow × 0.35` nos demais, escalado pela altura da célula (`0.3 + h`).

---

## Etapa 5 — Rasterização dos quadriláteros

`fill_quad()` preenche um quadrilátero de cor chapada. Não é um scanline genérico: ele
usa **recorte por half-planes**.

Para cada uma das 4 arestas do quad, o renderer deriva uma inequação `A·x + B·y + C ≥ 0`:

```c
A[i] = -sgn * dy;
B[i] =  sgn * dx;
C[i] =  sgn * (-dx*ay + dy*ax) + 0.4f * (fabsf(dx) + fabsf(dy));
```

O termo `0.4 × (|dx| + |dy|)` é um **dilation proposital**: as faces são levemente
infladas para que faces vizinhas se sobreponham um pouco e **não apareçam frestas
pretas** entre os blocos. É a razão de o "Espaço entre voxels" precisar de um valor
negativo zero — e a razão de o `gap` existir como opção separada.

Depois, para cada linha `y` da caixa envolvente:

1. Cada half-plane vira um limite em `x`: `A > 0` dá um piso, `A < 0` dá um teto,
   `A ≈ 0` exige `C ≥ 0` sob a linha, senão a linha inteira é descartada.
2. O intervalo `[x0, x1]` resultante é preenchido com a cor.

Quando a câmera está exatamente frontal, o topo da célula vira um retângulo alinhado
aos eixos — nesse caso o renderer usa um caminho rápido de preenchimento direto em
linha, evitando o custo da rasterização.

---

## Etapa 6 — Saída

O resultado é gravado em `outbuf` (RGB565, `uint16_t`) e devolvido ao frontend:

```c
vf = vox_render(buff, vout_width, vout_height, vout_width * 2);
if (vf) { vox_output_size(&vw, &vh); video_cb(vf, vw, vh, vw * 2); return; }
```

O `pitch_bytes` é informado porque o framebuffer de origem pode ter passo diferente
da largura.

**Detalhe crítico:** o framebuffer do PicoDrive é RGB565 — o core define
`RETRO_PIXEL_FORMAT_RGB565` e **aborta** se o frontend não aceitar. O renderizador
converte de volta para RGB565 na saída, porque é o formato que o frontend do libretro
já aceitou.

O renderizador tem **dois caminhos de leitura**, e é isso que revela a origem dele:

```c
#ifdef FRONTEND_SUPPORTS_RGB565
   /* lê como RGB565 */
#else
   /* lê como 0RGB1555 */
#endif
```

O PicoDrive só usa RGB565. Já o Genesis Plus GX negocia os dois — e foi sobre o GPGX
que este renderizador foi escrito. Ver
[PROJECT-GENESIS.md](PROJECT-GENESIS.md).

---

## Integração com o frontend (libretro)

O renderizador conversa com o frontend por três funções:

```c
bool vox_enabled(void);                    /* o modo voxel está ligado?           */
bool vox_check_options(retro_environment_t env);  /* lê as opções do core         */
void vox_output_size(unsigned *w, unsigned *h);   /* resolução de saída            */
void vox_input(int rx, int ry, bool reset);       /* analógico + reset de câmera   */
const uint16_t *vox_render(const uint16_t *src, unsigned w, unsigned h, size_t pitch);
```

`vox_check_options()` lê todas as opções do core via `RETRO_ENVIRONMENT_GET_VARIABLE`
e **recalcula a geometria do frontend** quando o modo voxel é ligado/desligado ou
quando a resolução de saída muda. No `libretro.c` isso vira:

```c
if (vox_check_options(environ_cb) && !first_run)
   libretro_update_geometry = true;
```

E o tamanho de saída do modo voxel (até 960×672) é reservado em
`retro_get_system_av_info()` com `max_width`/`max_height`, para que o frontend reserve
espaço para o quadro maior.

---

## Limites de desempenho

O custo é essencialmente **proporcional ao número de células**:

| Resolução da origem | `step = 1` | `step = 2` | `step = 4` |
|---|---|---|---|
| 320×224 (Mega Drive) | 71.680 células | 17.920 | 4.480 |
| 640×448 | 286.720 (excede o teto) | 71.680 | 17.920 |

Quando `(gw/step) × (gh/step)` passa de `MAXCELLS - 1000` (130.000), o próprio renderer
**aumenta o `step` automaticamente** — a cena continua funcionando, só com menos detalhe.
Isso é a rede de segurança para origens grandes.

---

## Referência rápida de arquivos

| Arquivo | Papel |
|---|---|
| `platform/libretro/voxel.c` | O renderizador completo (amostragem, câmera, cena, desenho, rasterização) |
| `platform/libretro/voxel.h` | API pública do renderizador + constantes `VOX_MAX_W/H` |
| `platform/libretro/libretro.c` | Integração: `retro_run`, `retro_get_system_av_info`, `update_variables` |
| `platform/libretro/libretro_core_options.h` | As 21 opções do modo voxel |
| `Makefile` / `Makefile.libretro` | Adiciona `voxel.o` ao build e renomeia o alvo |
