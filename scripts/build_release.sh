#!/usr/bin/env bash
# Monta o pacote de release do Project Voxel.
#
#   bash scripts/build_release.sh            # compila tudo e monta release/
#   bash scripts/build_release.sh --skip-build   # só reempacota o que já existe
#
# Saída: release/project-voxel-v1.0/
#
# Requer: gcc, git, zip. Para o build Windows: x86_64-w64-mingw32-gcc.
#         Para o build Android: NDK (ANDROID_NDK_HOME ou NDK=...).

set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$AQUI/.." && pwd)"
COMMIT=1890c2932234c9d30f4cd3851d02228baae8f09e
VERSAO="v1.0"
OUT="$RAIZ/release/project-voxel-$VERSAO"
BUILD="$RAIZ/release/.build"
SKIP=0
[ "$1" = "--skip-build" ] && SKIP=1

mkdir -p "$BUILD"
cd "$BUILD"

if [ "$SKIP" = "0" ]; then
  echo "==> clonando o PicoDrive na commit $COMMIT"
  rm -rf picodrive
  git clone -q --recursive https://github.com/libretro/picodrive.git picodrive
  git -C picodrive checkout -q "$COMMIT"
  git -C picodrive submodule update -q --init --recursive

  echo "==> aplicando o patch"
  git -C picodrive apply --whitespace=nowarn "$RAIZ/patches/project-genesis-32x.patch"

  echo "==> build Linux x86_64"
  make -C picodrive -f Makefile.libretro -j"$(nproc)" >/dev/null
  cp picodrive/project_genesis_32x_libretro.so ./project_genesis_32x_libretro_linux_x86_64.so

  echo "==> build Windows x86_64"
  if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
    make -C picodrive -f Makefile.libretro platform=win -j"$(nproc)" >/dev/null
    cp picodrive/project_genesis_32x_libretro.dll ./project_genesis_32x_libretro.dll
  else
    echo "    x86_64-w64-mingw32-gcc ausente — pulando a DLL"
  fi

  echo "==> build Android arm64"
  NDK="${ANDROID_NDK_HOME:-${NDK:-}}"
  if [ -z "$NDK" ] || [ ! -d "$NDK" ]; then
    NDK="$(ls -d /usr/local/lib/android/sdk/ndk/* /opt/android-ndk-* "$RAIZ"/toolchain/android-ndk-* 2>/dev/null | sort -V | tail -1 || true)"
  fi
  if [ -n "$NDK" ] && [ -d "$NDK" ]; then
    CC="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android24-clang"
    make -C picodrive -f Makefile.libretro platform=aarch64 CC="$CC" -j"$(nproc)" >/dev/null
    cp picodrive/project_genesis_32x_libretro.so ./project_genesis_32x_libretro_android.so
  else
    echo "    NDK ausente — pulando o .so Android (use: NDK=/caminho/ndk bash scripts/build_release.sh)"
  fi
fi

echo "==> montando o pacote"
rm -rf "$OUT"
mkdir -p "$OUT"
cp "$BUILD"/*.so "$BUILD"/*.dll "$OUT"/ 2>/dev/null || true
cp "$RAIZ/cores/project_genesis_32x_libretro_android.info" "$OUT"/
cp "$RAIZ/patches/project-genesis-32x.patch" "$OUT"/
cp "$RAIZ/scripts/build_termux_32x.sh" "$OUT"/
cp "$RAIZ/LEIA-ME.txt" "$OUT"/ 2>/dev/null || true
cp "$RAIZ/docs/RELEASE-NOTES-$VERSAO.md" "$OUT"/RELEASE-NOTES.md 2>/dev/null || true

# o wrapper do Retro8 vai junto: faz parte do mesmo projeto
if [ -f "$RAIZ/release/retro8_voxel_libretro.so" ]; then
  cp "$RAIZ/release/retro8_voxel_libretro.so" "$OUT"/
fi

echo "==> checksums"
( cd "$OUT" && sha256sum * > SHA256SUMS.txt )

echo
echo "Pacote pronto em: $OUT"
ls -la "$OUT"
