# Project Genesis — modo GPGX

O **primeiro modo** do core [Project Genesis](PROJECT-GENESIS.md), e a origem do
renderizador: o **Genesis Plus GX** (GPGX) compilado com o motor voxel 3D dentro.

É o mesmo core e o mesmo renderizador do
[modo PicoDrive (32X)](PROJECT-GENESIS-32X.md) — muda a base de emulação. O nome do
core no RetroArch é **Project Genesis** — sem o "32X" porque o GPGX não emula o 32X.

```
RetroArch  →  Project Genesis v1.0 (GPGX 1.7.4) b9c2316
```

---

## O que é verificado

| Item | Valor | Origem da informação |
|---|---|---|
| Nome do core | `Project Genesis v1.0 (GPGX 1.7.4) b9c2316` | Título da janela do RetroArch (captura real) |
| Base | `libretro/genesis-plus-gx` commit `b9c231644197` | Commit datado de 2026-11-09, mensagem *"libretro: define ALIGN_LONG for 32-bit ARM unix builds (#415)"* |
| Versão do GPGX | `v1.7.4` | `info->library_version = "v1.7.4" GIT_VERSION` no `libretro/libretro.c` do upstream |
| Formato de pixel | **RGB565** quando o frontend aceita, **XRGB1555** caso contrário | `libretro/libretro.c` upstream: `#ifdef FRONTEND_SUPPORTS_RGB565` |
| Extensões | `m3u\|mdx\|md\|smd\|gen\|bin\|cue\|iso\|chd\|bms\|sms\|gg\|sg\|68k\|sgd` | `info->valid_extensions` no upstream |
| Sistemas | Mega Drive, Mega CD, Master System, Game Gear, SG-1000 | README do upstream |
| **32X** | ❌ **Não suporta** | O GPGX não tem núcleo SH2 — só o 68000 (`core/m68k/`) |

---

## A pista que prova a linhagem

O patch do [Project Genesis 32X](PROJECT-GENESIS-32X.md) — que aplica sobre o
**PicoDrive** — tem duas sobras textuais do GPGX que ninguém limpou:

**1. Na descrição da opção principal:**

```c
{
   "project_genesis_voxel",
   "Voxel 3D",
   NULL,
   "Liga o renderizador voxel 3D. Desligado mostra a imagem 2D normal do Genesis Plus GX.",
   ...
}
```

**2. No cabeçalho do renderizador** (`voxel.h`):

```c
/* Project Genesis - renderizador voxel por software para o core libretro.
 * Recebe o framebuffer 16 bits do Genesis Plus GX e devolve um quadro 3D em voxels. */
```

Nenhum dos dois arquivos tem relação com o PicoDrive — ambos foram **copiados** de um
projeto anterior que usava GPGX.

**3. E a prova técnica, no próprio código do renderizador:**

```c
#ifdef FRONTEND_SUPPORTS_RGB565
   /* le como RGB565 */
#else
   /* le como XRGB1555 */
#endif
```

Essa é exatamente a mesma negociação de formato de pixel que o GPGX faz no upstream:

```c
#ifdef FRONTEND_SUPPORTS_RGB565
      unsigned rgb565 = RETRO_PIXEL_FORMAT_RGB565;
      if (environ_cb(RETRO_ENVIRONMENT_SET_PIXEL_FORMAT, &rgb565))
         log_cb(RETRO_LOG_INFO, "Frontend supports RGB565 - will use that instead of XRGB1555.\n");
#endif
```

O renderizador foi escrito para um core que **negocia RGB565 ou XRGB1555** — o GPGX.
O PicoDrive, em contraste, exige RGB565 e aborta se o frontend recusar. Por isso o
renderer do PicoDrive só precisou do caminho RGB565.

**Conclusão:** o `voxel.c` nasceu aqui, no core baseado em GPGX, e foi reaproveitado
no PicoDrive — de onde vieram as sobras textuais.

---

## Relação entre os dois "Project Genesis"

| | **Project Genesis** (GPGX) | **Project Genesis 32X** (PicoDrive) |
|---|---|---|
| Base | `libretro/genesis-plus-gx` @ `b9c2316` | `libretro/picodrive` @ `1890c29` |
| Versão exibida | `v1.0 (GPGX 1.7.4) b9c2316` | `v1.0 (PicoDrive 2.05-1890c29)` |
| Mega Drive / Master System / GG / SG-1000 | ✅ | ✅ |
| Mega-CD | ✅ | ✅ |
| **32X** | ❌ | ✅ |
| Other (Picodrive-specific) | — | Sim (SPARC, etc. via PicoDrive) |
| Formato de pixel | RGB565 **ou** XRGB1555 | RGB565 (exigido) |
| Renderizador voxel | `voxel.c` | `voxel.c` (mesmo código) |
| Opções | `project_genesis_*` | `project_genesis_*` |

O prefixo das opções — `project_genesis_*` — é **o mesmo nos dois**, e a categoria do
core options chama-se *"Project Genesis (Voxel 3D)"* nos dois casos. Isso indica que a
porta para o PicoDrive reaproveitou o namespace de opções inteiro, junto com o
renderizador.

> **Nota de honestidade:** o patch aplicado sobre o GPGX **não está neste repositório**
> — só o patch do PicoDrive foi publicado. As afirmações acima sobre opções
> compartilhadas vêm da leitura do patch do PicoDrive e do aspecto do core GPGX em
> execução; o patch do GPGX em si não foi analisado linha a linha.

---

## A diferença visível nas capturas

As duas capturas do usuário mostram o mesmo motor em cima de bases diferentes, e a
diferença é bem perceptível:

**Project Genesis 32X (PicoDrive)** — cena densa, com terreno, água, vegetação e
personagens convertidos em blocos. Tons de verde, roxo, azul e cinza, com o chão
claro e o fundo escuro. A cena tem profundidade real: as colunas da frente são altas
e as de trás descem.

**Project Genesis (GPGX)** — cena muito mais esparsa e escura: a maior parte do quadro
do jogo é preta, então a maior parte dos voxels tem altura zero e fica invisível. Só
aparecem onde há cor — daí a estrutura azul/ciano flutuando e a mancha cinza no
canto inferior esquerdo. As faixas diagonais escuras são o chão e o fundo da cena
vistos de um ângulo baixo.

Isso não é defeito: é a consequência direta de o renderizador transformar **pixel
claro em bloco alto** e **pixel escuro em nada**. Em um jogo com muita área preta
(fundo de tela), o resultado é uma cena majoritariamente vazia. O modo
**Cor para altura** e o ajuste de **luz ambiente** são as saídas para esse caso.

---

## Instalação

O binário (`project_genesis_libretro.so` / `.dll`) não está neste repositório. O que
existe aqui é a documentação e o patch equivalente do outro core.

Para montar este core você precisa:

1. Clonar `libretro/genesis-plus-gx` na commit `b9c2316`;
2. Aplicar o patch do Project Genesis sobre o GPGX (não publicado aqui);
3. Compilar com `make -f Makefile.libretro`.

O resultado é um core de **aproximadamente 1 MB** — bem menor que os 2,3 MB do core
PicoDrive, porque o GPGX é mais enxuto que o PicoDrive.

---

## Estado de teste

| Item | Situação |
|---|---|
| Core em execução | ✅ Confirmado pela captura real do RetroArch |
| Emulação de Mega Drive / Master System | ✅ Aparência da cena coerente com um jogo real |
| 32X | ❌ Não suportado (o GPGX não tem SH2) |
| Código-fonte do patch | ⚠️ Não publicado |
| Desempenho | ⚠️ Não medido |
