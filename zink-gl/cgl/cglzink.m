// SPDX-License-Identifier: MIT
// cglzink: a process's Apple OpenGL contexts draw through Mesa's zink instead of Apple's GL engine.
//
// Loaded with DYLD_INSERT_LIBRARIES, into processes chosen by the user. Apple's CGL objects stay (AppKit and the
// application hold them); each adopted context gets an EGL context of its own, and the context's dispatch table, which
// every gl* symbol goes through, is filled with thunks that drop Apple's context argument and call zink.
//
// What the table does not cover is hooked here: making a context current, presenting (CGLFlushDrawable and
// NSOpenGLContext's flushBuffer), attaching a view. Nothing here is required: when EGL cannot be opened, or
// CGLZINK_OFF is set, every context stays on Apple's OpenGL.
//
// Not handled yet, those applications stay on Apple's GL by not loading this: CGLTexImageIOSurface2D, CVOpenGLTexture,
// CAOpenGLLayer, CGLSetPBuffer. See README.md.
#define GL_SILENCE_DEPRECATION
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#include <OpenGL/OpenGL.h>
#include <OpenGL/CGLContext.h>
#include <OpenGL/gl3.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <objc/runtime.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// The few EGL declarations this needs: no EGL headers on a machine that only has the framework.
typedef void *EGLDisplay, *EGLConfig, *EGLContext, *EGLSurface;
typedef int EGLint;
typedef unsigned EGLBoolean;
#define EGL_NONE 0x3038
#define EGL_OPENGL_API 0x30A2
#define EGL_SURFACE_TYPE 0x3033
#define EGL_PBUFFER_BIT 1
#define EGL_WINDOW_BIT 4
#define EGL_RENDERABLE_TYPE 0x3040
#define EGL_OPENGL_BIT 8
#define EGL_RED_SIZE 0x3024
#define EGL_GREEN_SIZE 0x3023
#define EGL_BLUE_SIZE 0x3022
#define EGL_ALPHA_SIZE 0x3021
#define EGL_DEPTH_SIZE 0x3025
#define EGL_STENCIL_SIZE 0x3026
#define EGL_SAMPLES 0x3031
#define EGL_SAMPLE_BUFFERS 0x3032
#define EGL_WIDTH 0x3057
#define EGL_HEIGHT 0x3056
#define EGL_CONTEXT_MAJOR_VERSION 0x3098
#define EGL_CONTEXT_MINOR_VERSION 0x30FB
#define EGL_CONTEXT_OPENGL_PROFILE_MASK 0x30FD
#define EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT 1
#define EGL_CONTEXT_OPENGL_COMPATIBILITY_PROFILE_BIT 2

static struct {
    EGLDisplay (*GetDisplay)(void *);
    EGLBoolean (*Initialize)(EGLDisplay, EGLint *, EGLint *);
    EGLBoolean (*BindAPI)(unsigned);
    EGLBoolean (*ChooseConfig)(EGLDisplay, const EGLint *, EGLConfig *, EGLint, EGLint *);
    EGLContext (*CreateContext)(EGLDisplay, EGLConfig, EGLContext, const EGLint *);
    EGLBoolean (*DestroyContext)(EGLDisplay, EGLContext);
    EGLSurface (*CreateWindowSurface)(EGLDisplay, EGLConfig, void *, const EGLint *);
    EGLSurface (*CreatePbufferSurface)(EGLDisplay, EGLConfig, const EGLint *);
    EGLBoolean (*DestroySurface)(EGLDisplay, EGLSurface);
    EGLBoolean (*MakeCurrent)(EGLDisplay, EGLSurface, EGLSurface, EGLContext);
    EGLBoolean (*SwapBuffers)(EGLDisplay, EGLSurface);
    EGLBoolean (*SwapInterval)(EGLDisplay, EGLint);
    EGLint (*GetError)(void);
    void *(*GetProcAddress)(const char *);
} egl;
static EGLDisplay g_display;
static int g_log;
#define LOG(...) do { if (g_log) { fprintf(stderr, "cglzink: " __VA_ARGS__); fputc('\n', stderr); } } while (0)

// One per adopted context. The list is short (a process has few contexts) and read under its lock only on a change.
typedef struct Adopted {
    struct Adopted *next;
    CGLContextObj cgl;
    GLIContext rend;
    GLIFunctionDispatch apple;
    EGLContext context;
    EGLConfig config;
    EGLSurface offscreen, window;
    CALayer *layer;
    NSView *view;              // not retained, as NSOpenGLContext: Apple's context never hears of it
    unsigned swaps;
    int interval, interval_set;
} Adopted;
static Adopted *g_adopted;
static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;
// The thread's current context, as the thunks and the hooks see it.
static __thread Adopted *t_current;
static __thread GLIContext t_rend;
// Set while this library calls Apple's CGL or EGL itself, so that a backend using CGL is not adopted in its turn.
static __thread int t_inside;

static void bind_rend(GLIContext rend);
#define CGLT_ENTER(c) do { if (__builtin_expect(t_rend != (c), 0)) bind_rend(c); } while (0)
#include "thunks.h"
#include "backend_names.h"
void *cglt_backend[CGLT_N];

// An entry the backend does not have: nothing happens, and what it returns reads as 0. Every entry in the table returns
// void, an integer or a pointer, so one function serves them all.
static uintptr_t missing_entry(void) { return 0; }


static void *open_backend(void) {
    // A sandboxed application cannot read /usr/local, where zink's @rpath and the Vulkan loader's manifests point. With the
    // loader already in the process, dyld answers zink's dlopen by its install name.
    if (!getenv("CGLZINK_EGL")) {
        setenv("VK_ICD_FILENAMES", "/Library/IntelXe/GL/intel_icd.x86_64.json", 0);
        dlopen("/Library/IntelXe/GL/libvulkan.1.dylib", RTLD_NOW | RTLD_GLOBAL);
    }
    const char *path = getenv("CGLZINK_EGL");
    return dlopen(path ? path : "/Library/IntelXe/GL/libEGL.1.dylib", RTLD_NOW | RTLD_LOCAL);
}

// Once, on the first context. Fails soft: g_display stays NULL and nothing is adopted.
static void backend_init(void) {
    if (getenv("CGLZINK_OFF")) return;
    g_log = getenv("CGLZINK_LOG") != NULL;
    t_inside++;
    void *h = open_backend();
    if (!h) { LOG("no EGL: %s", dlerror()); t_inside--; return; }
#define R(name) if (!(*(void **)&egl.name = dlsym(h, "egl" #name))) { LOG("EGL without egl" #name); t_inside--; return; }
    R(GetDisplay) R(Initialize) R(BindAPI) R(ChooseConfig) R(CreateContext) R(DestroyContext) R(CreateWindowSurface)
    R(CreatePbufferSurface) R(DestroySurface) R(MakeCurrent) R(SwapBuffers) R(SwapInterval) R(GetError) R(GetProcAddress)
#undef R
    EGLDisplay display = egl.GetDisplay(NULL);
    EGLint major = 0, minor = 0;
    if (!display || !egl.Initialize(display, &major, &minor) || !egl.BindAPI(EGL_OPENGL_API)) {
        LOG("EGL did not start: 0x%x", egl.GetError());
        t_inside--;
        return;
    }
    int found = 0;
    for (int i = 0; i < CGLT_N; i++) {
        void *entry = cglt_names[i] ? egl.GetProcAddress(cglt_names[i]) : NULL;
        found += entry != NULL;
        cglt_backend[i] = entry ? entry : (void *)missing_entry;
    }
    LOG("EGL %d.%d, %d of %d table entries", major, minor, found, CGLT_N);
    g_display = display;
    t_inside--;
}

static EGLConfig choose_config(CGLPixelFormatObj format) {
    GLint color = 24, alpha = 8, depth = 24, stencil = 8, samples = 0, buffers = 0;
    if (format) {
        CGLDescribePixelFormat(format, 0, kCGLPFAColorSize, &color);
        CGLDescribePixelFormat(format, 0, kCGLPFAAlphaSize, &alpha);
        CGLDescribePixelFormat(format, 0, kCGLPFADepthSize, &depth);
        CGLDescribePixelFormat(format, 0, kCGLPFAStencilSize, &stencil);
        CGLDescribePixelFormat(format, 0, kCGLPFASamples, &samples);
        CGLDescribePixelFormat(format, 0, kCGLPFASampleBuffers, &buffers);
    }
    int per_channel = color >= 30 && color != 32 ? 10 : 8;   // Apple's 32 is 8 bits per channel with alpha
    if (depth > 24) depth = 24;                              // Apple's 32 is floating point; EGL's sizes are minimums and go to 24 here
    const int msaa = buffers > 0 && samples > 1;             // Apple can answer one buffer with zero samples
    // A platform may give window and pbuffer surfaces in different configs: an offscreen context without a pbuffer binds
    // no surface at all.
    const EGLint surfaces[] = { EGL_WINDOW_BIT | EGL_PBUFFER_BIT, EGL_WINDOW_BIT, EGL_PBUFFER_BIT };
    // The macOS platform offers no multisampled config: such a request goes on without MSAA instead of staying on Apple's GL
    for (int ms = msaa; ms >= 0; ms--) {
        for (int i = 0; i < 3; i++) {
            const EGLint wanted[] = {
                EGL_SURFACE_TYPE, surfaces[i], EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
                EGL_RED_SIZE, per_channel, EGL_GREEN_SIZE, per_channel, EGL_BLUE_SIZE, per_channel,
                EGL_ALPHA_SIZE, alpha, EGL_DEPTH_SIZE, depth, EGL_STENCIL_SIZE, stencil,
                EGL_SAMPLE_BUFFERS, ms ? 1 : 0, EGL_SAMPLES, ms ? samples : 0, EGL_NONE };
            EGLConfig config = NULL;
            EGLint n = 0;
            if (egl.ChooseConfig(g_display, wanted, &config, 1, &n) && n > 0) {
                if (msaa && !ms) LOG("no EGL config with %d samples: this context has no MSAA", samples);
                return config;
            }
        }
    }
    LOG("no EGL config for color %d alpha %d depth %d stencil %d buffers %d samples %d", color, alpha, depth, stencil, buffers, samples);
    return NULL;
}

static Adopted *find_cgl(CGLContextObj cgl) {
    pthread_mutex_lock(&g_lock);
    Adopted *a = g_adopted;
    while (a && a->cgl != cgl) a = a->next;
    pthread_mutex_unlock(&g_lock);
    return a;
}

static Adopted *find_rend(GLIContext rend) {
    pthread_mutex_lock(&g_lock);
    Adopted *a = g_adopted;
    while (a && a->rend != rend) a = a->next;
    pthread_mutex_unlock(&g_lock);
    return a;
}

static void adopt(CGLContextObj cgl, CGLPixelFormatObj format, CGLContextObj share) {
    static pthread_once_t once = PTHREAD_ONCE_INIT;
    pthread_once(&once, backend_init);
    if (!g_display || t_inside || find_cgl(cgl)) return;
    t_inside++;
    GLint profile = kCGLOGLPVersion_Legacy;
    if (format) CGLDescribePixelFormat(format, 0, kCGLPFAOpenGLProfile, &profile);
    // The same versions Apple's GL gives for these profiles. zink is newer than all of them.
    const int core = profile != kCGLOGLPVersion_Legacy;
    const EGLint attributes[] = {
        EGL_CONTEXT_MAJOR_VERSION, core ? (profile == kCGLOGLPVersion_GL4_Core ? 4 : 3) : 2,
        EGL_CONTEXT_MINOR_VERSION, core ? (profile == kCGLOGLPVersion_GL4_Core ? 1 : 2) : 1,
        EGL_CONTEXT_OPENGL_PROFILE_MASK,
        core ? EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT : EGL_CONTEXT_OPENGL_COMPATIBILITY_PROFILE_BIT, EGL_NONE };
    Adopted *shared = share ? find_cgl(share) : NULL;
    EGLConfig config = choose_config(format);
    EGLContext context = config ? egl.CreateContext(g_display, config, shared ? shared->context : NULL, attributes) : NULL;
    if (!context) {
        LOG("no EGL context for profile 0x%x (0x%x): this context stays on Apple's OpenGL", profile, egl.GetError());
        t_inside--;
        return;
    }
    const EGLint size[] = { EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE };
    EGLSurface offscreen = egl.CreatePbufferSurface(g_display, config, size);
    Adopted *a = calloc(1, sizeof *a);
    a->cgl = cgl;
    a->rend = cgl->rend;
    a->apple = cgl->disp;
    a->context = context;
    a->config = config;
    a->offscreen = offscreen;
    pthread_mutex_lock(&g_lock);
    a->next = g_adopted;
    g_adopted = a;
    pthread_mutex_unlock(&g_lock);
    memcpy(&cgl->disp, cglt_table, sizeof cglt_table);
    LOG("adopted %p, profile 0x%x", (void *)cgl, profile);
    t_inside--;
}

static void bind_context(Adopted *a) {
    t_inside++;
    if (a) {
        EGLSurface surface = a->window ? a->window : a->offscreen;
        if (!egl.MakeCurrent(g_display, surface, surface, a->context))
            LOG("eglMakeCurrent 0x%x", egl.GetError());
        if (a->interval_set && a->window) egl.SwapInterval(g_display, a->interval);
    } else if (t_current) {
        egl.MakeCurrent(g_display, NULL, NULL, NULL);
    }
    t_current = a;
    t_rend = a ? a->rend : NULL;
    t_inside--;
}

// A table call for a context that is not the thread's current one: the CGLMacro.h style, or another thread's context.
static void bind_rend(GLIContext rend) { bind_context(find_rend(rend)); }

static CGLError my_CGLCreateContext(CGLPixelFormatObj format, CGLContextObj share, CGLContextObj *out) {
    CGLError error = CGLCreateContext(format, share, out);
    if (error == kCGLNoError && out && *out && !t_inside) adopt(*out, format, share);
    return error;
}

static CGLError my_CGLDestroyContext(CGLContextObj cgl) {
    Adopted *a = t_inside ? NULL : find_cgl(cgl);
    if (a) {
        t_inside++;
        if (t_current == a) bind_context(NULL);
        if (a->window) egl.DestroySurface(g_display, a->window);
        if (a->offscreen) egl.DestroySurface(g_display, a->offscreen);
        egl.DestroyContext(g_display, a->context);
        pthread_mutex_lock(&g_lock);
        for (Adopted **p = &g_adopted; *p; p = &(*p)->next) if (*p == a) { *p = a->next; break; }
        pthread_mutex_unlock(&g_lock);
        [a->layer release];
        cgl->disp = a->apple;
        free(a);
        t_inside--;
    }
    return CGLDestroyContext(cgl);
}

static CGLError my_CGLSetCurrentContext(CGLContextObj cgl) {
    CGLError error = CGLSetCurrentContext(cgl);
    if (!t_inside && error == kCGLNoError) {
        Adopted *a = cgl ? find_cgl(cgl) : NULL;
        if (a != t_current) bind_context(a);
    }
    return error;
}

static void present(Adopted *a) {
    if (t_current != a) bind_context(a);
    t_inside++;
    if (a->window) {
        if (!egl.SwapBuffers(g_display, a->window)) LOG("eglSwapBuffers 0x%x", egl.GetError());
        if (++a->swaps <= 2 || !(a->swaps % 256)) LOG("%u swaps of %p", a->swaps, (void *)a);
    } else {
        // No window: as Apple's GL, the swap only flushes.
        static void (*flush)(void);
        if (!flush) flush = (void (*)(void))egl.GetProcAddress("glFlush");
        if (flush) flush();
    }
    t_inside--;
}

static CGLError my_CGLFlushDrawable(CGLContextObj cgl) {
    Adopted *a = t_inside ? NULL : find_cgl(cgl);
    if (!a) return CGLFlushDrawable(cgl);
    present(a);
    return kCGLNoError;
}

static CGLError my_CGLSetParameter(CGLContextObj cgl, CGLContextParameter name, const GLint *value) {
    Adopted *a = t_inside || name != kCGLCPSwapInterval || !value ? NULL : find_cgl(cgl);
    if (a) {
        a->interval = *value;
        a->interval_set = 1;
        if (t_current == a && a->window) { t_inside++; egl.SwapInterval(g_display, *value); t_inside--; }
    }
    return CGLSetParameter(cgl, name, value);
}

// CGLTexImageIOSurface2D is not in the table, and Apple's engine no longer holds this context's textures.
static CGLError my_CGLTexImageIOSurface2D(CGLContextObj cgl, GLenum target, GLenum internal, GLsizei w, GLsizei h,
                                          GLenum format, GLenum type, IOSurfaceRef surface, GLuint plane) {
    if (!t_inside && find_cgl(cgl)) {
        static atomic_flag said;
        if (!atomic_flag_test_and_set(&said))
            fprintf(stderr, "cglzink: CGLTexImageIOSurface2D is not supported through zink; start this application without cglzink\n");
        return kCGLBadContext;
    }
    return CGLTexImageIOSurface2D(cgl, target, internal, w, h, format, type, surface, plane);
}

#define INTERPOSE(replacement, original) \
    __attribute__((used, section("__DATA,__interpose"))) static struct { const void *a, *b; } \
    interpose_##original = { (const void *)replacement, (const void *)original }
INTERPOSE(my_CGLCreateContext, CGLCreateContext);
INTERPOSE(my_CGLDestroyContext, CGLDestroyContext);
INTERPOSE(my_CGLSetCurrentContext, CGLSetCurrentContext);
INTERPOSE(my_CGLFlushDrawable, CGLFlushDrawable);
INTERPOSE(my_CGLSetParameter, CGLSetParameter);
INTERPOSE(my_CGLTexImageIOSurface2D, CGLTexImageIOSurface2D);

// NSOpenGLContext. Its methods may call CGL inside AppKit, where interposing may not reach, so they are hooked as well;
// adopt() and bind_context() do nothing the second time.
static IMP orig_init, orig_initCGL, orig_flush, orig_setView, orig_update, orig_clearDrawable, orig_makeCurrent, orig_clearCurrent;

static void view_layer(Adopted *a, NSView *view) {
    if (view && view == a->view && a->window) return;   // NSOpenGLView sets its view again and again: the surface stays
    LOG("setView %p: %.0fx%.0f", (void *)view, view.bounds.size.width, view.bounds.size.height);
    a->view = view;
    t_inside++;
    if (a->window) {
        if (t_current == a) egl.MakeCurrent(g_display, a->offscreen, a->offscreen, a->context);
        egl.DestroySurface(g_display, a->window);
        a->window = NULL;
    }
    [a->layer removeFromSuperlayer];
    [a->layer release];
    a->layer = nil;
    if (view) {
        // The view presents through a Metal layer of its own, as the EGL platform expects: EGLNativeWindowType is a CALayer.
        CAMetalLayer *layer = [CAMetalLayer layer];
        layer.frame = view.bounds;
        layer.contentsScale = view.window ? view.window.backingScaleFactor : 1.0;
        layer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
        layer.drawableSize = CGSizeMake(view.bounds.size.width * layer.contentsScale, view.bounds.size.height * layer.contentsScale);
        // A sublayer, not view.layer: a view whose layer is set is layer-hosting and AppKit stops calling its drawRect:,
        // which is where an NSOpenGLView draws.
        view.wantsLayer = YES;
        [view.layer addSublayer:layer];
        a->layer = [layer retain];
        a->window = egl.CreateWindowSurface(g_display, a->config, (void *)layer, NULL);
        if (!a->window) LOG("eglCreateWindowSurface 0x%x", egl.GetError());
        if (t_current == a) {
            EGLSurface surface = a->window ? a->window : a->offscreen;
            egl.MakeCurrent(g_display, surface, surface, a->context);
            if (a->interval_set && a->window) egl.SwapInterval(g_display, a->interval);
        }
    }
    t_inside--;
}

static id hook_init(NSOpenGLContext *self, SEL cmd, NSOpenGLPixelFormat *format, NSOpenGLContext *share) {
    id made = ((id (*)(id, SEL, id, id))orig_init)(self, cmd, format, share);
    if (made && !t_inside)
        adopt(((NSOpenGLContext *)made).CGLContextObj, format.CGLPixelFormatObj, share.CGLContextObj);
    return made;
}

static id hook_initCGL(NSOpenGLContext *self, SEL cmd, void *cgl) {
    id made = ((id (*)(id, SEL, void *))orig_initCGL)(self, cmd, cgl);
    if (made && !t_inside) adopt(cgl, CGLGetPixelFormat(cgl), NULL);
    return made;
}

static void hook_flush(NSOpenGLContext *self, SEL cmd) {
    Adopted *a = t_inside ? NULL : find_cgl(self.CGLContextObj);
    if (a) present(a); else ((void (*)(id, SEL))orig_flush)(self, cmd);
}

static void hook_setView(NSOpenGLContext *self, SEL cmd, NSView *view) {
    Adopted *a = t_inside ? NULL : find_cgl(self.CGLContextObj);
    // Apple's context gets no view: it would attach its own surface to the view we hand to EGL.
    if (a) view_layer(a, view); else ((void (*)(id, SEL, id))orig_setView)(self, cmd, view);
}

static void hook_update(NSOpenGLContext *self, SEL cmd) {
    Adopted *a = t_inside ? NULL : find_cgl(self.CGLContextObj);
    if (a) {
        CAMetalLayer *layer = (CAMetalLayer *)a->layer;
        NSView *view = a->view;   // self.view is nil: Apple's context was given none
        if (layer && view) {
            layer.frame = view.bounds;
            layer.contentsScale = view.window ? view.window.backingScaleFactor : layer.contentsScale;
            layer.drawableSize = CGSizeMake(view.bounds.size.width * layer.contentsScale, view.bounds.size.height * layer.contentsScale);
        }
        return;
    }
    ((void (*)(id, SEL))orig_update)(self, cmd);
}

static void hook_clearDrawable(NSOpenGLContext *self, SEL cmd) {
    Adopted *a = t_inside ? NULL : find_cgl(self.CGLContextObj);
    if (a) view_layer(a, nil); else ((void (*)(id, SEL))orig_clearDrawable)(self, cmd);
}

static void hook_makeCurrent(NSOpenGLContext *self, SEL cmd) {
    ((void (*)(id, SEL))orig_makeCurrent)(self, cmd);
    Adopted *a = t_inside ? NULL : find_cgl(self.CGLContextObj);
    if (a != t_current && !t_inside) bind_context(a);
}

static void hook_clearCurrent(id self, SEL cmd) {
    ((void (*)(id, SEL))orig_clearCurrent)(self, cmd);
    if (!t_inside && t_current) bind_context(NULL);
}

static IMP swap(Class c, SEL s, IMP replacement) {
    Method m = class_getInstanceMethod(c, s);
    return m ? method_setImplementation(m, replacement) : NULL;
}

// AppKit may load after this library, so this runs as images arrive and stops at the first image with the class.
static void on_image(const struct mach_header *header, intptr_t slide) {
    static atomic_flag done;
    Class c = objc_getClass("NSOpenGLContext");
    if (!c || atomic_flag_test_and_set(&done)) return;
    orig_init = swap(c, @selector(initWithFormat:shareContext:), (IMP)hook_init);
    orig_initCGL = swap(c, @selector(initWithCGLContextObj:), (IMP)hook_initCGL);
    orig_flush = swap(c, @selector(flushBuffer), (IMP)hook_flush);
    orig_setView = swap(c, @selector(setView:), (IMP)hook_setView);
    orig_update = swap(c, @selector(update), (IMP)hook_update);
    orig_clearDrawable = swap(c, @selector(clearDrawable), (IMP)hook_clearDrawable);
    orig_makeCurrent = swap(c, @selector(makeCurrentContext), (IMP)hook_makeCurrent);
    orig_clearCurrent = method_setImplementation(class_getClassMethod(c, @selector(clearCurrentContext)), (IMP)hook_clearCurrent);
}

__attribute__((constructor)) static void start(void) {
    if (!getenv("CGLZINK_OFF")) _dyld_register_func_for_add_image(on_image);
}
