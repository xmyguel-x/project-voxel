#!/data/data/com.termux/files/usr/bin/env bash
# Compila o core "Project Genesis 32X" (PicoDrive + voxel) no Termux ou em qualquer Linux.
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"
COMMIT=1890c2932234c9d30f4cd3851d02228baae8f09e
if command -v pkg >/dev/null 2>&1; then pkg install -y git clang make; fi
cd "$AQUI"
rm -rf picodrive
git clone --recursive https://github.com/libretro/picodrive.git picodrive
cd picodrive
git checkout "$COMMIT"
git submodule update --init --recursive
git apply --whitespace=nowarn "$AQUI/../patches/project-genesis-32x.patch"
PLAT=""
[ "$(uname -m)" = "aarch64" ] && PLAT="platform=aarch64"
make -f Makefile.libretro $PLAT -j"$(nproc 2>/dev/null || echo 4)"
cp project_genesis_32x_libretro.so "$AQUI/project_genesis_32x_libretro_android.so"
echo; echo "Pronto: $AQUI/project_genesis_32x_libretro_android.so"
