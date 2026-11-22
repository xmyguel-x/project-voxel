/*
 * Harness de teste do renderizador voxel do Project Genesis 32X.
 *
 * Compila voxel.c com -DVOX_TEST e exercita o renderizador fora do RetroArch:
 * monta uma imagem RGB565 sintetica, renderiza em varios modos/cameras e
 * grava previews em PPM.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "libretro.h"
#include "voxel.h"

void vox_test_set(int mode, int cam);

/* ---------- opcoes controladas pelo harness ---------- */
struct opt { const char *key; const char *val; };
static struct opt g_opts[] = {
    { "project_genesis_voxel",       "enabled" },
    { "project_genesis_mode",        "relief"  },
    { "project_genesis_palette",     "original"},
    { "project_genesis_camera",      "iso"     },
    { "project_genesis_zoom",        "100"     },
    { "project_genesis_depth",       "14"      },
    { "project_genesis_gap",         "8"       },
    { "project_genesis_step",        "1"       },
    { "project_genesis_resolution",  "15"      },
    { "project_genesis_light_angle", "45"      },
    { "project_genesis_light",       "100"     },
    { "project_genesis_ambient",     "45"      },
    { "project_genesis_saturation",  "115"     },
    { "project_genesis_contrast",    "100"     },
    { "project_genesis_glow",        "40"      },
    { "project_genesis_scanlines",   "disabled"},
    { "project_genesis_floor",       "enabled" },
    { "project_genesis_background",  "black"   },
    { "project_genesis_stick",       "enabled" },
    { NULL, NULL }
};

static bool env_stub(unsigned cmd, void *data)
{
    if ((cmd & 0xFFFF) == RETRO_ENVIRONMENT_GET_VARIABLE) {
        struct retro_variable *v = (struct retro_variable *)data;
        int i;
        for (i = 0; g_opts[i].key; i++)
            if (!strcmp(g_opts[i].key, v->key)) { v->value = g_opts[i].val; return true; }
        v->value = NULL;
        return false;
    }
    return true;
}

static void set_opt(const char *k, const char *v)
{
    int i;
    for (i = 0; g_opts[i].key; i++)
        if (!strcmp(g_opts[i].key, k)) { g_opts[i].val = v; return; }
}

/* ---------- imagem de teste 320x224 RGB565 ---------- */
static uint16_t pack(int r, int g, int b)
{
    r &= 255; g &= 255; b &= 255;
    return (uint16_t)(((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3));
}

#define TW 320
#define TH 224

static void build_scene(uint16_t *img)
{
    int x, y;
    for (y = 0; y < TH; y++) {
        for (x = 0; x < TW; x++) {
            int r, g, b;
            if (y < 60) {                       /* ceu: gradiente azul */
                r = 20 + y; g = 40 + y * 2; b = 120 + y * 2;
            } else if (y < 78 && x > 235 && x < 275) {   /* sol */
                r = 250; g = 220; b = 80;
            } else if (y >= 150) {              /* chao xadrez */
                int c = (((x / 16) + (y / 16)) & 1);
                r = c ? 70 : 40; g = c ? 140 : 90; b = c ? 60 : 45;
            } else {                            /* colinas */
                int hill = 130 + (int)(30.0 * (1 + 0.8 * (x - 160) / 160.0));
                if (y > hill) { r = 30; g = 120; b = 50; }
                else { r = 20 + y; g = 40 + y * 2; b = 120 + y * 2; }
            }
            /* uma faixa clara para dar contraste */
            if (y > 100 && y < 112 && x > 40 && x < 150) { r = 230; g = 235; b = 240; }
            img[y * TW + x] = pack(r, g, b);
        }
    }
}

static void save_ppm(const char *path, const uint16_t *rgb565, int w, int h)
{
    FILE *f = fopen(path, "wb");
    int x, y;
    if (!f) { fprintf(stderr, "nao abriu %s\n", path); return; }
    fprintf(f, "P6\n%d %d\n255\n", w, h);
    for (y = 0; y < h; y++) {
        for (x = 0; x < w; x++) {
            uint16_t p = rgb565[y * w + x];
            int r = ((p >> 11) & 31) << 3, g = ((p >> 5) & 63) << 2, b = (p & 31) << 3;
            fputc(r, f); fputc(g, f); fputc(b, f);
        }
    }
    fclose(f);
    printf("  -> %s (%dx%d)\n", path, w, h);
}

static void shot(const char *name, const uint16_t *img, int mode_idx, int cam_idx,
                 const char *pal, const char *bg, const char *res)
{
    unsigned vw, vh;
    const uint16_t *out;
    /* modos: relief=0 flat=1 diorama=2 neon=3 colorheight=4 */
    /* cameras: front=0 iso=1 cinema=2 low=3 side=4 orbit=5 */
    set_opt("project_genesis_palette", pal);
    set_opt("project_genesis_background", bg);
    set_opt("project_genesis_resolution", res);
    vox_check_options(env_stub);
    vox_test_set(mode_idx, cam_idx);   /* snap da camera (cam_init = 0) */
    out = vox_render(img, TW, TH, TW * 2);
    if (!out) { printf("  !! vox_render retornou NULL\n"); return; }
    vox_output_size(&vw, &vh);
    save_ppm(name, out, (int)vw, (int)vh);
}

int main(void)
{
    uint16_t *img = malloc(TW * TH * 2);
    build_scene(img);
    printf("renderizando previews:\n");
    shot("preview_relevo_iso.ppm",     img, 0, 1, "original", "navy", "20");
    shot("preview_diorama_low.ppm",    img, 2, 3, "original", "black", "20");
    shot("preview_neon_cinema.ppm",     img, 3, 2, "noir",     "black", "20");
    shot("preview_coraltura_front.ppm", img, 4, 0, "megablue", "gray",  "20");
    free(img);
    return 0;
}
