# Previews

Estas imagens foram geradas pelo próprio renderizador do patch, **sem o RetroArch**,
usando o harness em [`../tests/voxel_test.c`](../tests/voxel_test.c).

A cena de teste é sintética (320×224): céu em gradiente, sol, colinas, um chão
xadrez e uma faixa clara — para que dê para ver como cada modo trata cor, altura e
iluminação.

| Preview | Modo | Câmera | Paleta | Fundo |
|---|---|---|---|---|
| `relevo_iso.svg` | Relevo | Isométrica | Original | Azul-marinho |
| `diorama_low.svg` | Diorama | Baixa | Original | Preto |
| `neon_cinema.svg` | Neon | Cinema | Noir | Preto |
| `coraltura_front.svg` | Cor para altura | Frontal | Mega azul | Cinza |

Todas renderizadas em 2x (640×448).

## Por que SVG e não PNG?

A ferramenta de publicação usada para subir este repositório transporta **apenas
texto** — um PNG binário enviado por ela chega corrompido no GitHub.

A solução foi embutir o PNG dentro de um SVG como `data:image/png;base64`, que é
ASCII puro e sobrevive intacto ao transporte de texto:

```xml
<image width="640" height="448" xlink:href="data:image/png;base64,iVBORw0KGgo..."/>
```

Para commitar os PNGs diretamente, basta rodar `tests/run_previews.sh` e fazer
`git add` dos `.png` — o Git aceita binário normalmente.

## Regenerando

```bash
bash tests/run_previews.sh
```

O script clona o PicoDrive na commit correta, aplica o patch, compila o harness
com `-DVOX_TEST` e grava os `.ppm` na pasta de saída. Para converter:

```bash
python3 -c "from PIL import Image; Image.open('preview_relevo_iso.ppm').save('preview_relevo_iso.png')"
```
