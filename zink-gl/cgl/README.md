# cglzink: Apple OpenGL contexts drawing through zink (research, not installed by anything)

`libcglzink.dylib`, loaded with `DYLD_INSERT_LIBRARIES` into a chosen application, fills the dispatch table of each of its CGL
contexts with thunks that call Mesa's zink through EGL. Apple's CGL objects stay; only what they point at changes. Background:
`docs/reports/b580-zink-cgl-research-20261105.md`.

| File | What |
|---|---|
| `cglzink.m` | the layer: adopting contexts, current context, present, view → `CAMetalLayer`, swap interval |
| `../cgl-thunks/gen.py` | generates the 975 thunks. `GLhandleARB` passes unchanged: Mesa built on macOS has it pointer-sized as well (`include/GL/glext.h`) |
| `fakeegl.c` | test stand-in for EGL: a hidden Apple context per EGL context. Says nothing about zink |
| `layertest.m` | core and legacy contexts, CGL and NSOpenGLContext, another thread, a non-current context, ARB handles; prints pixel hashes |
| `build.sh ARCH OUT` | builds the three |

```
./build.sh arm64 /tmp/cz
/tmp/cz/layertest                                                                                 # Apple's GL
CGLZINK_EGL=/tmp/cz/libfakeegl.dylib DYLD_INSERT_LIBRARIES=/tmp/cz/libcglzink.dylib /tmp/cz/layertest   # the hashes must agree
```

Settings: `CGLZINK_OFF=1` (nothing is adopted), `CGLZINK_LOG=1`, `CGLZINK_EGL=<path>` (default `/Library/IntelXe/GL/libEGL.1.dylib`).
When EGL does not open, or a context cannot be created, that context stays on Apple's OpenGL.

## What has been run

On the build Mac (M1 Pro, macOS 27), arm64 and x86_64 under Rosetta, through `fakeegl.c`, so on Apple's GL:

- the pixel hashes agree with Apple's GL in every case above; `FAKEEGL_TINT=1` changes them, so the calls do arrive at the backend;
- `glGetAttachedObjectsARB` returns the same handles;
- `setView:` gave the view a `CAMetalLayer` and one window surface, `flushBuffer` one swap (arm64 only);
- `CGLZINK_OFF` and a missing EGL leave the application on Apple's GL.

**On the B580 (macOS 26.7.1, real Mesa EGL):** EGL 1.5 starts and 906 of 975 table entries resolve. Offscreen, through zink, the pixel hashes
of the core context, the other thread and the legacy ARB context equal Apple's GL, and `glGetAttachedObjectsARB` returns the same handles. A
window through `setView:` reports `zink Vulkan 1.4 (... Arc B580 ...)`, `4.6 (Compatibility Profile)`, and no GL error.
The frame rates this test prints are not comparable: neither path is limited to the display here.

**A real application: Chess.app (macOS 26.7.1, B580), `DYLD_INSERT_LIBRARIES` only.** All of its contexts are adopted, `libgallium` and the Vulkan loader are in the process, and board, pieces, textures and reflections are right by eye (window frame read from WindowServer). Against Apple's GL: largest channel difference above 32 on 0.59 % of the pixels, average 4.2. Greys agree and saturated colours shift a little (more blue in the wood); a colour matching difference is likely, not verified: setting the layer's `colorspace` changed nothing. It takes no MSAA here. Moving pieces has not been tried. Reaching it took four fixes that `layertest` could not show: the loader beside zink (a sandbox cannot read `/usr/local`), no MSAA and a depth of 24 instead of Apple's floating point 32 in the config, one surface across repeated `setView:`, and a sublayer instead of `view.layer` (layer-hosting views get no `drawRect:`).

## Not handled

- MSAA: the macOS EGL platform offers no multisampled config, so a context that asks for samples gets none (logged).
- `CGLTexImageIOSurface2D` returns `kCGLBadContext` and says so once. Video and Core Animation paths depend on it, also
  `CVOpenGLTextureCache` and `CAOpenGLLayer`: those applications should not load this layer.
- `CGLSetPBuffer`, `CGLSetOffScreen`, `CGLCopyContext`, `CGLDescribeRenderer`.
- `setView:` puts a Metal layer over the view's own layer: what the application draws into the view with AppKit stays under it.
- An entry zink does not have (Apple's own extensions, 11 entries no symbol reaches) does nothing and returns 0.
- `GL_VERSION` is zink's own, newer than the 4.1 an application expects from Apple.
- Interposing needs a process that keeps `DYLD_INSERT_LIBRARIES`: not hardened-runtime applications, unless AMFI is off.

## To check first on the B580

1. Why the default display offers no config for this request (`zink-gl/src/egltri.c` gets one with `native`): list `eglGetConfigs`. Does the macOS platform give pbuffers, or must offscreen contexts use another display?
2. A window through `setView:`: picture, resize (`update`), HiDPI; opaque handling is the same as with GLFW.
3. What a thunk costs: `CGLT_ENTER` reads a thread-local on each call, compared with Apple's path and the patched GLFW path.
4. GLFW without its patch, SDL, Qt, then a piglit comparison with Apple's GL.
