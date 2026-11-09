// SPDX-License-Identifier: MIT
// layertest: draws offscreen through CGL and NSOpenGLContext, in a core and a legacy context, from two threads, and prints a
// hash of the pixels. Run it alone and with DYLD_INSERT_LIBRARIES=libcglzink.dylib: the hashes must agree.
#define GL_SILENCE_DEPRECATION
#import <AppKit/AppKit.h>
#include <OpenGL/OpenGL.h>
#include <OpenGL/CGLContext.h>
#include <OpenGL/gl.h>
#include <OpenGL/glext.h>
#include <math.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
static uint64_t fnv(const GLubyte *p, int n) { uint64_t h = 1469598103934665603ull; for (int i = 0; i < n; i++) h = (h ^ p[i]) * 1099511628211ull; return h; }
static const char *VS = "#version 120\nvarying vec2 uv; void main(){ uv = gl_MultiTexCoord0.xy; gl_Position = gl_Vertex; }\n";
static const char *FS = "#version 120\nvarying vec2 uv; uniform vec4 k; void main(){ gl_FragColor = vec4(uv, 0.25, 1.0) * k; }\n";
// The ARB handle entry points: pointer-sized handles on macOS, GLuint in the backend.
static uint64_t legacy_arb(void) {
    GLhandleARB v = glCreateShaderObjectARB(GL_VERTEX_SHADER_ARB), f = glCreateShaderObjectARB(GL_FRAGMENT_SHADER_ARB), p = glCreateProgramObjectARB();
    glShaderSourceARB(v, 1, &VS, 0); glCompileShaderARB(v); glShaderSourceARB(f, 1, &FS, 0); glCompileShaderARB(f);
    glAttachObjectARB(p, v); glAttachObjectARB(p, f); glLinkProgramARB(p);
    GLint ok = 0; glGetObjectParameterivARB(p, GL_OBJECT_LINK_STATUS_ARB, &ok); if (!ok) printf("link failed\n");
    GLhandleARB got[4] = {0}; GLsizei n = 0; glGetAttachedObjectsARB(p, 4, &n, got);
    printf("attached %d (%s)\n", n, n == 2 && ((got[0] == v && got[1] == f) || (got[0] == f && got[1] == v)) ? "same handles" : "DIFFERENT handles");
    GLuint fbo, rb; glGenFramebuffersEXT(1, &fbo); glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, fbo);
    glGenRenderbuffersEXT(1, &rb); glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, rb); glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_RGBA8, 32, 32);
    glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_RENDERBUFFER_EXT, rb);
    glViewport(0, 0, 32, 32); glClearColor(0.25f, 0.5f, 0.75f, 1); glClear(GL_COLOR_BUFFER_BIT);
    glUseProgramObjectARB(p); glUniform4fARB(glGetUniformLocationARB(p, "k"), 1, 0.5f, 1, 1);
    glBegin(GL_TRIANGLES); glTexCoord2f(0, 0); glVertex2f(-1, -1); glTexCoord2f(1, 0); glVertex2f(3, -1); glTexCoord2f(0, 1); glVertex2f(-1, 3); glEnd();
    glFinish(); static GLubyte px[32 * 32 * 4]; glReadPixels(0, 0, 32, 32, GL_RGBA, GL_UNSIGNED_BYTE, px);
    if (glGetError()) printf("gl error\n");
    return fnv(px, sizeof px);
}
static uint64_t clear_only(float r) {
    GLuint fbo, rb; glGenFramebuffers(1, &fbo); glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glGenRenderbuffers(1, &rb); glBindRenderbuffer(GL_RENDERBUFFER, rb); glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8, 16, 16);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, rb);
    glViewport(0, 0, 16, 16); glClearColor(r, 0.5f, 0.25f, 1); glClear(GL_COLOR_BUFFER_BIT); glFinish();
    static __thread GLubyte px[16 * 16 * 4]; glReadPixels(0, 0, 16, 16, GL_RGBA, GL_UNSIGNED_BYTE, px);
    return fnv(px, sizeof px);
}
static CGLContextObj g_core;
static uint64_t g_thread_hash;
static void *other_thread(void *a) { CGLSetCurrentContext(g_core); g_thread_hash = clear_only(0.75f); CGLSetCurrentContext(NULL); return 0; }
int main(void) { @autoreleasepool {
    // CGL, core profile
    CGLPixelFormatAttribute a3[] = { kCGLPFAAccelerated, kCGLPFAOpenGLProfile, (CGLPixelFormatAttribute)kCGLOGLPVersion_GL3_Core, 0 };
    CGLPixelFormatObj pf; GLint np; CGLChoosePixelFormat(a3, &pf, &np);
    CGLCreateContext(pf, NULL, &g_core); CGLSetCurrentContext(g_core);
    printf("cgl core  %016llx\n", clear_only(0.25f));
    CGLFlushDrawable(g_core);
    CGLSetCurrentContext(NULL);
    pthread_t t; pthread_create(&t, 0, other_thread, 0); pthread_join(t, 0);
    printf("thread    %016llx\n", g_thread_hash);
    // NSOpenGLContext, legacy profile, with the ARB handle functions
    // Double-buffered: a window has no front-buffer drawing any more, and a single-buffered context stays black.
    NSOpenGLPixelFormatAttribute na[] = { NSOpenGLPFAAccelerated, NSOpenGLPFADoubleBuffer, 0 };
    NSOpenGLPixelFormat *format = [[NSOpenGLPixelFormat alloc] initWithAttributes:na];
    NSOpenGLContext *ns = [[NSOpenGLContext alloc] initWithFormat:format shareContext:nil];
    [ns makeCurrentContext];
    printf("nsgl arb  %016llx\n", legacy_arb());
    [ns flushBuffer];
    GLint i = 1; [ns setValues:&i forParameter:NSOpenGLContextParameterSwapInterval];
    // A real window, when asked: a triangle over a changing colour for LAYERTEST_WINDOW seconds, and the frame rate.
    if (getenv("LAYERTEST_WINDOW")) {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        double x = getenv("LAYERTEST_X") ? atof(getenv("LAYERTEST_X")) : 200;
        NSWindow *w = [[NSWindow alloc] initWithContentRect:NSMakeRect(x, 300, 480, 320) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
        w.title = getenv("LAYERTEST_TITLE") ? @(getenv("LAYERTEST_TITLE")) : @"cglzink test";
        [w makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
        [ns setView:w.contentView]; [ns update]; [ns makeCurrentContext];
        GLint interval = getenv("LAYERTEST_INTERVAL") ? atoi(getenv("LAYERTEST_INTERVAL")) : 0;
        [ns setValues:&interval forParameter:NSOpenGLContextParameterSwapInterval];
        printf("scale %.1f, view %.0fx%.0f, interval %d\n", w.backingScaleFactor, w.contentView.bounds.size.width, w.contentView.bounds.size.height, interval);
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0); glUseProgramObjectARB(0);
        double seconds = atof(getenv("LAYERTEST_WINDOW")), start = CFAbsoluteTimeGetCurrent(), t = 0; long frames = 0;
        printf("renderer %s | %s\n", glGetString(GL_RENDERER), glGetString(GL_VERSION));
        while ((t = CFAbsoluteTimeGetCurrent() - start) < seconds) {
            @autoreleasepool {
                NSEvent *e; while ((e = [NSApp nextEventMatchingMask:NSEventMaskAny untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES])) [NSApp sendEvent:e];
                glViewport(0, 0, (GLsizei)w.contentView.bounds.size.width, (GLsizei)w.contentView.bounds.size.height);
                glClearColor(0.5f + 0.5f * sin(t), 0.2f, 0.5f - 0.5f * sin(t), 1); glClear(GL_COLOR_BUFFER_BIT);
                glBegin(GL_TRIANGLES); glColor3f(1, 0, 0); glVertex2f(-0.6f, -0.6f); glColor3f(0, 1, 0); glVertex2f(0.6f, -0.6f); glColor3f(0, 0, 1); glVertex2f(0, 0.7f); glEnd();
                [ns flushBuffer]; frames++;
            }
        }
        printf("window: %ld frames, %.0f fps, gl error 0x%x\n", frames, frames / t, glGetError());
        [ns clearDrawable];
    }
    // CGLMacro.h style: the entry called directly for a context that is not current
    [NSOpenGLContext clearCurrentContext];
    CGLContextObj c = ns.CGLContextObj;
    GLfloat clear[4] = {0};
    c->disp.get_floatv(c->rend, GL_COLOR_CLEAR_VALUE, clear);
    printf("direct    %.2f %.2f %.2f\n", clear[0], clear[1], clear[2]);
    CGLDestroyContext(g_core);
    printf("done\n");
    return 0;
} }
