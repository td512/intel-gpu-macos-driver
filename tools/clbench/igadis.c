/* igadis <zebin> <outdir>: each kernel's machine code in an Intel GPU binary (zebin, ELF64), disassembled with the
 * driver's own iga64.dll for Xe2 (Battlemage), one .asm per kernel, and a line of counts per kernel on stdout. */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "iga.h"
typedef iga_status_t (*ctx_create_t)(const iga_context_options_t *, iga_context_t *);
typedef iga_status_t (*dis_t)(iga_context_t, const iga_disassemble_options_t *, const void *, uint32_t, const char *(*)(int32_t, void *), void *, char **);
static HMODULE find_iga(void) {
    HMODULE h = LoadLibraryA("iga64.dll"); if (h) return h;
    char pat[MAX_PATH]; WIN32_FIND_DATAA fd; snprintf(pat, sizeof pat, "%s\\System32\\DriverStore\\FileRepository\\iigd_dch.inf_amd64_*", getenv("SystemRoot"));
    HANDLE f = FindFirstFileA(pat, &fd); if (f == INVALID_HANDLE_VALUE) return NULL;
    do { char p[MAX_PATH]; snprintf(p, sizeof p, "%s\\System32\\DriverStore\\FileRepository\\%s\\iga64.dll", getenv("SystemRoot"), fd.cFileName);
         if ((h = LoadLibraryA(p))) { printf("iga: %s\n", p); break; } } while (FindNextFileA(f, &fd));
    FindClose(f); return h;
}
int main(int argc, char **argv) {
    if (argc < 3) { printf("usage: igadis <zebin> <outdir>\n"); return 2; }
    FILE *f = fopen(argv[1], "rb"); if (!f) { printf("cannot open %s\n", argv[1]); return 1; }
    fseek(f, 0, SEEK_END); long n = ftell(f); rewind(f); unsigned char *b = malloc(n); fread(b, 1, n, f); fclose(f);
    if (n < 64 || memcmp(b, "\x7f" "ELF", 4) || b[4] != 2) { printf("not an ELF64 file\n"); return 1; }
    uint64_t shoff; uint16_t shentsize, shnum, shstrndx; memcpy(&shoff, b + 0x28, 8); memcpy(&shentsize, b + 0x3a, 2); memcpy(&shnum, b + 0x3c, 2); memcpy(&shstrndx, b + 0x3e, 2);
    const unsigned char *sh = b + shoff; uint64_t stroff; memcpy(&stroff, sh + shstrndx * shentsize + 0x18, 8);
    HMODULE h = find_iga(); if (!h) { printf("iga64.dll not found\n"); return 1; }
    ctx_create_t cc = (ctx_create_t)(void *)GetProcAddress(h, "iga_context_create"); dis_t dis = (dis_t)(void *)GetProcAddress(h, "iga_context_disassemble");
    if (!cc || !dis) { printf("iga entry points missing\n"); return 1; }
    iga_context_options_t co = IGA_CONTEXT_OPTIONS_INIT(IGA_XE2); iga_context_t ctx;
    if (cc(&co, &ctx) != IGA_SUCCESS) { printf("iga context for Xe2 failed\n"); return 1; }
    iga_disassemble_options_t dopt = IGA_DISASSEMBLE_OPTIONS_INIT_NUMERIC_LABELS();
    for (int i = 0; i < shnum; i++) {
        const unsigned char *s = sh + i * shentsize; uint32_t nm; uint64_t off, size; memcpy(&nm, s, 4); memcpy(&off, s + 0x18, 8); memcpy(&size, s + 0x20, 8);
        const char *name = (const char *)b + stroff + nm;
        if (strncmp(name, ".text.", 6) || !size) continue;
        char *txt = NULL; iga_status_t st = dis(ctx, &dopt, b + off, (uint32_t)size, NULL, NULL, &txt);
        char path[1024]; snprintf(path, sizeof path, "%s\\%s.asm", argv[2], name + 6);
        FILE *o = fopen(path, "w"); if (o && txt) fputs(txt, o); if (o) fclose(o);
        int ins = 0, sends = 0, sync = 0, spill = 0; const char *p = txt;
        while (p && *p) { const char *e = strchr(p, '\n'); size_t l = e ? (size_t)(e - p) : strlen(p);
            char line[512]; size_t c = l < sizeof line - 1 ? l : sizeof line - 1; memcpy(line, p, c); line[c] = 0;
            const char *q = line; while (*q == ' ') q++;
            if (*q && *q != '/' && !(q[0] == 'L' && strchr(q, ':'))) { ins++; if (strstr(q, "send")) sends++; if (strstr(q, "sync")) sync++; if (strstr(q, "scratch")) spill++; }
            p = e ? e + 1 : NULL; }
        printf("%-16s %6llu bytes  %4d instructions  %3d sends  %2d syncs  %d scratch  (status %d)\n", name + 6, (unsigned long long)size, ins, sends, sync, spill, (int)st);
    }
    return 0;
}
