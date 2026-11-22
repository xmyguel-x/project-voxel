# Retro8 Voxel

O segundo core do Project Voxel, e o mais interessante do ponto de vista de
arquitetura: em vez de **modificar** um emulador, ele **embrulha** outro emulador.

O Retro8 Voxel é um core libretro que carrega o
[core PICO-8 do libretro](https://github.com/libretro/retro8) em tempo de execução
com `dlopen()`, repassa todas as chamadas da API libretro para ele e troca a entrega
do quadro 2D por uma renderização 3D.

```
RetroArch
   │  (API libretro completa)
   ▼
retro8_voxel_libretro.so        ← o wrapper: opções + renderizador + cena
   │  dlopen("retro8_libretro.so")
   ▼
retro8_libretro.so               ← o core original, intocado
   │  video_cb(frame 2D 128×128)
   ▼
retro8_voxel_libretro.so        ← intercepta, converte em 3D e devolve
```

---

## Duas versões que existem

| | **Código-fonte publicado** | **Binário distribuído** |
|---|---|---|
| Onde | [`xmyguel-x/retro8_voxel`](https://github.com/xmyguel-x/retro8_voxel) | `retro8_voxel_libretro.so` |
| Estado | **Versão anterior**, completa e legível | **Versão nova**, com mais recursos |
| Opções de core | Nenhuma — tudo fixo no código | **15 opções `r8v_*`** |
| Resolução | Fixa em 640×480 | `640x480` · `960x720` · `1280x960` |
| Tamanho | 18 KB de C | 56 KB de binário |

O repositório `retro8_voxel` publica a **versão base** do wrapper, com o código-fonte
completo e legível (`retro8_voxel.c`, 425 linhas). O binário que você encontra
distribuído é uma **evolução** dessa base, com as 15 opções de core que allowem
configurar resolução, qualidade, suavização, cores e câmera — o código dessa
evolução **não está publicado**.

Este documento descreve as duas, marcando o que vem do código-fonte e o que foi
verificado por análise do binário.

---

## O mecanismo, em detalhe

### Carregamento do core interno

```c
static const char *names[] = {
    "retro8_libretro_android.so",
    "retro8_inner_libretro_android.so",
    "retro8_libretro.so",
    NULL
};
```

O caminho é resolvido em tempo de execução com `dladdr()` sobre a própria função, de
modo que o core é sempre procurado **na mesma pasta do wrapper** — independente do
diretório de trabalho do frontend:

```c
if (dladdr((void *)&load_inner, &di) && di.dli_fname) {
    const char *s = strrchr(di.dli_fname, '/');
    /* recorta o diretório do próprio wrapper */
}
```

O binário mais recente tenta **quatro** nomes — acrescentando
`retro8_inner_libretro.so` — cobrindo as convenções de nome que o libretro usa.

### Encaminhamento da API

O wrapper exporta a API libretro completa. Quase tudo é repasseado direto:

```
retro_api_version          retro_set_environment       retro_get_system_info
retro_init                 retro_set_video_refresh      retro_get_system_av_info
retro_deinit               retro_set_audio_sample       retro_load_game
retro_reset                retro_set_audio_sample_batch retro_load_game_special
retro_run                  retro_set_input_poll         retro_unload_game
retro_serialize_size       retro_set_input_state        retro_set_controller_port_device
retro_serialize            retro_cheat_reset            retro_serialize
retro_unserialize          retro_cheat_set              retro_unserialize
                                                    retro_get_region
                                                    retro_get_memory_data / _size
```

Os ponteiros são resolvidos com `dlsym()` e **todos precisam existir** — se faltar
um único, o wrapper considera o core interno inválido (`g_ok = false`) e se recusa a
carregar o jogo.

### O proxy de vídeo — o ponto que troca tudo

```c
API void retro_set_video_refresh(video_t cb) {
    g_video = cb;                                   /* guarda o callback real   */
    if (load_inner()) in.set_video_refresh(video_proxy);  /* dá o seu ao interno */
}
```

- O core interno desenha o frame 2D e chama `video_proxy`.
- `video_proxy` **não entrega nada ao frontend** — apenas copia o frame para um
  buffer interno (`g_px`), convertendo do formato de pixel do core interno para
  RGB de 24 bits.
- `retro_run` então chama `render_scene()` e entrega o resultado 3D ao callback real:

```c
API void retro_run(void) {
    if (!g_ok) return;
    in.run();          /* o core interno avança o jogo e chama video_proxy */
    update_input();
    render_scene();
    if (g_video) g_video(fb, OUT_W, OUT_H, OUT_W * 4);
}
```

### O proxy de ambiente

O wrapper também intercepta `retro_set_environment` para controlar o que o core
interno enxerga:

| Comando | Ação |
|---|---|
| `SET_PIXEL_FORMAT` (10) | **Anota** o formato pedido pelo core interno e devolve `true` — é assim que o wrapper descobre se o frame chega em XRGB8888, RGB565 ou 0RGB1555 |
| `GET_AV_INFO` / `SET_GEOMETRY` (32, 37) | **Ignorados** — a saída do wrapper é fixa (640×480, 4:3), então a geometria do jogo não interfere |
| `HW_RENDER` (14), `GET_FRAMEBUFFER` (40, 41) | **Recusados** — o renderizador é por software, não há buffer de hardware |
| Todo o resto | Repassado ao frontend |

O wrapper anuncia ao frontend que ele usa **XRGB8888** (`fmt = 1`).

### Formatos de pixel

`video_proxy` converte o frame para RGB de 24 bits conforme o formato negociado:

```c
if (g_infmt == 1)      /* XRGB8888 */  c = ((const uint32_t *)row)[x] & 0xFFFFFF;
else if (g_infmt == 2) /* RGB565   */  /* 5/6/5 → 8/8/8 */
else                   /* 0RGB1555 */  /* 5/5/5 → 8/8/8 */
```

---

## O core por baixo: PICO-8

O [libretro/retro8](https://github.com/libretro/retro8) é uma implementação do
**PICO-8**, o console fantasy da Lexaloffle, escrita em C++ com backend SDL2 e
backend libretro.

Detalhe relevante para o voxel: a tela do PICO-8 é **128×128 com 16 cores**
(`PALETTE_SIZE = 16` em `src/vm/gfx.h`). Isso faz do PICO-8 um caso de uso ideal
para voxel: uma imagem pequena e muito colorida, onde cada pixel vira um bloco e a
cena 3D fica nítida em vez de virar um borrão de blocos gigantes.

O core aceita cartuchos **`.p8`** e **`.png`** (cartuchos em PNG com dados
embutidos, decodificados pelo próprio core via `loadPNG`).

---

## O renderizador

### Diferente do core do Genesis — aqui há z-buffer

O renderizador do Project Genesis 32X usa *painter's algorithm* (ordena as células de
trás para frente). O do Retro8 Voxel usa um **z-buffer de verdade** e rasteriza
**triângulos**:

```c
static uint32_t fb[OUT_W * OUT_H];   /* framebuffer RGB888 */
static float    zb[OUT_W * OUT_H];   /* z-buffer (1/distância) */
```

Cada quad é dividido em dois triângulos, e cada triângulo é rasterizado com
**interpolação perspective-correct** do inverso da profundidade (`iw`):

```c
iw = (w0 * a.w + w1 * b.w + w2 * c.w) * inv;
if (iw > zb[y * OUT_W + x]) { zb[y * OUT_W + x] = iw; fb[y * OUT_W + x] = col; }
```

Como a profundidade é interpolada, não há o artefato de "células atrás aparecendo
atrás das da frente" que o painter's algorithm do core do Genesis pode produzir.

### Câmera

Projeção em três rotações sucessivas (yaw → pitch), com projeção perspectiva
divisa pela distância:

```c
#define CAMD 340.0f    /* distância da câmera */
#define FOCAL 760.0f  /* distância focal */
#define YOFF -6.0f    /* deslocamento vertical */

static inline V proj(float x, float y, float z) {
    float x1 = x * g_cy + z * g_sy, z1 = -x * g_sy + z * g_cy;
    float y2 = y * g_cp + z1 * g_sp, z2 = -y * g_sp + z1 * g_cp;
    float iw = 1.0f / (CAMD - z2);
    V v = { OUT_W*0.5f + FOCAL*x1*iw, OUT_H*0.5f - FOCAL*y2*iw + YOFF, iw };
    return v;
}
```

Há um balanço automático suave somado ao yaw:

```c
float yaw = (g_yaw + sinf(g_frame * 0.015f) * 2.5f) * 0.0174532925f;
```

### Iluminação por face

Cada orientação de face tem um fator fixo — não há luz direcional configurável na
versão publicada:

| Face | Fator |
|---|---|
| `+z` (frente) | `1.00` |
| `+y` (topo) | `0.90` |
| `-x` (esquerda) | `0.80` |
| `+x` (direita) | `0.60` |
| `-y` (fundo) | `0.50` |

O binário mais novo acrescenta as opções `r8v_luz` (sombreamento das faces) e
`r8v_inclin`, `r8v_balanco`, `r8v_analog`, `r8v_zoom`, indicando uma câmera com
parâmetros ajustáveis.

### Altura dos voxels

A heurística do código-fonte publicado:

1. **A cor mais comum do quadro vira o "piso"** — encontrada por um histograma com
   hash de 64 entradas (`mode_color()`), e essas células ficam com altura zero.
2. As demais células sobem conforme o brilho, entre **2,0 e 8,5 unidades**:
   ```c
   lum = (0.30*r + 0.59*g + 0.11*b) / 255.0f;
   t   = 2.0f + lum * 6.5f;
   ```
3. A altura é **suavizada entre quadros**, o que dá o efeito "pop":
   ```c
   g_h[j*MAXG+i] += (t - g_h[j*MAXG+i]) * 0.8f;
   ```

A versão nova generaliza isso com as opções `r8v_altura` (Média/Baixa/Alta/Extrema),
`r8v_fonte` (Brilho/Saturação/Uniforme) e `r8v_suaviza` (Normal/Desligada/Suave/Lenta).

### Paredes só onde há degrau

Como no core do Genesis, as faces laterais só são desenhadas quando o vizinho é mais
baixo — o que dá o visual de relevo em vez de uma caixa para cada pixel:

```c
if (cam_x < xl && nl < h) face(2, xl, yb, ZF + nl, xr, yt, ztop, c);
```

---

## A carcaça de videogame

É o diferencial do wrapper: o jogo não é renderizado solto no espaço, ele aparece
**dentro de um console 3D**, desenhado com os mesmos primitivos.

A carcaça é construída com caixas (`box()`), cada uma das quais desenha apenas as
faces voltadas para a câmera:

```c
box(-120, -66, -16, 120, 66, ZF - 0.6f, BODY);  /* placa de trás   */
box(-120, -66, ZF, -44.8f, 66, 0, BODY);         /* laterais com recorte da tela */
box(44.8f, -66, ZF, 120, 66, 0, BODY);
box(-52, -52, ZF, -44.8f, 52, 1.5f, DARK);      /* moldura da tela */
...
```

O que tem na cena:

| Parte | Detalhe |
|---|---|
| Corpo | Placa de trás + laterais com o recorte da tela |
| Moldura | Moldura escura em volta da área do jogo |
| Direcional | 4 blocos, o centro afunda quando pressionado |
| Botões A / B | Vermelho e âmbar, afundam ao apertar |
| Start / Select | Duas linguetas abaixo da moldura |
| Ombros L / R | Blocos acima do corpo |
| Grade do alto-falante | 6 sulcos verticais |
| LED | Verde, à esquerda |

**Os botões respondem ao jogo.** A profundidade de cada botão é calculada a partir
da pressão do botão correspondente, interpolada quadro a quadro:

```c
p = g_press[8];  box(92, -2, 0, 106, 12, 4 - 1.6f * p, 0xd0305a);   /* A */
p = g_press[0];  box(74, -14, 0, 88, 0, 4 - 1.6f * p, 0xe0a030);     /* B */
```

Com a pressão vinda de `retro_get_input_state`, suavizada a 60% por quadro:

```c
float t = g_state(0, 1, 0, (unsigned)i) ? 1.0f : 0.0f;
g_press[i] += (t - g_press[i]) * 0.6f;
```

Ou seja: **quando você aperta A no controle, o botão A afunda na carcaça 3D.**

---

## Controles extras

| Controle | Ação |
|---|---|
| **Analógico direito** | Gira a câmera (yaw ±55°, pitch −8° a 68°, zona morta de 18%) |
| **L3** | Alterna entre voxel e plano |
| **R3** | Reseta a câmera (yaw 0, pitch 30°) |

A entrada é lida pelo wrapper (`g_state`), **não** repassada ao core interno — por
isso os botões do jogo não são afetados pela câmera.

---

## Compilando

### Termux (Android)

```sh
sh build_termux.sh
```

```sh
clang -shared -fPIC -O3 -ffast-math -fvisibility=hidden \
    -o retro8_voxel_libretro_android.so retro8_voxel.c -lm -ldl
```

### NDK (Linux/macOS)

```sh
NDK=/caminho/do/android-ndk ./build_android.sh
```

```sh
$CC -shared -fPIC -O3 -ffast-math -fvisibility=hidden -Wl,-z,max-page-size=16384 \
    -o retro8_voxel_libretro_android.so retro8_voxel.c -lm -ldl
```

> **`-ldl` é obrigatório** — o wrapper usa `dlopen()`/`dlsym()` para carregar o core
> interno. Sem ele o binário compila mas falha em tempo de execução.

### GitHub Actions

O workflow `build-android.yml` (publicado ao lado, fora de `.github/workflows/`)
compila o `.so` arm64 no runner e sobe como artefato. Para ativá-lo, mova o arquivo
para `.github/workflows/build-android.yml` e dê um push.

> O workflow não fica em `.github/workflows/` porque a ferramenta de publicação
> usada naquele momento bloqueia escrita nesse caminho (proteção contra CI
> malicioso). Ele está pronto para ser movido com um clique.

### Teste no PC

O repositório publicado traz um harness de teste que não precisa de emulador:

```sh
sh test/run_host_test.sh [quadros] [stick_x] [stick_y] [botoes]
```

Ele carrega um core PICO-8 falso, roda a cena e gera um `out.ppm`.

---

## Instalação

O ponto crítico: **os dois arquivos precisam estar na mesma pasta**.

```
cores/
├── retro8_voxel_libretro.so       ← o wrapper
└── retro8_libretro.so             ← o core PICO-8 original
```

No Android, o arquivo do core original se chama `retro8_libretro_android.so`.
**Não renomeie o original.**

Se o core interno não for encontrado, o wrapper envia esta mensagem ao frontend
(via `RETRO_ENVIRONMENT_SET_MESSAGE`, 6 segundos na tela):

> `Retro8 Voxel: coloque retro8_libretro_android.so na mesma pasta de cores`

(a versão mais nova usa a redação: *"coloque o core retro8 original na mesma pasta do
core voxel"*).

---

## Opções

A versão nova do binário tem 15 opções, todas prefixadas com `r8v_`. A referência
completa está em [OPCOES.md](OPCOES.md).

| Chave | Descrição |
|---|---|
| `r8v_modo` | Modo de renderização |
| `r8v_altura` | Altura dos voxels |
| `r8v_fonte` | Altura calculada por |
| `r8v_fundo` | Piso (cor que fica rente) |
| `r8v_inclin` | Inclinação inicial da câmera |
| `r8v_balanco` | Balanço automático da câmera |
| `r8v_analog` | Velocidade do analógico direito |
| `r8v_zoom` | Zoom da câmera |
| `r8v_suaviza` | Suavização das alturas |
| `r8v_luz` | Sombreamento das faces |
| `r8v_carcaca` | Carcaça do videogame |
| `r8v_cor` | Cor da carcaça |
| `r8v_cena` | Fundo da cena |
| `r8v_qualidade` | Qualidade do render (desempenho) |
| `r8v_resolucao` | Resolução da imagem |

> **Origem:** o código-fonte dessas opções não está publicado. As listas de valores
> foram extraídas do binário por leitura da tabela de literais; o pareamento entre
> chave e lista foi confirmado pelo posicionamento contíguo das strings.

---

## Estado de teste

| Item | Situação |
|---|---|
| Código-fonte da versão base | ✅ Publicado e legível |
| Build arm64 via CI | ✅ Workflow pronto no repositório `retro8_voxel` |
| Teste no PC com core falso | ✅ `test/run_host_test.sh` disponível |
| Com o retro8 real em aparelho | ⚠️ Não testado |
| Versão nova (com as 15 opções) | ⚠️ Código-fonte não publicado; binário analisado por reverse engineering |
