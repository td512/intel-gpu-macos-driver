# CGL dispatch thunks (research tool, not part of any install)

`gl*` calls go through the current CGL context's table (`CGLContextObj->disp`). These files make a table whose entries drop the
`GLIContext` argument and call a backend such as zink. See `docs/reports/b580-zink-cgl-research-20261105.md`.

- `gen.py OUT`: from the SDK's `gliDispatch.h` and libGL's exports: `map.c`, `thunks.h`, `check.c`.
- `map.c` → `map.tsv`: measured with a numbered trap in every entry: which symbol reaches which entry.
- `names.py map.tsv thunks.h > backend_names.h`: the GL name a backend resolves for each entry.
- `check.c`: renders a shader, texture and FBO directly and through the thunks and compares the pixels.
  Build: `clang -arch x86_64 -O1 -w check.c -framework OpenGL -o check`.
