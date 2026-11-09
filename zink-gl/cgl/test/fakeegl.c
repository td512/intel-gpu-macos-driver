// SPDX-License-Identifier: MIT
// A test stand-in for Mesa's EGL, for a machine without zink. Each "EGL context" is a hidden Apple context (not current to
// CGL), and the GL functions it hands out call that context's own entries directly. So the layer's plumbing runs for
// real, and pixels can be compared with Apple's GL. Nothing here says anything about zink. Window surfaces only count.
#define GL_SILENCE_DEPRECATION
#include <OpenGL/OpenGL.h>
#include <OpenGL/CGLContext.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef void *EGLDisplay, *EGLConfig, *EGLContext, *EGLSurface;
typedef int EGLint;
static GLIFunctionDispatch *g_fake_table;
static GLIContext g_fake_rend;
#include "fake_backend.h"
#include "backend_names.h"
#define V __attribute__((visibility("default")))
static long g_swaps, g_windows, g_binds, g_gets;
__attribute__((destructor)) static void report(void) {
    fprintf(stderr, "fakeegl: %ld makecurrent, %ld window surfaces, %ld swaps, %ld entries resolved\n", g_binds, g_windows, g_swaps, g_gets);
}
V EGLDisplay eglGetDisplay(void *n) { return (void *)1; }
V unsigned eglInitialize(EGLDisplay d, EGLint *a, EGLint *b) { *a = 1; *b = 5; return 1; }
V unsigned eglBindAPI(unsigned a) { return 1; }
V unsigned eglChooseConfig(EGLDisplay d, const EGLint *w, EGLConfig *c, EGLint n, EGLint *o) { *c = (void *)1; *o = 1; return 1; }
V EGLContext eglCreateContext(EGLDisplay d, EGLConfig c, EGLContext share, const EGLint *a) {
    int major = 2, minor = 1, core = 0;
    for (; a && *a != 0x3038; a += 2) { if (a[0] == 0x3098) major = a[1]; if (a[0] == 0x30FB) minor = a[1]; if (a[0] == 0x30FD) core = a[1] == 1; }
    CGLPixelFormatAttribute at[] = { kCGLPFAAccelerated, kCGLPFAOpenGLProfile,
        (CGLPixelFormatAttribute)(!core ? kCGLOGLPVersion_Legacy : major >= 4 ? kCGLOGLPVersion_GL4_Core : kCGLOGLPVersion_GL3_Core), 0 };
    CGLPixelFormatObj pf; GLint np;
    if (CGLChoosePixelFormat(at, &pf, &np) || !pf) return NULL;
    CGLContextObj made = NULL;
    CGLCreateContext(pf, share, &made);
    CGLReleasePixelFormat(pf);
    return made;
}
V unsigned eglDestroyContext(EGLDisplay d, EGLContext c) { if (c == (void *)g_fake_rend) g_fake_rend = NULL; CGLDestroyContext(c); return 1; }
V EGLSurface eglCreateWindowSurface(EGLDisplay d, EGLConfig c, void *w, const EGLint *a) { g_windows++; return (void *)2; }
V EGLSurface eglCreatePbufferSurface(EGLDisplay d, EGLConfig c, const EGLint *a) { return (void *)3; }
V unsigned eglDestroySurface(EGLDisplay d, EGLSurface s) { return 1; }
V unsigned eglMakeCurrent(EGLDisplay d, EGLSurface r, EGLSurface s, EGLContext c) {
    g_binds++;
    g_fake_table = c ? &((CGLContextObj)c)->disp : NULL;
    g_fake_rend = c ? ((CGLContextObj)c)->rend : NULL;
    return 1;
}
V unsigned eglSwapBuffers(EGLDisplay d, EGLSurface s) { g_swaps++; return 1; }
V unsigned eglSwapInterval(EGLDisplay d, EGLint i) { return 1; }
V EGLint eglGetError(void) { return 0x3000; }
// FAKEEGL_TINT: the clear colour comes out wrong, which shows that the application's GL calls really arrive here.
static void tinted_clear_color(GLfloat r, GLfloat g, GLfloat b, GLfloat a) { g_fake_table->clear_color(g_fake_rend, 1 - r, g, b, a); }
V void *eglGetProcAddress(const char *name) {
    if (getenv("FAKEEGL_TINT") && !strcmp(name, "glClearColor")) return (void *)tinted_clear_color;
    for (int i = 0; i < (int)(sizeof cglt_names / sizeof *cglt_names); i++)
        if (cglt_names[i] && !strcmp(cglt_names[i], name)) { g_gets++; return fake_backs[i]; }
    return NULL;
}
