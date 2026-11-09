// SPDX-License-Identifier: MIT
// A test stand-in for Mesa's EGL, for a machine without zink. Each "EGL context" is a hidden Apple context (not current to
// CGL), and the GL functions it hands out call that context's own entries directly. So the layer's plumbing runs for
// real, and pixels can be compared with Apple's GL. Nothing here says anything about zink. Window surfaces only count.
//
// As Mesa's EGL: the current context is per thread, and a context current on one thread cannot be made current on another
// (EGL_BAD_ACCESS). FAKEEGL_ZINK_NAMES=1 refuses the 58 table names zink did not resolve on the B580 (5 Nov 2026), so
// that the layer's replacements for Apple's extensions run. FAKEEGL_ZINK_STRINGS=1 reports zink's version and extensions.
#define GL_SILENCE_DEPRECATION
#include <OpenGL/OpenGL.h>
#include <OpenGL/CGLContext.h>
#include <OpenGL/gl.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef void *EGLDisplay, *EGLConfig, *EGLContext, *EGLSurface;
typedef int EGLint;
static __thread GLIFunctionDispatch *g_fake_table;
static __thread GLIContext g_fake_rend;
static __thread CGLContextObj t_bound;
static __thread EGLint t_error = 0x3000;
#include "fake_backend.h"
#include "backend_names.h"
#define V __attribute__((visibility("default")))
static long g_swaps, g_windows, g_binds, g_gets, g_refused, g_intervals, g_busy;
static int g_interval = -1;
// which thread has which context current
static struct { CGLContextObj c; pthread_t owner; } g_owners[64];
static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;
static const char *zink_lacks[] = {
    "glBindVertexArrayAPPLE", "glBufferParameteriAPPLE", "glDeleteFencesAPPLE", "glDeleteVertexArraysAPPLE", "glDisableVertexAttribAPPLE",
    "glDrawElementArrayAPPLE", "glDrawRangeElementArrayAPPLE", "glElementPointerAPPLE", "glEnableVertexAttribAPPLE", "glFinishFenceAPPLE",
    "glFinishObjectAPPLE", "glFinishRenderAPPLE", "glFlushMappedBufferRangeAPPLE", "glFlushRenderAPPLE", "glFlushVertexArrayRangeAPPLE",
    "glFramebufferTextureFaceEXT", "glGenFencesAPPLE", "glGenVertexArraysAPPLE", "glGetObjectParameterivAPPLE", "glGetTexParameterPointervAPPLE",
    "glGetUniformBufferSizeEXT", "glGetUniformOffsetEXT", "glInsertEventMarkerEXT", "glIsFenceAPPLE", "glIsVertexArrayAPPLE",
    "glIsVertexAttribEnabledAPPLE", "glLabelObjectWithResponsibleProcessAPPLE", "glMapVertexAttrib1dAPPLE", "glMapVertexAttrib1fAPPLE", "glMapVertexAttrib2dAPPLE",
    "glMapVertexAttrib2fAPPLE", "glMultiDrawElementArrayAPPLE", "glMultiDrawElementsIndirectAPPLE", "glMultiDrawRangeElementArrayAPPLE", "glObjectPurgeableAPPLE",
    "glObjectUnpurgeableAPPLE", "glPointSizePointerAPPLE", "glPopGroupMarkerEXT", "glPushGroupMarkerEXT", "glSetFenceAPPLE",
    "glSwapAPPLE", "glTestFenceAPPLE", "glTestObjectAPPLE", "glTextureRangeAPPLE", "glUniformBufferEXT",
    "glVertexArrayParameteriAPPLE", "glVertexArrayRangeAPPLE", "glVertexBlendARB", "glVertexPointSizefAPPLE", "glWeightPointerARB",
    "glWeightbvARB", "glWeightdvARB", "glWeightfvARB", "glWeightivARB", "glWeightsvARB",
    "glWeightubvARB", "glWeightuivARB", "glWeightusvARB",
};
__attribute__((destructor)) static void report(void) {
    fprintf(stderr, "fakeegl: %ld makecurrent (%ld refused: current elsewhere), %ld window surfaces, %ld swaps, %ld swap intervals (last %d), "
            "%ld entries resolved, %ld refused as zink would\n", g_binds, g_busy, g_windows, g_swaps, g_intervals, g_interval, g_gets, g_refused);
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
static int owner_slot(CGLContextObj c) {
    for (int i = 0; i < 64; i++) if (g_owners[i].c == c) return i;
    for (int i = 0; i < 64; i++) if (!g_owners[i].c) { g_owners[i].c = c; g_owners[i].owner = NULL; return i; }
    return -1;
}
V unsigned eglDestroyContext(EGLDisplay d, EGLContext c) {
    pthread_mutex_lock(&g_lock);
    int i = owner_slot(c);
    if (i >= 0) g_owners[i].c = NULL;
    pthread_mutex_unlock(&g_lock);
    if (t_bound == c) { t_bound = NULL; g_fake_table = NULL; g_fake_rend = NULL; }
    CGLDestroyContext(c);
    return 1;
}
V EGLSurface eglCreateWindowSurface(EGLDisplay d, EGLConfig c, void *w, const EGLint *a) { g_windows++; return (void *)2; }
V EGLSurface eglCreatePbufferSurface(EGLDisplay d, EGLConfig c, const EGLint *a) { return (void *)3; }
V unsigned eglDestroySurface(EGLDisplay d, EGLSurface s) { return 1; }
V unsigned eglMakeCurrent(EGLDisplay d, EGLSurface r, EGLSurface s, EGLContext c) {
    pthread_mutex_lock(&g_lock);
    g_binds++;
    int i = c ? owner_slot(c) : -1;
    if (i >= 0 && g_owners[i].owner && !pthread_equal(g_owners[i].owner, pthread_self())) {
        g_busy++;
        pthread_mutex_unlock(&g_lock);
        t_error = 0x3002;   // EGL_BAD_ACCESS; the thread keeps what it had
        return 0;
    }
    if (t_bound) { int j = owner_slot(t_bound); if (j >= 0) g_owners[j].owner = NULL; }
    if (i >= 0) g_owners[i].owner = pthread_self();
    pthread_mutex_unlock(&g_lock);
    t_bound = c;
    g_fake_table = c ? &((CGLContextObj)c)->disp : NULL;
    g_fake_rend = c ? ((CGLContextObj)c)->rend : NULL;
    return 1;
}
V unsigned eglSwapBuffers(EGLDisplay d, EGLSurface s) { g_swaps++; return 1; }
V unsigned eglSwapInterval(EGLDisplay d, EGLint i) { g_intervals++; g_interval = i; return 1; }
V EGLint eglGetError(void) { EGLint e = t_error; t_error = 0x3000; return e; }
// FAKEEGL_ZINK_STRINGS: the version and extensions say what zink says (4.6, GLSL 4.60, one extension Apple does not have,
// GL_ARB_buffer_storage), so that the layer must give the application Apple's again.
#define GL_NUM_EXTENSIONS_ 0x821D
#define GL_MAJOR_VERSION_ 0x821B
#define GL_MINOR_VERSION_ 0x821C
static int fake_core(void) { const char *v = (const char *)g_fake_table->get_string(g_fake_rend, GL_VERSION); return v && v[0] >= '3'; }
static __thread char t_list[32768];
static __thread const char *t_items[1024];
static int fake_extensions(void) {   // Apple's list for the context's profile, then the extra one
    int n = 0;
    t_list[0] = 0;
    if (fake_core()) {
        GLint count = 0; g_fake_table->get_integerv(g_fake_rend, GL_NUM_EXTENSIONS_, &count);
        for (GLint i = 0; i < count && n < 1023; i++) t_items[n++] = (const char *)g_fake_table->get_stringi(g_fake_rend, GL_EXTENSIONS, i);
    } else {
        strlcpy(t_list, (const char *)g_fake_table->get_string(g_fake_rend, GL_EXTENSIONS), sizeof t_list);
        char *save = NULL;
        for (char *t = strtok_r(t_list, " ", &save); t && n < 1023; t = strtok_r(NULL, " ", &save)) t_items[n++] = t;
    }
    t_items[n++] = "GL_ARB_buffer_storage";
    return n;
}
static const GLubyte *zs_GetString(GLenum name) {
    static __thread char joined[32768];
    if (name == GL_VERSION) return (const GLubyte *)(fake_core() ? "4.6 (Core Profile) Mesa 27.0.0-devel" : "4.6 (Compatibility Profile) Mesa 27.0.0-devel");
    if (name == GL_SHADING_LANGUAGE_VERSION) return (const GLubyte *)"4.60";
    if (name == GL_EXTENSIONS && !fake_core()) {
        int n = fake_extensions();
        joined[0] = 0;
        for (int i = 0; i < n; i++) { strlcat(joined, t_items[i], sizeof joined); strlcat(joined, " ", sizeof joined); }
        return (const GLubyte *)joined;
    }
    return g_fake_table->get_string(g_fake_rend, name);
}
static const GLubyte *zs_GetStringi(GLenum name, GLuint index) {
    if (name != GL_EXTENSIONS) return g_fake_table->get_stringi(g_fake_rend, name, index);
    int n = fake_extensions();
    return index < (GLuint)n ? (const GLubyte *)t_items[index] : NULL;
}
static void zs_GetIntegerv(GLenum pname, GLint *v) {
    if (pname == GL_NUM_EXTENSIONS_) { *v = fake_extensions(); return; }
    if (pname == GL_MAJOR_VERSION_) { *v = 4; return; }
    if (pname == GL_MINOR_VERSION_) { *v = 6; return; }
    g_fake_table->get_integerv(g_fake_rend, pname, v);
}
// FAKEEGL_TINT: the clear colour comes out wrong, which shows that the application's GL calls really arrive here.
static void tinted_clear_color(GLfloat r, GLfloat g, GLfloat b, GLfloat a) { g_fake_table->clear_color(g_fake_rend, 1 - r, g, b, a); }
V void *eglGetProcAddress(const char *name) {
    if (getenv("FAKEEGL_TINT") && !strcmp(name, "glClearColor")) return (void *)tinted_clear_color;
    if (getenv("FAKEEGL_ZINK_STRINGS")) {
        if (!strcmp(name, "glGetString")) return (void *)zs_GetString;
        if (!strcmp(name, "glGetStringi")) return (void *)zs_GetStringi;
        if (!strcmp(name, "glGetIntegerv")) return (void *)zs_GetIntegerv;
    }
    if (getenv("FAKEEGL_ZINK_NAMES"))
        for (size_t i = 0; i < sizeof zink_lacks / sizeof *zink_lacks; i++) if (!strcmp(zink_lacks[i], name)) { g_refused++; return NULL; }
    for (int i = 0; i < (int)(sizeof cglt_names / sizeof *cglt_names); i++)
        if (cglt_names[i] && !strcmp(cglt_names[i], name)) { g_gets++; return fake_backs[i]; }
    // core names the layer's replacements use that are not table names here
    return NULL;
}
