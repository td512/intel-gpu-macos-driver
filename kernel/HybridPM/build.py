#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Build HybridPM.kext (kernel/HybridPM, a Lilu plugin) and hpmstat, its user-space reader.

Usage: build.py [--debug] [--output DIR] [--sdk DIR] [--lilu DIR]   (default output: <repo>/build/HybridPM)

The kext is built -O2 -g (symbols stripped) by default, the release build; --debug builds it -O0 with DEBUG=1, which
turns on Lilu's DBGLOG lines (shown with the boot-arg -hpmdbg and a DEBUG Lilu). hpmstat is signed ad hoc.

Build dependencies, not vendored:
- MacKernelSDK (https://github.com/acidanthera/MacKernelSDK, APSL-2.0): --sdk, $MACKERNELSDK or <repo>/external/MacKernelSDK.
- Lilu (https://github.com/acidanthera/Lilu, BSD-3-Clause): its headers and Library/plugin_start.cpp, which is compiled
  into the kext. --lilu takes a Lilu.kext (DEBUG build, whose Contents/Resources holds Headers/ and Library/), that
  Contents/Resources folder, or a Lilu source checkout; $LILU or <repo>/external/Lilu.kext. Lilu's licence text is
  kept in LICENSE.Lilu and copied into the bundle's Resources.
"""
import argparse,os,plistlib,shutil,subprocess,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent          # kernel/HybridPM
REPO=HERE.parent.parent
VER=(REPO/'VERSION').read_text().strip()       # the release that last rebuilt the kext
IDENT='io.github.yusufklncc.HybridPM'
def run(cmd): subprocess.run([str(x) for x in cmd],check=True,cwd=HERE)
def lilu_dir(p):
 for d in (p/'Contents/Resources',p,p/'Lilu'):
  if (d/'Headers/kern_api.hpp').is_file() and (d/'Library/plugin_start.cpp').is_file(): return d
 sys.exit(f'Lilu headers not found under {p}: pass --lilu with a Lilu.kext (DEBUG build), its Contents/Resources or a Lilu checkout')
def main():
 p=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
 p.add_argument('--debug',action='store_true',help='-O0 with DEBUG=1 (DBGLOG lines)')
 p.add_argument('--release',action='store_true',help='no effect: the release build is the default')
 p.add_argument('--output',type=Path,default=REPO/'build/HybridPM')
 p.add_argument('--sdk',type=Path,default=Path(os.environ.get('MACKERNELSDK',REPO/'external/MacKernelSDK')),
  help='MacKernelSDK checkout (default: $MACKERNELSDK or <repo>/external/MacKernelSDK)')
 p.add_argument('--lilu',type=Path,default=Path(os.environ.get('LILU',REPO/'external/Lilu.kext')),
  help='Lilu.kext, its Contents/Resources, or a Lilu checkout (default: $LILU or <repo>/external/Lilu.kext)')
 a=p.parse_args();out=a.output.resolve()
 sdk=a.sdk.resolve()
 if not (sdk/'Headers').is_dir() or not (sdk/'Library/x86_64/libkmod.a').is_file():
  sys.exit(f'MacKernelSDK not found at {sdk}: pass --sdk, set MACKERNELSDK, or clone it to {REPO/"external/MacKernelSDK"}')
 lilu=lilu_dir(a.lilu.resolve())
 kext=out/'HybridPM.kext'
 if kext.exists(): shutil.rmtree(kext)
 bundle=kext/'Contents';(bundle/'MacOS').mkdir(parents=True);(bundle/'Resources').mkdir()
 objdir=out/'obj';objdir.mkdir(parents=True,exist_ok=True)
 # The kernel C++ flags of kernel/IntelXe/build.py (the WEG/Lilu kext ABI, 10.6 deployment target), plus Lilu's headers
 # as system headers (-isystem): kern_util.hpp raises -Wsign-conversion and -Wshadow warnings that are not ours.
 base=['xcrun','clang++','-arch','x86_64','-std=c++17',('-O0' if a.debug else '-O2'),'-g','-fapple-kext','-fno-exceptions','-fno-rtti',
  '-fno-stack-protector','-fno-builtin','-fno-asynchronous-unwind-tables','-mno-red-zone','-nostdinc','-DKERNEL','-DKERNEL_PRIVATE',
  '-D__APPLE__','-D__MACH__','-I'+str(sdk/'Headers'),'-isystem',str(lilu),'-mmacosx-version-min=10.6','-DAPPLE_KEXT_ASSERTIONS=1',
  '-DDRIVER_PRIVATE','-DAPPLE','-DNeXT','-fno-common','-Wall','-Wextra','-Wno-unused-parameter','-Wno-deprecated-declarations',
  '-DPRODUCT_NAME=HybridPM',f'-DMODULE_VERSION={VER}','-fdebug-compilation-dir=.']
 if a.debug: base+=['-DDEBUG=1']
 objects=[]
 for src in [HERE/'HybridPM.cpp',lilu/'Library/plugin_start.cpp']:
  obj=objdir/(src.stem+'.o');run(base+['-c',src,'-o',obj]);objects.append(obj)
 exe=bundle/'MacOS/HybridPM'
 run(['xcrun','ld','-arch','x86_64','-kext','-undefined','dynamic_lookup','-no_fixup_chains','-macos_version_min','10.6','-o',exe,*objects,sdk/'Library/x86_64/libkmod.a'])
 run(['xcrun','strip','-S',exe])
 libs={x:'10.0.0' for x in ['com.apple.kpi.bsd','com.apple.kpi.dsep','com.apple.kpi.iokit','com.apple.kpi.libkern','com.apple.kpi.mach','com.apple.kpi.unsupported']}
 libs['com.apple.iokit.IOPCIFamily']='1.1';libs['as.vit9696.Lilu']='1.2.0'
 info=dict(CFBundleIdentifier=IDENT,CFBundleExecutable='HybridPM',CFBundleName='HybridPM',CFBundlePackageType='KEXT',CFBundleVersion=VER,
  CFBundleShortVersionString=VER,OSBundleCompatibleVersion='0.1.0',OSBundleRequired='Root',OSBundleLibraries=libs,
  IOKitPersonalities={IDENT:dict(CFBundleIdentifier=IDENT,IOClass='HybridPM',IOMatchCategory='HybridPM',IOProviderClass='IOResources',IOResourceMatch='IOKit')})
 (bundle/'Info.plist').write_bytes(plistlib.dumps(info))
 shutil.copyfile(HERE/'LICENSE.Lilu',bundle/'Resources/LICENSE-Lilu.txt')   # plugin_start.cpp is in the binary
 syms=subprocess.check_output(['xcrun','nm','-u',str(exe)],text=True)
 assert not any(x in syms for x in ['chkstk_darwin','___memcpy_chk']), 'userspace ABI imported'
 print(kext)
 hpmstat=out/'hpmstat'
 run(['xcrun','clang','-arch','x86_64','-mmacosx-version-min=11.0','-O2','-Wall','-Wextra','-o',hpmstat,HERE/'hpmstat.c'])
 run(['codesign','-f','-s','-',hpmstat])
 print(hpmstat)
if __name__=='__main__':main()
