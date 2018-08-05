// https://github.com/prideout/heman/blob/master/src/distance.c

#include <inttypes.h>

const float INF = 1E20;

typedef struct {
    int width, height, nbands;
    float* data;
} heman_image;

#define NEW(t, n) calloc(n, sizeof(t))
#define SDISTFIELD_TEXEL(x, y) (*(sdf->data + y * width + x))
#define COORDFIELD_TEXEL(x, y, c) (*(cf->data + 2 * (y * width + x) + c))

static void edt(float* f, float* d, float* z, uint16_t* w, int n)
{
    int k = 0;
    float s;
    w[0] = 0;
    z[0] = -INF;
    z[1] = +INF;
    for (int q = 1; q < n; ++q) {
        s = ((f[q] + SQR(q)) - (f[w[k]] + SQR(w[k]))) / (2 * q - 2 * w[k]);
        while (s <= z[k]) {
            --k;
            s = ((f[q] + SQR(q)) - (f[w[k]] + SQR(w[k]))) / (2 * q - 2 * w[k]);
        }
        w[++k] = q;
        z[k] = s;
        z[k + 1] = +INF;
    }
    k = 0;
    for (int q = 0; q < n; ++q) {
        while (z[k + 1] < q) {
            ++k;
        }
        d[q] = SQR(q - w[k]) + f[w[k]];
    }
}

static void transform_to_distance(heman_image* sdf)
{
    int width = sdf->width;
    int height = sdf->height;
    int size = width * height;
    float* ff = NEW(float, size);
    float* dd = NEW(float, size);
    float* zz = NEW(float, (height + 1) * (width + 1));
    uint16_t* ww = NEW(uint16_t, size);

#pragma omp parallel for
    for (int x = 0; x < width; ++x) {
        float* f = ff + height * x;
        float* d = dd + height * x;
        float* z = zz + (height + 1) * x;
        uint16_t* w = ww + height * x;
        for (int y = 0; y < height; ++y) {
            f[y] = SDISTFIELD_TEXEL(x, y);
        }
        edt(f, d, z, w, height);
        for (int y = 0; y < height; ++y) {
            SDISTFIELD_TEXEL(x, y) = d[y];
        }
    }

#pragma omp parallel for
    for (int y = 0; y < height; ++y) {
        float* f = ff + width * y;
        float* d = dd + width * y;
        float* z = zz + (width + 1) * y;
        uint16_t* w = ww + width * y;
        for (int x = 0; x < width; ++x) {
            f[x] = SDISTFIELD_TEXEL(x, y);
        }
        edt(f, d, z, w, width);
        for (int x = 0; x < width; ++x) {
            SDISTFIELD_TEXEL(x, y) = d[x];
        }
    }

    free(ff);
    free(dd);
    free(zz);
    free(ww);
}

heman_image* heman_distance_create_df(heman_image* src)
{
    assert(src->nbands == 1 && "Distance field input must have only 1 band.");
    heman_image* positive = heman_image_create(src->width, src->height, 1);
    int size = src->height * src->width;
    float* pptr = positive->data;
    float* sptr = src->data;
    for (int i = 0; i < size; ++i, ++sptr) {
        *pptr++ = *sptr ? 0 : INF;
    }
    transform_to_distance(positive);
    float inv = 1.0f / src->width;
    pptr = positive->data;
    for (int i = 0; i < size; ++i, ++pptr) {
        *pptr = sqrt(*pptr) * inv;
    }
    return positive;
}
