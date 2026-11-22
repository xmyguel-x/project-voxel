# Instalação e uso

## Project Genesis 32X

### Windows

1. Copie `project_genesis_32x_libretro.dll` para a pasta `cores` do RetroArch.
2. Copie `project_genesis_32x_libretro_android.info` para a pasta `info` do RetroArch
   — é isso que faz o core aparecer na lista de "sugeridos".

> A DLL do Windows **não foi testada**.

### Linux

1. Copie `project_genesis_32x_libretro_linux_x86_64.so` para a pasta `cores` do
   RetroArch.
2. Copie o `.info` para a pasta `info`.

### Android (Termux)

Em vez de usar um binário pronto, você pode compilar direto no celular:

```bash
bash scripts/build_termux_32x.sh
```

O script:

1. instala `git`, `clang` e `make` (via `pkg install`) se ainda não estiverem lá;
2. clona `https://github.com/libretro/picodrive.git` na commit
   `1890c2932234c9d30f4cd3851d02228baae8f09e`;
3. inicializa os submódulos;
4. aplica `patches/project-genesis-32x.patch`;
5. compila com `make -f Makefile.libretro` (passando `platform=aarch64` em
   appliances aarch64);
6. copia o resultado para `project_genesis_32x_libretro_android.so`.

> O binário gerado é específico da arquitetura do aparelho. Em aparelhos x86_64
> (emuladores) o script detecta pelo `uname -m` e não passa `platform`.

### Compilando no Linux (x86_64)

```bash
git clone --recursive https://github.com/libretro/picodrive.git
cd picodrive
git checkout 1890c2932234c9d30f4cd3851d02228baae8f09e
git submodule update --init --recursive
git apply --whitespace=nowarn /caminho/para/project-voxel/patches/project-genesis-32x.patch
make -f Makefile.libretro -j"$(nproc)"
cp project_genesis_32x_libretro.so /caminho/para/retroarch/cores/
```

---

## Retro8 Voxel

Este core **precisa do core original na mesma pasta**. Sem isso ele nem inicia.

```
cores/
├── retro8_voxel_libretro.so       ← o wrapper (56 KB)
└── retro8_libretro.so             ← o core PICO-8 original
```

No Android, o arquivo do core original se chama `retro8_libretro_android.so`.

O wrapper tenta, nesta ordem, abrir:

1. `retro8_inner_libretro.so`
2. `retro8_libretro.so`
3. `retro8_libretro_android.so`

Se nenhum existir, a mensagem de erro é:

> `Retro8 Voxel: coloque o core retro8 original na mesma pasta do core voxel`

O core original vem do repositório [libretro/retro8](https://github.com/libretro/retro8)
(PICO-8 implementation with SDL2 and RetroArch back-ends), sob a licença própria dele.

---

## BIOS

As BIOS **não** acompanham o projeto por motivos de direitos autorais. Você precisa
descartá-las por conta própria e colocá-las na pasta `system` do RetroArch.

### 32X

| Arquivo | Conteúdo |
|---|---|
| `32X_G_BIOS.BIN` | BIOS do processador principal (Genesis) |
| `32X_M_BIOS.BIN` | BIOS do SH-2 mestre |
| `32X_S_BIOS.BIN` | BIOS do SH-2 escravo |

O PicoDrive também aceita `pico_32x.bin` (BIOS de 68k) para o processador principal.

### Mega-CD

| Arquivo | Região |
|---|---|
| `bios_CD_U.bin` | Estados Unidos |
| `bios_CD_E.bin` | Europa |
| `bios_CD_J.bin` | Japão |

---

## Ajustes recomendados para jogar

Depois de carregar um jogo, abra **Opções do núcleo → Project Genesis (Voxel 3D)**.

### Começando

| Ajuste | Valor sugerido |
|---|---|
| Modo 3D | `Relevo` — é o mais legível |
| Câmera | `Isométrica` — mostra os três eixos |
| Tamanho do voxel | `1x (detalhado)` se o aparelho aguentar, senão `2x` |
| Resolução de saída | `1.5x (480x336)` no celular, `2x (640x448)` no PC |
| Chão | `Ligado` — dá noção de chão |
| Fundo | `Azul-marinho` — separa melhor a silhueta que preto puro |

### Se estiver lento

1. **Tamanho do voxel → `2x`** ou `4x`. É o ganho mais grande: 4× e 16× menos células.
2. **Resolução de saída → `1x (320x224)`**.
3. **Profundidade → 6 ou 8** (menos geometria para rasterizar).
4. **Espaço entre voxels → 0%** (cada bloco a menos é uma face a menos).

### Se a imagem estiver "chapada"

1. **Profundidade → 18 ou 24** — dá mais alcance à altura.
2. **Luz ambiente → 30%** e **intensidade da luz → 150%** — mais contraste entre as faces.
3. **Direção da luz → 315°** ou `135°` — ângulos diagonais mostram melhor os degraus.

### Explorando

- `Diorama` + `Baixa (diorama)` = cena de maquete, vista de cima.
- `Neon` + `Noir` = visual monocromático com bloom.
- `Cor para altura` = o relevo passa a ser definido pela cor, não pelo brilho — resultados
 mais marcantes com jogos de paleta saturada.
- Analógico direito + `R3` = gire a câmera e volte ao início quando travar.

---

## Problemas conhecidos

**"O core não aparece no RetroArch"** — o `.info` precisa estar na pasta `info`. Sem
ele, o core só aparece na busca manual.

**"Retro8 Voxel: coloque o core retro8 original na mesma pasta do core voxel"** — o
wrapper não achou `retro8_libretro.so` (ou `retro8_libretro_android.so`) no mesmo
diretório. Confira as permissões de leitura do arquivo.

**"RGB565 support required, sorry"** — o PicoDrive exige RGB565. Se o frontend (ou um
wrapper externo) só aceitar XRGB8888, o core não sobe. É uma limitação do PicoDrive
original, não do renderizador.

**Cores erradas ou cena invertida** — o framebuffer do emulador precisa estar em
RGB565. Um frontend que force XRGB8888 faz o renderer ler bytes como se fossem
crominance, produzindo cores bizarras.

**Desempenho ruim no celular** — reduza `Tamanho do voxel` primeiro. É a alavanca de
maior impacto.
