// SPDX-License-Identifier: MIT
// appleext.h (included by cglzink.m): Apple's own GL extensions that zink does not have, made from core functions.
//
// zink resolves 906 of the 975 entries of Apple's table (B580, 5 Nov 2026). Of the rest, applications written for the
// Mac call some without checking the extension string, because every Mac had them: GL_APPLE_vertex_array_object above
// all (the only VAO a 2.1 context on macOS has), GL_APPLE_fence, GL_APPLE_flush_render, GL_APPLE_element_array. Those
// get an implementation here; Apple's hints (texture range, vertex array range, buffer flushing) stay no-ops, which is
// correct: zink keeps the data coherent without them.

static void *core(const char *name) { return egl.GetProcAddress(name); }

// GL_APPLE_fence on GL 3.2 sync objects. Fence names are global to the process here, not per share group: they are
// only handed out by glGenFencesAPPLE, so two contexts never meet the same name.
static struct {
    pthread_mutex_t lock;
    GLsync *sync;
    unsigned char *used;
    GLuint size, next;
} fences = { PTHREAD_MUTEX_INITIALIZER, NULL, NULL, 0, 1 };
static GLsync (*p_FenceSync)(GLenum, GLbitfield);
static GLenum (*p_ClientWaitSync)(GLsync, GLbitfield, GLuint64);
static void (*p_DeleteSync)(GLsync);
static void (*p_Finish)(void);

static GLsync *fence_slot(GLuint name, int create) {
    if (!name) return NULL;
    if (name >= fences.size) {
        if (!create) return NULL;
        GLuint size = fences.size ? fences.size : 64;
        while (size <= name) size *= 2;
        fences.sync = realloc(fences.sync, size * sizeof *fences.sync);
        fences.used = realloc(fences.used, size);
        memset(fences.sync + fences.size, 0, (size - fences.size) * sizeof *fences.sync);
        memset(fences.used + fences.size, 0, size - fences.size);
        fences.size = size;
    }
    if (!fences.used[name] && !create) return NULL;
    fences.used[name] = 1;
    return &fences.sync[name];
}

static void x_GenFencesAPPLE(GLsizei n, GLuint *out) {
    pthread_mutex_lock(&fences.lock);
    for (GLsizei i = 0; i < n; i++) { out[i] = fences.next++; fence_slot(out[i], 1); }
    pthread_mutex_unlock(&fences.lock);
}

static void x_DeleteFencesAPPLE(GLsizei n, const GLuint *names) {
    pthread_mutex_lock(&fences.lock);
    for (GLsizei i = 0; i < n; i++) {
        GLsync *s = fence_slot(names[i], 0);
        if (!s) continue;
        if (*s) p_DeleteSync(*s);
        *s = NULL;
        fences.used[names[i]] = 0;
    }
    pthread_mutex_unlock(&fences.lock);
}

static void x_SetFenceAPPLE(GLuint name) {
    GLsync made = p_FenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0);
    pthread_mutex_lock(&fences.lock);
    GLsync *s = fence_slot(name, 1);
    GLsync old = s ? *s : NULL;
    if (s) *s = made;
    pthread_mutex_unlock(&fences.lock);
    if (old) p_DeleteSync(old);
    if (!s && made) p_DeleteSync(made);
}

static GLsync fence_of(GLuint name) {
    pthread_mutex_lock(&fences.lock);
    GLsync *s = fence_slot(name, 0);
    GLsync sync = s ? *s : NULL;
    pthread_mutex_unlock(&fences.lock);
    return sync;
}

// A name that was generated but never set is not a fence yet (the spec's wording, from NV_fence)
static GLboolean x_IsFenceAPPLE(GLuint name) { return fence_of(name) != NULL; }

static GLboolean x_TestFenceAPPLE(GLuint name) {
    GLsync sync = fence_of(name);
    if (!sync) return GL_TRUE;
    // Flushing, so that an application polling this does not wait forever for work never sent
    GLenum r = p_ClientWaitSync(sync, GL_SYNC_FLUSH_COMMANDS_BIT, 0);
    return r == GL_ALREADY_SIGNALED || r == GL_CONDITION_SATISFIED;
}

static void x_FinishFenceAPPLE(GLuint name) {
    GLsync sync = fence_of(name);
    if (!sync) return;
    while (p_ClientWaitSync(sync, GL_SYNC_FLUSH_COMMANDS_BIT, 1000000000ull) == GL_TIMEOUT_EXPIRED) {}
}

// Per object: what Apple tracks per texture or buffer is not known here, so all work so far is waited for.
static GLboolean x_TestObjectAPPLE(GLenum object, GLuint name) { p_Finish(); return GL_TRUE; }
static void x_FinishObjectAPPLE(GLenum object, GLint name) { p_Finish(); }

// GL_APPLE_flush_render: glSwapAPPLE presents the current context as CGLFlushDrawable does.
static void x_SwapAPPLE(void) { present(t_current); }

// GL_APPLE_element_array: the element pointer is per context.
static void (*p_DrawElements)(GLenum, GLsizei, GLenum, const GLvoid *);
static void (*p_DrawRangeElements)(GLenum, GLuint, GLuint, GLsizei, GLenum, const GLvoid *);

static size_t element_size(GLenum type) { return type == GL_UNSIGNED_BYTE ? 1 : type == GL_UNSIGNED_SHORT ? 2 : 4; }

static void x_ElementPointerAPPLE(GLenum type, const GLvoid *pointer) {
    if (!t_current) return;
    t_current->element_type = type;
    t_current->element_pointer = pointer;
}

static const GLvoid *element_at(GLint first) {
    return (const char *)t_current->element_pointer + (size_t)first * element_size(t_current->element_type);
}

static void x_DrawElementArrayAPPLE(GLenum mode, GLint first, GLsizei count) {
    if (t_current) p_DrawElements(mode, count, t_current->element_type, element_at(first));
}

static void x_DrawRangeElementArrayAPPLE(GLenum mode, GLuint start, GLuint end, GLint first, GLsizei count) {
    if (t_current) p_DrawRangeElements(mode, start, end, count, t_current->element_type, element_at(first));
}

static void x_MultiDrawElementArrayAPPLE(GLenum mode, const GLint *first, const GLsizei *count, GLsizei n) {
    for (GLsizei i = 0; t_current && i < n; i++) p_DrawElements(mode, count[i], t_current->element_type, element_at(first[i]));
}

static void x_MultiDrawRangeElementArrayAPPLE(GLenum mode, GLuint start, GLuint end, const GLint *first, const GLsizei *count, GLsizei n) {
    for (GLsizei i = 0; t_current && i < n; i++)
        p_DrawRangeElements(mode, start, end, count[i], t_current->element_type, element_at(first[i]));
}

// GL_APPLE_object_purgeable: nothing is ever purged, so the contents are always kept.
static GLenum x_ObjectPurgeableAPPLE(GLenum type, GLuint name, GLenum option) { return 0x8A1A; /* GL_VOLATILE_APPLE */ }
static GLenum x_ObjectUnpurgeableAPPLE(GLenum type, GLuint name, GLenum option) { return 0x8A1B; /* GL_RETAINED_APPLE */ }
static void x_GetObjectParameterivAPPLE(GLenum type, GLuint name, GLenum pname, GLint *params) { if (params) *params = GL_FALSE; }
// GL_APPLE_texture_range: no client storage pointer
static void x_GetTexParameterPointervAPPLE(GLenum target, GLenum pname, GLvoid **params) { if (params) *params = NULL; }

// GL_EXT_debug_marker on KHR_debug
static void (*p_PushDebugGroup)(GLenum, GLuint, GLsizei, const GLchar *);
static void (*p_PopDebugGroup)(void);
static void (*p_DebugMessageInsert)(GLenum, GLenum, GLuint, GLenum, GLsizei, const GLchar *);
static void x_PushGroupMarkerEXT(GLsizei length, const GLchar *marker) { p_PushDebugGroup(0x824A, 0, length ? length : -1, marker ? marker : ""); }
static void x_PopGroupMarkerEXT(void) { p_PopDebugGroup(); }
static void x_InsertEventMarkerEXT(GLsizei length, const GLchar *marker) {
    p_DebugMessageInsert(0x824A /* APPLICATION */, 0x8268 /* MARKER */, 0, 0x826B /* NOTIFICATION */, length ? length : -1, marker ? marker : "");
}

// GL_EXT_geometry_shader4's one face of a cube map, as a plain attachment of that face
static void (*p_FramebufferTexture2D)(GLenum, GLenum, GLenum, GLuint, GLint);
static void x_FramebufferTextureFaceEXT(GLenum target, GLenum attachment, GLuint texture, GLint level, GLenum face) {
    p_FramebufferTexture2D(target, attachment, face, texture, level);
}

// The replacement for an entry zink does not resolve, or NULL.
static void *apple_extension(const char *name) {
    static const struct { const char *apple, *core; } same[] = {
        // the same functions under core names; APPLE_vertex_array_object objects behave as core VAOs in a compatibility context
        { "glGenVertexArraysAPPLE", "glGenVertexArrays" }, { "glDeleteVertexArraysAPPLE", "glDeleteVertexArrays" },
        { "glBindVertexArrayAPPLE", "glBindVertexArray" }, { "glIsVertexArrayAPPLE", "glIsVertexArray" },
        { "glFlushRenderAPPLE", "glFlush" }, { "glFinishRenderAPPLE", "glFinish" },
    };
    for (size_t i = 0; i < sizeof same / sizeof *same; i++)
        if (!strcmp(name, same[i].apple)) return core(same[i].core);
#define NEED(p, n) (p || (*(void **)&p = core(n)))
    static const struct { const char *name; void *fn; } made[] = {
        { "glGenFencesAPPLE", x_GenFencesAPPLE }, { "glDeleteFencesAPPLE", x_DeleteFencesAPPLE },
        { "glSetFenceAPPLE", x_SetFenceAPPLE }, { "glIsFenceAPPLE", x_IsFenceAPPLE },
        { "glTestFenceAPPLE", x_TestFenceAPPLE }, { "glFinishFenceAPPLE", x_FinishFenceAPPLE },
        { "glTestObjectAPPLE", x_TestObjectAPPLE }, { "glFinishObjectAPPLE", x_FinishObjectAPPLE },
        { "glSwapAPPLE", x_SwapAPPLE },
        { "glElementPointerAPPLE", x_ElementPointerAPPLE }, { "glDrawElementArrayAPPLE", x_DrawElementArrayAPPLE },
        { "glDrawRangeElementArrayAPPLE", x_DrawRangeElementArrayAPPLE },
        { "glMultiDrawElementArrayAPPLE", x_MultiDrawElementArrayAPPLE },
        { "glMultiDrawRangeElementArrayAPPLE", x_MultiDrawRangeElementArrayAPPLE },
        { "glObjectPurgeableAPPLE", x_ObjectPurgeableAPPLE }, { "glObjectUnpurgeableAPPLE", x_ObjectUnpurgeableAPPLE },
        { "glGetObjectParameterivAPPLE", x_GetObjectParameterivAPPLE },
        { "glGetTexParameterPointervAPPLE", x_GetTexParameterPointervAPPLE },
        { "glPushGroupMarkerEXT", x_PushGroupMarkerEXT }, { "glPopGroupMarkerEXT", x_PopGroupMarkerEXT },
        { "glInsertEventMarkerEXT", x_InsertEventMarkerEXT },
        { "glFramebufferTextureFaceEXT", x_FramebufferTextureFaceEXT },
    };
    for (size_t i = 0; i < sizeof made / sizeof *made; i++) {
        if (strcmp(name, made[i].name)) continue;
        // the core functions each one needs; without them the entry stays empty
        if (strstr(name, "Fence") || strstr(name, "TestObject") || strstr(name, "FinishObject")) {
            if (!NEED(p_FenceSync, "glFenceSync") || !NEED(p_ClientWaitSync, "glClientWaitSync") ||
                !NEED(p_DeleteSync, "glDeleteSync") || !NEED(p_Finish, "glFinish")) return NULL;
        } else if (strstr(name, "ElementArray")) {
            if (!NEED(p_DrawElements, "glDrawElements") || !NEED(p_DrawRangeElements, "glDrawRangeElements")) return NULL;
        } else if (strstr(name, "Marker")) {
            if (!NEED(p_PushDebugGroup, "glPushDebugGroup") || !NEED(p_PopDebugGroup, "glPopDebugGroup") ||
                !NEED(p_DebugMessageInsert, "glDebugMessageInsert")) return NULL;
        } else if (strstr(name, "FramebufferTextureFace")) {
            if (!NEED(p_FramebufferTexture2D, "glFramebufferTexture2D")) return NULL;
        }
        return made[i].fn;
    }
#undef NEED
    return NULL;
}
