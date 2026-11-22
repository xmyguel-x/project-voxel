# Project Genesis 32X

O primeiro core do Project Voxel: um **emulador completo** (PicoDrive) compilado com o
renderizador voxel 3D dentro.

Ele roda **Mega Drive, Mega-CD, Master System e 32X** (além de Game Gear, SG-1000 e
cartuchos 68k), e o quadro 2D de cada jogo é reescrito como uma cena 3D de blocos.

---

## Como foi construído

```
libretro/picodrive @ 1890c2932234c9d30f4cd3851d02228baae8f09e
        │
        │  git apply project-genesis-32x.patch
        ▼
   PicoDrive patcheado
        │
        │  make -f Makefile.libretro
        ▼
 project_genesis_32x_libretro.so
```

O commit é fixo no script de build (`COMMIT=1890c2932234c9d30f4cd3851d02228baae8f09e`)
para que o resultado seja reproduzível: o patch depende da estrutura exata do código
daquele ponto.

**Base:** <https://github.com/libretro/picodrive> — <https://github.com/libretro/picodrive>

---

## O que o patch muda

O patch toca **5 arquivos** e adiciona **2 novos**:

### `Makefile`
Adiciona o objeto do renderizador ao build libretro:

```diff
 ifeq "$(PLATFORM)" "libretro"
  OBJS += platform/libretro/libretro.o
+ OBJS += platform/libretro/voxel.o
```

### `Makefile.libretro`
Muda o nome do artefato gerado:

```diff
-TARGET_NAME := picodrive
+TARGET_NAME := project_genesis_32x
```

### `platform/libretro/voxel.c` e `voxel.h` (novos)
O renderizador 3D — 441 + 23 linhas. Detalhado em
[RENDERIZADOR-VOXEL.md](RENDERIZADOR-VOXEL.md).

### `platform/libretro/libretro.c`
Quatro pontos de integração:

**1. Identidade do core**
```c
info->library_name    = "Project Genesis 32X";
info->library_version = "v1.0 (PicoDrive " VERSION ")";
```

**2. Geometria reservada** — o frontend precisa saber que a saída pode chegar a
960×672 mesmo quando o modo voxel está desligado:
```c
if (info->geometry.max_width  < VOX_MAX_W) info->geometry.max_width  = VOX_MAX_W;  /* 960 */
if (info->geometry.max_height < VOX_MAX_H) info->geometry.max_height = VOX_MAX_H;  /* 672 */
```

**3. Geometria ativa** — com o voxel ligado, a resolução do vídeo passa a ser a do
renderizador 3D, e não a do emulador:
```c
if (vox_enabled()) {
   vox_output_size(&vw, &vh);
   info->geometry.base_width  = vw;
   info->geometry.base_height = vh;
   info->geometry.aspect_ratio = (float)vw / (float)vh;
}
```

**4. O desvio no `retro_run`** — este é o ponto crucial. O framebuffer normal do
PicoDrive é interceptado e devolvido apenas se o renderizador voxel desligar:

```c
if (vox_enabled())
{
   const uint16_t *vf;
   unsigned vw, vh;

   /* analógico direito orbita a câmera; R3 reseta */
   vox_input(input_state_cb(0, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_RIGHT, RETRO_DEVICE_ID_ANALOG_X),
             input_state_cb(0, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_RIGHT, RETRO_DEVICE_ID_ANALOG_Y),
             false);
   if (input_state_cb(0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R3))
      vox_input(0, 0, true);

   vf = vox_render((const uint16_t *)buff, vout_width, vout_height, vout_width * 2);
   if (vf) {
      vox_output_size(&vw, &vh);
      video_cb(vf, vw, vh, vw * 2);
      return;                       /* ← não entrega o frame 2D */
   }
}

video_cb((short *)buff, vout_width, vout_height, vout_width * 2);
```

### `platform/libretro/libretro_core_options.h`
Uma nova **categoria** de opções no menu do core, com 19 opções:

```c
{ "voxel", "Project Genesis (Voxel 3D)", "Modo voxel 3D: transforma cada pixel do jogo em um bloco, com camera, luz, paletas e varios modos." }
```

---

## Sistemas suportados

O Project Genesis 32X é, por baixo, o PicoDrive. Suporta:

| Sistema | Extensão |
|---|---|
| Sega Mega Drive / Genesis | `.bin` `.gen` `.smd` `.md` `.chd` `.cue` `.iso` |
| Sega 32X | `.32x` `.chd` `.cue` `.iso` |
| Sega Mega-CD | `.cue` `.iso` `.chd` |
| Sega Master System | `.sms` |
| Sega Game Gear | `.gg` |
| Sega SG-1000 | `.sg` |
| Cartuchos 68k (Sega) | `.68k` `.pco` |

### BIOS necessárias

- **32X** — `32X_G_BIOS.BIN`, `32X_M_BIOS.BIN` e `32X_S_BIOS.BIN` na pasta `system`
  do RetroArch. O PicoDrive aceita também a BIOS de 68k (`pico_32x.bin`) para o
 processador principal.
- **Mega-CD** — `bios_CD_U.bin` (EUA), `bios_CD_E.bin` (Europa) ou `bios_CD_J.bin`
  (Japão) na pasta `system`.

Sem essas BIOS, os respectivos jogos não inicializam.

---

## Opções

São 19 opções na categoria **Project Genesis (Voxel 3D)**. A referência completa, com
todos os valores e o efeito de cada uma, está em [OPCOES.md](OPCOES.md). As três que
mais importam no dia a dia:

| Opção | Padrão | Para que serve |
|---|---|---|
| **Tamanho do voxel** | `1x (detalhado)` | `2x`/`4x` agrupam pixels e aceleram muito |
| **Resolução de saída** | `1.5x (480x336)` | Menor = mais leve no celular |
| **Voxel 3D** | `Ligado` | Desligado volta ao quadro 2D normal |

---

## Compilando

### Termux (Android)

```bash
bash scripts/build_termux_32x.sh
```

O script instala `git`, `clang` e `make` se preciso, clona o PicoDrive na commit
fixada, aplica o patch, compila e copia o resultado para
`project_genesis_32x_libretro_android.so`.

Em appliances aarch64 ele passa `platform=aarch64` para o Makefile.

### Linux (x86_64)

```bash
git clone --recursive https://github.com/libretro/picodrive.git
cd picodrive
git checkout 1890c2932234c9d30f4cd3851d02228baae8f09e
git submodule update --init --recursive
git apply --whitespace=nowarn /caminho/para/project-genesis-32x.patch
make -f Makefile.libretro -j"$(nproc)"
```

O binário gerado é `project_genesis_32x_libretro.so`.

### Windows

O `.dll` correspondente (`project_genesis_32x_libretro.dll`) precisa ser compilado com
MSVC ou MinGW seguindo o `Makefile` do PicoDrive. **Esta build não foi testada.**

---

## Notas e peculiaridades conhecidas

**1. Textos copiados de outro projeto.** As descrições de duas opções dizem
*"Genesis Plus GX"* — este core é PicoDrive, não Genesis Plus GX. O mesmo acontecer em
`voxel.h`, cujo comentário de cabeçalho fala em *"o framebuffer do Genesis Plus GX"*.

Não é um erro de digitação: é a **marca da origem do renderizador**. O `voxel.c` foi
escrito primeiro para o core **Project Genesis**, baseado em Genesis Plus GX, e depois
reaproveitado aqui — as opções, o namespace `project_genesis_*` e a categoria do core
options vieram junto. A linhagem completa está em
[PROJECT-GENESIS-GPGX.md](PROJECT-GENESIS-GPGX.md).

**2. O modo "Plano" não é uma ausência de blocos.** A altura é 0, mas o renderer
mantém uma espessura mínima de `0.6 × step`. O resultado é uma laje plana e uniforme,
não uma tela vazia.

**3. O buffer de saída é RGB565.** O PicoDrive define `RETRO_PIXEL_FORMAT_RGB565` e
aborta a inicialização se o frontend não aceitar. O renderizador lê e devolve nesse
formato.

**4. Sem z-buffer.** A ordenação das células é uma aproximação por painter's algorithm.
Em cenas muito inclinadas com muitos degraus podem aparecer pequenas sobreposições
incorretas.

**5. A ordem de leitura das células em X e Y é independente.** O `make_order()`
interpola a ordem com um corte em X e outro em Y, o que é uma aproximação — não um
z-buffer exato.

---

## Estado de teste

| Item | Situação |
|---|---|
| Core Linux x86_64 | ✅ Testado com ROM de teste — modos, câmera e paletas funcionando |
| ROMs de 32X | ⚠️ Não testado |
| ROMs de Mega-CD | ⚠️ Não testado |
| Build Android (Termux) | ⚠️ Não testado |
| DLL do Windows | ⚠️ Não testado |
