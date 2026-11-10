// SPDX-License-Identifier: MIT
// fcequiv <dylib> <ll> <stage> <outprefix> <idx:size:hex>...: the whole translation of a variant (nvmtl_translate_fc) and the
// plugin's fc-spec path (nvmtl_fc_structural + nvmtl_translate_fc_spec2, then the values frozen in as the plugin does,
// nvmtl_spec_fc.h). Writes <outprefix>-whole.spv and <outprefix>-frozen.spv.
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "nvmtl_spec_fc.h"
typedef int (*fc_fn)(const char *, const char *, const uint32_t *, const uint32_t *, const uint8_t *const *, size_t, uint8_t **, size_t *, char *, size_t);
typedef int (*st_fn)(const char *, uint8_t **, size_t *, char *, size_t);
typedef int (*sp_fn)(const char *, const char *, const uint32_t *, const uint32_t *, const uint8_t *const *, size_t, const uint32_t *, size_t, uint32_t *, uint8_t **, size_t *, char *, size_t);
static void wr(const char *pre, const char *suf, const void *d, size_t n) { char p[2048]; snprintf(p, sizeof p, "%s-%s.spv", pre, suf); FILE *f = fopen(p, "wb"); fwrite(d, 1, n, f); fclose(f); }
int main(int argc, char **argv) {
  void *h = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL); if (!h) return 2;
  fc_fn tf = (fc_fn)dlsym(h, "nvmtl_translate_fc"); st_fn fs = (st_fn)dlsym(h, "nvmtl_fc_structural"); sp_fn s2 = (sp_fn)dlsym(h, "nvmtl_translate_fc_spec2");
  void (*caps)(uint32_t) = (void (*)(uint32_t))dlsym(h, "nvmtl_translate_set_caps"); if (caps) caps(7);
  FILE *f = fopen(argv[2], "rb"); fseek(f, 0, SEEK_END); long n = ftell(f); rewind(f); char *ll = malloc(n + 1); fread(ll, 1, n, f); ll[n] = 0; fclose(f);
  uint32_t idx[128], sz[128]; uint8_t *pay[128]; size_t nc = 0;
  for (int a = 5; a < argc && nc < 128; a++) { unsigned i, s; char hex[300] = {0}; if (sscanf(argv[a], "%u:%u:%299s", &i, &s, hex) < 2) continue;
    idx[nc] = i; sz[nc] = s; pay[nc] = calloc(1, s); for (unsigned b = 0; b < s && hex[2*b]; b++) { unsigned v; sscanf(hex + 2*b, "%2x", &v); pay[nc][b] = v; } nc++; }
  uint8_t *o = NULL; size_t ol = 0; char e[2048] = {0};
  if (tf(ll, argv[3], idx, sz, (const uint8_t *const *)pay, nc, &o, &ol, e, sizeof e)) { printf("whole FAILED %s\n", e); return 3; }
  wr(argv[4], "whole", o, ol);
  int structural[512] = {0}; o = NULL; ol = 0;
  if (fs(ll, &o, &ol, e, sizeof e) == 0) { char *js = strndup((char *)o, ol); for (char *p = js; *p;) { if (*p >= '0' && *p <= '9') { long v = strtol(p, &p, 10); if (v < 512) structural[v] = 1; } else p++; } }
  uint32_t si[128], ss[128]; const uint8_t *sv[128]; size_t sn = 0, cnt = 0; uint32_t count = 0;
  for (size_t k = 0; k < nc; k++) if (structural[idx[k]]) { si[sn] = idx[k]; ss[sn] = sz[k]; sv[sn] = pay[k]; sn++; }
  o = NULL; ol = 0;
  if (s2(ll, argv[3], si, ss, sv, sn, idx, nc, &count, &o, &ol, e, sizeof e)) { printf("spec2 FAILED %s\n", e); return 4; }
  size_t words = 0; unsigned applied = 0;
  uint32_t *w = nvmtl_spec_fc_apply_ex((const uint32_t *)o, ol / 4, idx, sz, (const uint8_t *const *)pay, nc, &words, &applied, 1);
  if (!w) { printf("freeze FAILED\n"); return 5; }
  wr(argv[4], "frozen", w, words * 4);
  printf("ok baked=%zu spec-constants=%u applied=%u\n", sn, count, applied); (void)cnt;
  return 0;
}
