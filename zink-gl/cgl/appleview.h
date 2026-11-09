// SPDX-License-Identifier: MIT
// appleview.h (included by cglzink.m): what an application asks about its context is answered as Apple's GL answers it.
//
// An application on macOS resolves GL functions from OpenGL.framework, which exports up to 4.1 and Apple's extensions. zink
// says 4.6 with GL_ARB_buffer_storage and the rest: GZDoom 4.14 then took its 4.4 path and called glBufferStorage through
// a NULL pointer (B580, 9 Nov 2026). So, per context, from Apple's own context of the same profile:
//   GL_VERSION, GL_SHADING_LANGUAGE_VERSION   Apple's strings (4.1 / 4.10 core, 2.1 / 1.20 legacy)
//   GL_MAJOR_VERSION, GL_MINOR_VERSION        read from that version
//   GL_EXTENSIONS (string and glGetStringi), GL_NUM_EXTENSIONS
//                                             Apple's list, without what zink lacks, with what appleext.h makes
//   GL_VENDOR                                 zink's if it names Intel, else "Intel Inc." (applications pick paths by it)
//   GL_RENDERER                               zink's (it names the Intel device)
// Nothing here exports gl* symbols, and neither do Mesa's libraries: dlsym finds no 4.2+ function either.

typedef struct AppleView {
    char *version, *glsl;
    int major, minor;
    char **apple;              // Apple's extensions for this profile
    int napple;
    char **ext;                // what the application is told: built at the first query, with the context bound
    int next;
    char *joined;
    int built;
} AppleView;

static const GLubyte *(*z_GetString)(GLenum);
static const GLubyte *(*z_GetStringi)(GLenum, GLuint);
static void (*z_GetIntegerv)(GLenum, GLint *);
static void (*z_GetInteger64v)(GLenum, GLint64 *);
static pthread_mutex_t g_view_lock = PTHREAD_MUTEX_INITIALIZER;

static void view_add(char ***list, int *n, const char *name) {
    if (!(*n & 63)) *list = realloc(*list, (*n + 64) * sizeof **list);
    (*list)[(*n)++] = strdup(name);
}

static void view_split(char ***list, int *n, const char *joined) {
    char *copy = strdup(joined ? joined : ""), *save = NULL;
    for (char *t = strtok_r(copy, " ", &save); t; t = strtok_r(NULL, " ", &save)) view_add(list, n, t);
    free(copy);
}

// From Apple's context (not current: its entries take the context, as CGLMacro.h uses them), before its table is replaced.
static AppleView *view_from_apple(CGLContextObj cgl, int core) {
    AppleView *v = calloc(1, sizeof *v);
    GLIContext r = cgl->rend;
    const char *version = (const char *)cgl->disp.get_string(r, GL_VERSION);
    const char *glsl = (const char *)cgl->disp.get_string(r, GL_SHADING_LANGUAGE_VERSION);
    v->version = strdup(version ? version : core ? "4.1 zink" : "2.1 zink");
    v->glsl = strdup(glsl ? glsl : core ? "4.10" : "1.20");
    if (sscanf(v->version, "%d.%d", &v->major, &v->minor) != 2) { v->major = core ? 4 : 2; v->minor = 1; }
    if (core) {
        GLint n = 0;
        cgl->disp.get_integerv(r, GL_NUM_EXTENSIONS, &n);
        for (GLint i = 0; i < n; i++) {
            const char *e = (const char *)cgl->disp.get_stringi(r, GL_EXTENSIONS, (GLuint)i);
            if (e) view_add(&v->apple, &v->napple, e);
        }
    } else {
        view_split(&v->apple, &v->napple, (const char *)cgl->disp.get_string(r, GL_EXTENSIONS));
    }
    return v;
}

// An extension of Apple's that appleext.h makes from core functions: kept when its function was made.
static int view_made(const char *e) {
    static const struct { const char *ext, *fn; } made[] = {
        { "GL_APPLE_vertex_array_object", "glBindVertexArrayAPPLE" }, { "GL_APPLE_fence", "glSetFenceAPPLE" },
        { "GL_APPLE_element_array", "glDrawElementArrayAPPLE" }, { "GL_APPLE_flush_render", "glSwapAPPLE" },
        { "GL_APPLE_object_purgeable", "glObjectPurgeableAPPLE" }, { "GL_EXT_debug_marker", "glPushGroupMarkerEXT" },
        { "GL_APPLE_flush_buffer_range", NULL },   // its two functions are hints; the data is right without them
    };
    for (size_t i = 0; i < sizeof made / sizeof *made; i++) {
        if (strcmp(e, made[i].ext)) continue;
        if (!made[i].fn) return 1;
        for (int k = 0; k < CGLT_N; k++)
            if (cglt_names[k] && !strcmp(cglt_names[k], made[i].fn)) return cglt_backend[k] != (void *)missing_entry;
    }
    return 0;
}

static void view_build(AppleView *v) {
    pthread_mutex_lock(&g_view_lock);
    if (!v->built) {
        char **zink = NULL;
        int nzink = 0;
        GLint n = 0;
        z_GetIntegerv(GL_NUM_EXTENSIONS, &n);
        for (GLint i = 0; i < n; i++) {
            const char *e = (const char *)z_GetStringi(GL_EXTENSIONS, (GLuint)i);
            if (e) view_add(&zink, &nzink, e);
        }
        if (!nzink) view_split(&zink, &nzink, (const char *)z_GetString(GL_EXTENSIONS));
        size_t length = 1;
        for (int i = 0; i < v->napple; i++) {
            int keep = view_made(v->apple[i]);
            for (int k = 0; k < nzink && !keep; k++) keep = !strcmp(zink[k], v->apple[i]);
            if (keep) { view_add(&v->ext, &v->next, v->apple[i]); length += strlen(v->apple[i]) + 1; }
        }
        v->joined = calloc(1, length);
        for (int i = 0; i < v->next; i++) { strcat(v->joined, v->ext[i]); strcat(v->joined, " "); }
        LOG("extensions: Apple %d, zink %d, told %d", v->napple, nzink, v->next);
        for (int k = 0; k < nzink; k++) free(zink[k]);
        free(zink);
        v->built = 1;
    }
    pthread_mutex_unlock(&g_view_lock);
}

static AppleView *current_view(void);

static const GLubyte *x_GetString(GLenum name) {
    AppleView *v = current_view();
    if (v) {
        switch (name) {
        case GL_VERSION: return (const GLubyte *)v->version;
        case GL_SHADING_LANGUAGE_VERSION: return (const GLubyte *)v->glsl;
        case GL_VENDOR: {
            const char *vendor = (const char *)z_GetString(GL_VENDOR);
            return (const GLubyte *)(vendor && strstr(vendor, "Intel") ? vendor : "Intel Inc.");
        }
        case GL_EXTENSIONS: {
            const GLubyte *zink = z_GetString(GL_EXTENSIONS);   // NULL and GL_INVALID_ENUM in a core context, as Apple's
            if (!zink) return NULL;
            view_build(v);
            return (const GLubyte *)v->joined;
        }
        }
    }
    return z_GetString(name);
}

static const GLubyte *x_GetStringi(GLenum name, GLuint index) {
    AppleView *v = current_view();
    if (v && name == GL_EXTENSIONS) {
        view_build(v);
        if (index < (GLuint)v->next) return (const GLubyte *)v->ext[index];
        return z_GetStringi(name, 0xFFFFFFFFu);   // past the end: GL_INVALID_VALUE from zink
    }
    return z_GetStringi(name, index);
}

static int view_integer(AppleView *v, GLenum pname, GLint64 *out) {
    switch (pname) {
    case GL_MAJOR_VERSION: *out = v->major; return 1;
    case GL_MINOR_VERSION: *out = v->minor; return 1;
    case GL_NUM_EXTENSIONS: view_build(v); *out = v->next; return 1;
    }
    return 0;
}

static void x_GetIntegerv(GLenum pname, GLint *params) {
    z_GetIntegerv(pname, params);
    if (__builtin_expect(pname != GL_MAJOR_VERSION && pname != GL_MINOR_VERSION && pname != GL_NUM_EXTENSIONS, 1)) return;
    AppleView *v = current_view();
    GLint64 value;
    if (v && params && view_integer(v, pname, &value)) *params = (GLint)value;
}

static void x_GetInteger64v(GLenum pname, GLint64 *params) {
    z_GetInteger64v(pname, params);
    AppleView *v = current_view();
    GLint64 value;
    if (v && params && view_integer(v, pname, &value)) *params = value;
}

// After the table is resolved: the four query entries go through the view.
static void view_install(void) {
    static const struct { const char *name; void **original; void *wrapper; } q[] = {
        { "glGetString", (void **)&z_GetString, (void *)x_GetString },
        { "glGetStringi", (void **)&z_GetStringi, (void *)x_GetStringi },
        { "glGetIntegerv", (void **)&z_GetIntegerv, (void *)x_GetIntegerv },
        { "glGetInteger64v", (void **)&z_GetInteger64v, (void *)x_GetInteger64v },
    };
    for (size_t i = 0; i < sizeof q / sizeof *q; i++)
        for (int k = 0; k < CGLT_N; k++)
            if (cglt_names[k] && !strcmp(cglt_names[k], q[i].name) && cglt_backend[k] != (void *)missing_entry) {
                *q[i].original = cglt_backend[k];
                cglt_backend[k] = q[i].wrapper;
            }
    // all four or none: the strings and the numbers must agree
    if (!z_GetString || !z_GetStringi || !z_GetIntegerv || !z_GetInteger64v) {
        for (size_t i = 0; i < sizeof q / sizeof *q; i++)
            for (int k = 0; k < CGLT_N; k++)
                if (cglt_backend[k] == q[i].wrapper) cglt_backend[k] = *q[i].original;
        LOG("version and extension queries are zink's own (a query entry is missing)");
    }
}
