// SPDX-License-Identifier: MIT
// ep <dylib> <ll> <stage> <outdir> [idx:size:hex ...]: every entry point the plugin calls for one function, outputs to <outdir>/<EP>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
typedef int (*tr_fn)(const char *, const char *, uint8_t **, size_t *, char *, size_t);
typedef int (*fc_fn)(const char *, const char *, const uint32_t *, const uint32_t *, const uint8_t *const *, size_t, uint8_t **, size_t *, char *, size_t);
typedef int (*st_fn)(const char *, uint8_t **, size_t *, char *, size_t);
typedef int (*sp_fn)(const char *, const char *, const uint32_t *, const uint32_t *, const uint8_t *const *, size_t, const uint32_t *, size_t, uint32_t *, uint8_t **, size_t *, char *, size_t);
typedef int (*sm_fn)(const char *, const char *, const char *, uint8_t **, size_t *, char *, size_t);
static const char *OUT;
static void put(const char *ep, int rc, uint8_t *o, size_t ol, const char *e) {
  char p[2048]; snprintf(p, sizeof p, "%s/%s", OUT, ep); FILE *f = fopen(p, "wb");
  if (rc) fprintf(f, "ERROR rc=%d %s\n", rc, e); else fwrite(o, 1, ol, f); fclose(f);
}
int main(int argc, char **argv) {
  void *h = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL); if (!h) { fprintf(stderr, "%s\n", dlerror()); return 2; }
  OUT = argv[4];
  void (*caps)(uint32_t) = (void (*)(uint32_t))dlsym(h, "nvmtl_translate_set_caps"); if (caps) caps(7);
  FILE *f = fopen(argv[2], "rb"); fseek(f, 0, SEEK_END); long n = ftell(f); rewind(f); char *ll = malloc(n + 1); fread(ll, 1, n, f); ll[n] = 0; fclose(f);
  const char *st = argv[3];
  uint32_t idx[64], sz[64]; uint8_t *pay[64]; size_t nc = 0;
  for (int a = 5; a < argc && nc < 64; a++) { unsigned i, s; char hex[300] = {0}; if (sscanf(argv[a], "%u:%u:%299s", &i, &s, hex) < 2) continue;
    idx[nc] = i; sz[nc] = s; pay[nc] = calloc(1, s); for (unsigned b = 0; b < s && hex[2*b]; b++) { unsigned v; sscanf(hex + 2*b, "%2x", &v); pay[nc][b] = v; } nc++; }
  uint8_t *o; size_t ol; char e[4096]; int rc;
#define CALL(EP, expr) do { o = NULL; ol = 0; e[0] = 0; rc = (expr); put(EP, rc, o, ol, e); } while (0)
  tr_fn tr = (tr_fn)dlsym(h, "nvmtl_translate"), rf = (tr_fn)dlsym(h, "nvmtl_reflect");
  st_fn vr = (st_fn)dlsym(h, "nvmtl_visible_refs"), fs = (st_fn)dlsym(h, "nvmtl_fc_structural");
  fc_fn tf = (fc_fn)dlsym(h, "nvmtl_translate_fc"), rff = (fc_fn)dlsym(h, "nvmtl_reflect_fc");
  sp_fn s2 = (sp_fn)dlsym(h, "nvmtl_translate_fc_spec2"); sm_fn sm = (sm_fn)dlsym(h, "nvmtl_translate_samplers");
  CALL("translate", tr(ll, st, &o, &ol, e, sizeof e));
  CALL("reflect", rf(ll, st, &o, &ol, e, sizeof e));
  CALL("visible_refs", vr(ll, &o, &ol, e, sizeof e));
  if (nc) {
    CALL("translate_fc", tf(ll, st, idx, sz, (const uint8_t *const *)pay, nc, &o, &ol, e, sizeof e));
    CALL("reflect_fc", rff(ll, st, idx, sz, (const uint8_t *const *)pay, nc, &o, &ol, e, sizeof e));
    int structural[512] = {0};
    o = NULL; ol = 0; e[0] = 0; rc = fs(ll, &o, &ol, e, sizeof e); put("fc_structural", rc, o, ol, e);
    if (!rc) { char *js = strndup((char *)o, ol); for (char *p = js; *p;) { if (*p >= '0' && *p <= '9') { long v = strtol(p, &p, 10); if (v < 512) structural[v] = 1; } else p++; } }
    uint32_t si[64], ss[64]; const uint8_t *sv[64]; size_t sn = 0; uint32_t cnt = 0;
    for (size_t k = 0; k < nc; k++) if (structural[idx[k]]) { si[sn] = idx[k]; ss[sn] = sz[k]; sv[sn] = pay[k]; sn++; }
    CALL("spec2", s2(ll, st, si, ss, sv, sn, idx, nc, &cnt, &o, &ol, e, sizeof e));
    char js[8192]; int k = snprintf(js, sizeof js, "{\"a8_targets\":0,\"constants\":{");
    for (size_t c = 0; c < nc; c++) { k += snprintf(js + k, sizeof js - k, "%s\"%u\":[", c ? "," : "", idx[c]); for (uint32_t b = 0; b < sz[c]; b++) k += snprintf(js + k, sizeof js - k, "%s%u", b ? "," : "", pay[c][b]); k += snprintf(js + k, sizeof js - k, "]"); }
    snprintf(js + k, sizeof js - k, "},\"samplers\":{\"0\":{\"min_filter\":\"Linear\",\"mag_filter\":\"Linear\",\"mip_filter\":\"None\",\"address_mode_s\":\"ClampToEdge\",\"address_mode_t\":\"ClampToEdge\",\"address_mode_r\":\"ClampToEdge\",\"coordinates\":\"Pixel\",\"compare_function\":\"None\",\"max_anisotropy\":1,\"lod_min_clamp\":0,\"lod_max_clamp\":1000,\"border_color\":\"TransparentBlack\",\"reduction\":\"WeightedAverage\",\"lod_bias\":0}}}");
    CALL("samplers", sm(ll, st, js, &o, &ol, e, sizeof e));
  }
  return 0;
}
