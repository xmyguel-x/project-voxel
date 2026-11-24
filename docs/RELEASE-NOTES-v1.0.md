# Project Voxel — v1.0

Primeira release pública do **Project Voxel**: cores libretro que reescrevem o quadro 2D
de um emulador como uma cena 3D de voxels.

## O que tem no pacote

### Project Genesis — modo PicoDrive (32X)

Core libretro com o renderizador voxel 3D compilado dentro do **PicoDrive**. Roda
**Mega Drive, Mega-CD, Master System, 32X**, Game Gear e SG-1000.

| Arquivo | Plataforma |
|---|---|
| `project_genesis_32x_libretro_linux_x86_64.so` | Linux x86_64 |
| `project_genesis_32x_libretro.dll` | Windows x86_64 |
| `project_genesis_32x_libretro_android.so` | Android arm64 |
| `project_genesis_32x_libretro_android.info` | arquivo `.info` do RetroArch |

### Retro8 Voxel

Core **wrapper** que carrega o core PICO-8 original com `dlopen()` e desenha o jogo
dentro de uma **carcaça de videogame 3D**, com D-pad, A/B, Start/Select e ombros que
**afundam** quando você aperta.

| Arquivo | Plataforma |
|---|---|
| `retro8_voxel_libretro.so` | Linux x86_64 |

> O wrapper precisa do core original **`retro8_libretro.so`** (ou
> `retro8_libretro_android.so`) **na mesma pasta** de cores.

### Fonte

| Arquivo | O que é |
|---|---|
| `project-genesis-32x.patch` | o patch aplicado sobre o PicoDrive |
| `build_termux_32x.sh` | compila o core direto no Termux (Android) |

## Download

Página de release com os binários, os hashes SHA-256 e o botão de download:

**<https://xmyguel-x.github.io/project-voxel/release.html>**

| Arquivo | Tamanho | SHA-256 |
|---|---|---|
| `project_genesis_32x_libretro.dll` | 2.944.002 B | `db2a7d33e82d3e331a51` |
| `project_genesis_32x_libretro_linux_x86_64.so` | 2.340.392 B | `881c102c435b22fc4c07` |
| `retro8_voxel_libretro.so` | 56.472 B | `8a8ba0486f2182ed1462` |
| `project_genesis_32x_libretro_android.info` | 612 B | `59fc9694ebb532f11151` |
| `project-genesis-32x.patch` | 41.340 B | `0b8e11103329a414634a` |
| `build_termux_32x.sh` | 824 B | `2b1fcf6affbf79a2f75a` |

## Instalação

**Windows** — copie `project_genesis_32x_libretro.dll` para a pasta `cores` do
RetroArch, e o `.info` para a pasta `info`.

**Linux** — copie `project_genesis_32x_libretro_linux_x86_64.so` para a pasta `cores`.

**Android** — copie `project_genesis_32x_libretro_android.so` para a pasta de cores do
RetroArch.

Em qualquer plataforma, o `.info` vai para a pasta `info` — é ele que faz o core
aparecer na lista de sugeridos.

## BIOS

O pacote **não** traz BIOS, por direitos autorais. Coloque-as na pasta `system` do
RetroArch:

- **32X** — `32X_G_BIOS.BIN`, `32X_M_BIOS.BIN`, `32X_S_BIOS.BIN`
- **Mega-CD** — `bios_CD_U.bin` (EUA), `bios_CD_E.bin` (Europa) ou `bios_CD_J.bin` (Japão)

## Controles

- **Analógico direito** — orbita a câmera
- **R3** — reseta a câmera
- No **Retro8 Voxel**: **L3** alterna entre voxel e plano

## Opções

As 21 opções ficam em *Opções do núcleo → Project Genesis (Voxel 3D)*: modo 3D
(relevo, plano, diorama, neon, cor para altura), paleta, câmera, zoom, profundidade,
espaçamento entre voxels, tamanho do voxel, resolução de saída, luz e sombra, e mais
duas de desempenho:

- **Desempenho automatico (HLE)** — mantém os atalhos que não mudam a imagem sempre
  ligados e só reduz o tamanho do voxel quando o 3D está lento. `Equilibrado (10 ms)`,
  `Rapido (6 ms)`, `Qualidade (16 ms)` ou `Desligado`.
- **Quadros do 3D** — desenha o 3D em menos quadros para poupar CPU; o jogo continua a 60.

Dica de desempenho: se o core ficar lento no celular, reduza **Tamanho do voxel** para
`2x` ou `4x` — é a alavanca de maior impacto, porque o custo é proporcional ao número
de células. Com o *Desempenho automatico* ligado, o core faz isso sozinho.

## Compilando do zero

```bash
git clone --recursive https://github.com/libretro/picodrive.git
cd picodrive
git checkout 1890c2932234c9d30f4cd3851d02228baae8f09e
git submodule update --init --recursive
git apply --whitespace=nowarn /caminho/para/project-genesis-32x.patch
make -f Makefile.libretro -j"$(nproc)"
```

No Termux (Android), use o `build_termux_32x.sh` incluído.

## Checksums

`SHA256SUMS.txt` traz o hash de cada arquivo do pacote:

```bash
sha256sum -c SHA256SUMS.txt
```

Os hashes desta release:

```
db2a7d33e82d3e331a511dd49702c7227e591a3c3c111224ab4f5bae44cb7190  project_genesis_32x_libretro.dll
881c102c435b22fc4c076fd4641444a06ee1512bd9fc8694fd0be0bb66aa8ddf  project_genesis_32x_libretro_linux_x86_64.so
8a8ba0486f2182ed1462e081e35cbadbadb8478bf5f0fe4fd269d5ba457fa884  retro8_voxel_libretro.so
59fc9694ebb532f111516eba5b00efadd792d3fd98b9371da7687313a7a986bc  project_genesis_32x_libretro_android.info
0b8e11103329a414634af8615834075a7fb98ccf3fe9af421650d69ab7b3828e  project-genesis-32x.patch
2b1fcf6affbf79a2f75ab0f382a504a682aa308f5b0fb6a452844f80275cbf61  build_termux_32x.sh
```

## Mais informação

- Documentação completa: <https://github.com/xmyguel-x/project-voxel>
- Código do wrapper Retro8 Voxel: <https://github.com/xmyguel-x/retro8_voxel>

## Créditos

- **PicoDrive** — <https://github.com/libretro/picodrive> — notaz, irixxxx e a comunidade
- **Genesis Plus GX** — <https://github.com/libretro/genesis-plus-gx>
- **Retro8 (PICO-8)** — <https://github.com/libretro/retro8>
- Renderizador voxel, patches e wrapper: **xMyguel_x**
