#!/usr/bin/env bash
# Gera os previews do renderizador voxel SEM precisar do RetroArch.
#
# Compila o voxel.c do patch com -DVOX_TEST, monta uma imagem RGB565 sintetica
# e renderiza alguns modos/cameras, gravando o resultado em PPM.
#
# Uso:  bash tests/run_previews.sh [pasta-de-saida]
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"
SAIDA="${1:-$AQUI/../previews}"
COMMIT=1890c2932234c9d30f4cd3851d02228baae8f09e
TMP="${TMPDIR:-/tmp}/voxel-preview-build"

echo "1/4 clonando o PicoDrive na commit $COMMIT"
rm -rf "$TMP"
git clone -q --recursive https://github.com/libretro/picodrive.git "$TMP"
git -C "$TMP" checkout -q "$COMMIT"
git -C "$TMP" submodule update -q --init --recursive

echo "2/4 aplicando o patch"
git -C "$TMP" apply --whitespace=nowarn "$AQUI/../patches/project-genesis-32x.patch"

echo "3/4 compilando o harness"
cc -O2 -DVOX_TEST \
   -I "$TMP/platform/libretro" \
   -I "$TMP/platform/libretro/libretro-common/include" \
   -o "$TMP/voxel_test" "$AQUI/voxel_test.c" "$TMP/platform/libretro/voxel.c" -lm

echo "4/4 renderizando"
mkdir -p "$SAIDA"
cd "$SAIDA"
"$TMP/voxel_test"

echo
echo "Previews em PPM gerados em: $SAIDA"
echo "Para converter para PNG (opcional):"
for f in *.ppm; do
  [ -e "$f" ] || continue
  echo "  python3 -c \"from PIL import Image; Image.open('$f').save('${f%.ppm}.png')\""
done
