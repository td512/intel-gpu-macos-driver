# xlate-compare

Host tools (no GPU) that compare two builds of `libnvmtl_translate.dylib` on real shader AIR, for every entry point the
Metal plugin calls, and check the function-constant paths against each other. They exist because the nullmoth 2.9 merge
changed what the fc-spec path (`nvmtl_translate_fc_spec2`) produced for Core Animation's `fixed_frag` while every
SPIR-V corpus stayed byte-identical: WindowServer drew a white desktop.

- `ep.c` - one function through `nvmtl_translate`, `nvmtl_reflect`, `nvmtl_visible_refs`, and, with constants,
  `nvmtl_translate_fc`, `nvmtl_reflect_fc`, `nvmtl_fc_structural`, `nvmtl_translate_fc_spec2`, `nvmtl_translate_samplers`;
  each output into a folder. Build for the dylib's architecture (`clang -arch x86_64 -o ep ep.c` for the shipped one).
- `run_ep.py <old.dylib> <new.dylib> <outdir> <ll>...` - every function with a zero and three random constant sets
  through both builds; prints each output that differs (module bytes, reflection JSON, structural set, errors).
- `fcequiv.c` - the whole translation of a variant and the plugin's fc-spec module with the values frozen in
  (`nullmoth/plugin/nvmtl_spec_fc.h`): `clang -I nullmoth/plugin -o fcequiv fcequiv.c`.
- `equiv.py <dylib> <ll> <nsets> <outdir>` - for each constant set, the frozen fc-spec module must keep at least the
  texture operations of the whole translation (it may keep more: less is folded). The first nm29 build failed it on
  `fixed_frag_lph_cph` (9 -> 5 in one set); main and the fixed build pass.

The AIR comes from a metallib: `AIRDUMP=<dir> <gbspv/xs> NVMTLDriver.bundle/Contents/MacOS/NVMTLDriver <lib.metallib>`
writes each function's LLVM text. Apple's shaders are not in the repository; point the tools at a local copy.
