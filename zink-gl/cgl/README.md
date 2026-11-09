# cglzink: native OpenGL applications drawing through zink (experimental, per application)

`libcglzink.dylib`, loaded with `DYLD_INSERT_LIBRARIES` into a chosen application, fills the dispatch table of each of its CGL
contexts with thunks that call Mesa's zink through EGL. Apple's CGL objects stay; only what they point at changes. It is
the CGL/NSOpenGL counterpart of the GLFW route in `../README.md`: the application's GL calls skip Apple's OpenGL → Metal →
plugin path. Nothing loads it unless the user starts an application through `../cglzink-app.sh`.

History: prototype in the hackintosh research tree (`tools/b580/cgl-zink`, `tools/b580/cgl-thunks`; commits 0640304,
cb58869, ea35ef0, aca50fc, 57e1f0c, 5 Nov 2026), imported unchanged in this folder's first commit.

| File | What |
|---|---|
| `cglzink.m` | the layer: adopting contexts, lifetime, current context and threads, present, view → layer, swap interval, IOSurface |
| `appleext.h` | Apple's own GL extensions zink lacks (`APPLE_vertex_array_object`, `APPLE_fence`, `APPLE_element_array`, ...) from core functions |
| `gen/` | the thunk generator and the measured symbol → entry map (`gen/README.md`) |
| `test/fakeegl.c` | test stand-in for EGL: a hidden Apple context per EGL context, Mesa's binding rules. Says nothing about zink |
| `test/layertest.m`, `test/run.sh` | pixel hashes on Apple's GL and through the layer, which must agree |
| `build.sh ARCH OUT` | builds all three (x86_64 for the B580, arm64 for tests on Apple silicon), ad-hoc signed |

```
./build.sh x86_64 /tmp/cz      # libcglzink.dylib for the package (lib/ of ZINK_DIR)
./build.sh arm64 /tmp/czt && LAYERTEST_VIEW=1 test/run.sh /tmp/czt   # plumbing tests on the build Mac
```

Settings: `CGLZINK_OFF=1` (nothing is adopted), `CGLZINK_LOG=1`, `CGLZINK_EGL=<path>` (default `/Library/IntelXe/GL/libEGL.1.dylib`).
When EGL does not open, or a context cannot be made, that context stays on Apple's OpenGL.

## What it covers

- CGL: `CGLCreateContext`, `CGLDestroyContext`/`CGLReleaseContext` (by reference count), `CGLSetCurrentContext`,
  `CGLLockContext`/`CGLUnlockContext`, `CGLFlushDrawable`, `CGLSetParameter` (swap interval), `CGLClearDrawable`,
  `CGLUpdateContext`, `CGLTexImageIOSurface2D` (a copy), all 975 dispatch entries (906 straight to zink, 25 rebuilt in
  `appleext.h`, the rest Apple-only hints that do nothing).
- NSOpenGLContext: `initWithFormat:shareContext:`, `initWithCGLContextObj:`, `makeCurrentContext`, `clearCurrentContext`,
  `setView:`, `update`, `flushBuffer`, `clearDrawable`. NSOpenGLView works through these.
- Legacy (2.1 → zink 4.6 compatibility) and core (3.2 / 4.1 → zink core) profiles; shared contexts (both on zink, or both
  stay on Apple's GL); a context used by two threads under `CGLLockContext` (the CVDisplayLink pattern).
- Retina: the surface is in pixels only when the view asks for it (`wantsBestResolutionOpenGLSurface`), as with Apple.
- The swap interval is Apple's context's own value (the application's, or Apple's default 1).
- Contexts Core Animation makes for a `CAOpenGLLayer`/`NSOpenGLLayer` (and the application's subclasses) stay on Apple's GL.

## What it does not

- MSAA: the macOS EGL platform offers no multisampled config; a context asking for samples gets none (said once).
- `CGLTexImageIOSurface2D` copies the plane at the call: right for video textures (`CVOpenGLTextureCache`), wrong for
  drawing into an IOSurface (browsers' compositors). `GL_YCBCR_422_APPLE` is refused.
- `CGLSetPBuffer`, `CGLSetOffScreen`, `CGLCopyContext`, `kCGLCPSurfaceBackingSize`, `kCGLCPSurfaceOpacity` 0, full screen
  CGL: said once, left to Apple's GL (so they show nothing through zink).
- `setView:` puts a layer over the view's own: what the application draws into the view with AppKit stays under it.
- `GL_VERSION`/`GL_RENDERER`/`GL_EXTENSIONS` are zink's (4.6, no `GL_APPLE_*`).
- A context two threads use without locking: the second thread's calls are dropped after 100 ms (said once).
- Injection needs `DYLD_INSERT_LIBRARIES` to reach the process: true on this driver's setup (AMFI off) also for hardened
  and Apple applications; `launchctl setenv` refuses `DYLD_*` names, so there is no system-wide switch (`../README.md`).

Tested on the build Mac (macOS 27, arm64 and x86_64 under Rosetta) through the stand-in only: every hash equal to Apple's
GL, with and without zink's missing names. On the B580 the prototype ran Chess.app (5 Nov); this version is not yet run there.
