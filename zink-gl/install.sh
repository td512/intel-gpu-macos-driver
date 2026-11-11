#!/bin/bash
# SPDX-License-Identifier: MIT
# install.sh (zink-gl): OpenGL through Mesa's zink on the Intel Arc B580, for applications that open their OpenGL
# context through GLFW / EGL (LWJGL 3 games such as Minecraft Java). Apple's OpenGL, Mesa ANV and the kexts are not
# touched; nothing here is loaded by a process that does not ask for these libraries.
#
#   sudo ./install.sh              install (backs up what it replaces to ./previous/, once)
#   sudo ./install.sh --undo       put back what was there before
#   ./install.sh --test            offscreen self-test (EGL pbuffer, GL core through zink on the B580, ~1 s)
#   sudo ./install.sh --global on  every LWJGL 3 application of every user uses zink (JAVA_TOOL_OPTIONS, set by a
#                                  LaunchAgent at login; applies to applications started after the next login, or
#                                  right away for the logged-in user)
#   sudo ./install.sh --global off back to Apple's OpenGL for them
#   ./install.sh --status
#   ./cglzink-app.sh ...           native CGL/NSOpenGL applications through zink, one at a time (experimental; see there)
#   sudo ./install.sh --global-gl on|off   EXPERIMENTAL: every native OpenGL application through zink (cglzink): a
#                                  LaunchAgent puts libcglzink-boot into DYLD_INSERT_LIBRARIES of the login session;
#                                  it takes part only in application bundles that are not Apple's (Chess excepted),
#                                  browsers, Electron apps or video players; /Library/IntelXe/GL/cglzink-global.txt
#                                  ("-bundle.id" / "+bundle.id") refuses or allows one. Turn it off before deleting
#                                  /Library/IntelXe/GL by hand: an inserted library that is missing stops every launch.
#
# Installs:
#   /Library/IntelXe/GL/                   libEGL (Mesa EGL, macOS platform), libgallium (zink), libGLzink (LWJGL's
#                                          OpenGL library), libglfw.3 (GLFW 3.4 + the zink EGL patch), and when the
#                                          package has it libcglzink (CGL/NSOpenGL applications, loaded only by
#                                          cglzink-app.sh's launchers)
#   /Library/IntelXe/GL/libvulkan.1.dylib, intel_icd.x86_64.json: the loader and manifest again, for sandboxed applications
#   /usr/local/lib/libvulkan.1.4.363.dylib the Khronos Vulkan loader (+ libvulkan.1.dylib, libvulkan.dylib links),
#                                          which zink and ordinary Vulkan applications use to find the B580
#   /usr/local/share/vulkan/icd.d/intel_icd.x86_64.json  -> /Library/GPUBundles/nvmtl/libvulkan_intel.dylib
set -euo pipefail
H=$(cd "$(dirname "$0")" && pwd)
B=$H/previous
GL=/Library/IntelXe/GL
VL=/usr/local/lib VLIB=libvulkan.1.4.363.dylib
ICDD=/usr/local/share/vulkan/icd.d ICD=intel_icd.x86_64.json
LA=/Library/LaunchAgents/io.github.yusufklncc.intelxe.zink-gl.plist
LIBS="libEGL.1.dylib libgallium-27.0.0-devel.dylib libGLzink.dylib libglfw.3.dylib"
OPTLIBS="libcglzink.dylib libcglzink-boot.dylib IntelXeGL"   # installed when the package has them
HELPER=$GL/IntelXeGL   # what the LaunchAgents run, so macOS names it (not "sh" or "launchctl") in its notices
LAGL=/Library/LaunchAgents/io.github.yusufklncc.intelxe.cglzink-global.plist
BOOT=$GL/libcglzink-boot.dylib
JOPTS="-Dorg.lwjgl.glfw.libname=$GL/libglfw.3.dylib -Dorg.lwjgl.opengl.libname=$GL/libGLzink.dylib"

root() { [ "$(id -u)" = 0 ] || { echo "needs root: sudo $0 $*"; exit 1; }; }
sums() { (cd "$H" && shasum -a 256 -c SHA256SUMS >/dev/null) || { echo "REFUSED: files differ from SHA256SUMS"; exit 1; }; }
sig() { "$H/sigcheck" "$1" >/dev/null || { "$H/sigcheck" "$1"; echo "REFUSED: $1 is not signed"; exit 1; }; }
console_user() { stat -f %Su /dev/console 2>/dev/null || true; }

status() {
    echo "zink-gl:"
    [ -d $GL ] && echo "  $GL: $(cd $GL && ls *.dylib | tr '\n' ' ')" || echo "  $GL: not installed"
    [ -e $VL/$VLIB ] && echo "  Vulkan loader: $VL/$VLIB" || echo "  Vulkan loader: not installed"
    [ -e $ICDD/$ICD ] && echo "  ICD: $ICDD/$ICD -> $(sed -n 's/.*"library_path": *"\([^"]*\)".*/\1/p' $ICDD/$ICD)" || echo "  ICD: none"
    if [ -e $LA ]; then echo "  global: on ($LA)"; else echo "  global: off"; fi
    if [ -e $GL/libcglzink.dylib ]; then echo "  cglzink: installed; per application with ./cglzink-app.sh"; fi
    if [ -e $LAGL ]; then echo "  cglzink for every OpenGL application: on ($LAGL, experimental)"; else echo "  cglzink for every OpenGL application: off"; fi
    local u; u=$(console_user)
    if [ -n "$u" ] && [ "$u" != root ]; then
        if [ "$(id -u)" = 0 ]; then echo "  JAVA_TOOL_OPTIONS for $u: $(launchctl asuser "$(id -u "$u")" launchctl getenv JAVA_TOOL_OPTIONS 2>/dev/null || true)"
        else echo "  JAVA_TOOL_OPTIONS for $u: (sudo $0 --status shows it)"; fi
    fi
    echo "  surfvram: $(sysctl -n debug.intelxe.surfvram 2>/dev/null || echo '?') (2 = no present copy)"
}

global() {
    root "--global $1"
    local u; u=$(console_user)
    case "$1" in
    on)
        [ -d $GL ] || { echo "install first: sudo $0"; exit 1; }
        cat > $LA.new <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>io.github.yusufklncc.intelxe.zink-gl</string>
	<key>ProgramArguments</key>
	<array>$(if [ -x $HELPER ]; then echo "<string>$HELPER</string>"; else echo "<string>/bin/launchctl</string>"; fi)<string>setenv</string><string>JAVA_TOOL_OPTIONS</string><string>$JOPTS</string></array>
	<key>RunAtLoad</key><true/>
</dict>
</plist>
EOF
        chown root:wheel $LA.new; chmod 644 $LA.new; mv $LA.new $LA
        if [ -n "$u" ] && [ "$u" != root ]; then
            launchctl asuser "$(id -u "$u")" launchctl setenv JAVA_TOOL_OPTIONS "$JOPTS"
            echo "on: LWJGL 3 applications started from now on by $u (and by every user after login) use zink."
        else echo "on: from the next login."; fi
        echo "Applications started before this keep Apple's OpenGL until they are restarted." ;;
    off)
        rm -f $LA
        if [ -n "$u" ] && [ "$u" != root ]; then launchctl asuser "$(id -u "$u")" launchctl unsetenv JAVA_TOOL_OPTIONS; fi
        echo "off: LWJGL applications started from now on use Apple's OpenGL." ;;
    *) echo "usage: $0 --global on|off"; exit 2 ;;
    esac
}

# --global-gl on|off: libcglzink-boot in DYLD_INSERT_LIBRARIES of the login session. The LaunchAgent sets it only while
# both libraries are there (a missing inserted library would stop every application from starting); off unsets it
# for the logged-in user at once.
global_gl() {
    root "--global-gl $1"
    local u; u=$(console_user)
    case "$1" in
    on)
        [ -f $BOOT ] && [ -f $GL/libcglzink.dylib ] || { echo "this installation has no libcglzink-boot.dylib: install a package that has it first"; exit 1; }
        cat > $LAGL.new <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>io.github.yusufklncc.intelxe.cglzink-global</string>
	<key>ProgramArguments</key>
$(if [ -x $HELPER ]; then echo "	<array><string>$HELPER</string><string>setenv</string><string>DYLD_INSERT_LIBRARIES</string><string>$BOOT</string><string>$BOOT</string><string>$GL/libcglzink.dylib</string></array>"
  else echo "	<array><string>/bin/sh</string><string>-c</string><string>[ -f $BOOT ] &amp;&amp; [ -f $GL/libcglzink.dylib ] &amp;&amp; exec /bin/launchctl setenv DYLD_INSERT_LIBRARIES $BOOT</string></array>"; fi)
	<key>RunAtLoad</key><true/>
</dict>
</plist>
PLIST
        chown root:wheel $LAGL.new; chmod 644 $LAGL.new; mv $LAGL.new $LAGL
        if [ -n "$u" ] && [ "$u" != root ]; then
            launchctl asuser "$(id -u "$u")" launchctl setenv DYLD_INSERT_LIBRARIES $BOOT
            echo "on (experimental): OpenGL applications $u starts from now on draw through zink, where cglzink-global's rules allow."
        else echo "on (experimental): from the next login."; fi
        echo "Off: sudo $0 --global-gl off. Running applications keep what they had until they are restarted." ;;
    off)
        rm -f $LAGL
        if [ -n "$u" ] && [ "$u" != root ]; then
            case "$(launchctl asuser "$(id -u "$u")" launchctl getenv DYLD_INSERT_LIBRARIES 2>/dev/null)" in
                *libcglzink-boot*) launchctl asuser "$(id -u "$u")" launchctl unsetenv DYLD_INSERT_LIBRARIES ;;
            esac
        fi
        echo "off: OpenGL applications started from now on use Apple's OpenGL (cglzink-app.sh launchers still work)." ;;
    *) echo "usage: $0 --global-gl on|off"; exit 2 ;;
    esac
}

# place SRC DST: replace DST (file or directory) with a root-owned copy of SRC
place() { rm -rf "$2.new"; ditto "$1" "$2.new"; chown -R root:wheel "$2.new"; chmod -R go-w "$2.new"; rm -rf "$2"; mv "$2.new" "$2"; }

install_all() {
    root
    sums
    [ -f /Library/GPUBundles/nvmtl/libvulkan_intel.dylib ] || { echo "REFUSED: the driver is not installed (no /Library/GPUBundles/nvmtl/libvulkan_intel.dylib)"; exit 1; }
    local f; for f in $LIBS; do sig "$H/lib/$f"; done; sig "$H/vulkan/$VLIB"
    # the global switch is on but this package lacks its library: replacing the folder would leave the session inserting
    # a missing library, which stops every application from starting
    if [ -e $LAGL ] && [ ! -f "$H/lib/libcglzink-boot.dylib" ]; then echo "REFUSED: cglzink's global switch is on and this package has no libcglzink-boot.dylib: sudo $0 --global-gl off first"; exit 1; fi
    for f in $OPTLIBS; do [ -f "$H/lib/$f" ] && sig "$H/lib/$f"; done
    if [ ! -d "$B" ]; then
        mkdir -p "$B"
        if [ -d $GL ]; then ditto $GL "$B/GL"; else touch "$B/no-GL"; fi
        if [ -e $VL/$VLIB ]; then cp -p $VL/$VLIB "$B/$VLIB"; else touch "$B/no-loader"; fi
        if [ -e $ICDD/$ICD ]; then cp -p $ICDD/$ICD "$B/$ICD"; else touch "$B/no-icd"; fi
        echo "backup: $B"
    fi
    mkdir -p /Library/IntelXe "$H/.stage"
    rm -rf "$H/.stage/GL"; mkdir "$H/.stage/GL"
    for f in $LIBS; do cp "$H/lib/$f" "$H/.stage/GL/"; done
    for f in $OPTLIBS; do [ -f "$H/lib/$f" ] && cp "$H/lib/$f" "$H/.stage/GL/"; done
    ln -s libEGL.1.dylib "$H/.stage/GL/libEGL.dylib"
    # also beside zink: a sandboxed application cannot read /usr/local
    install -m 755 "$H/vulkan/$VLIB" "$H/.stage/GL/libvulkan.1.dylib"
    install -m 644 "$H/vulkan/icd.d/$ICD" "$H/.stage/GL/$ICD"
    place "$H/.stage/GL" $GL; rm -rf "$H/.stage"
    mkdir -p $VL $ICDD
    install -o root -g wheel -m 755 "$H/vulkan/$VLIB" $VL/$VLIB
    ln -sf $VLIB $VL/libvulkan.1.dylib; ln -sf libvulkan.1.dylib $VL/libvulkan.dylib
    install -o root -g wheel -m 644 "$H/vulkan/icd.d/$ICD" $ICDD/$ICD
    # switches turned on by an older package: their LaunchAgents run the helper from now on
    if [ -x $HELPER ]; then
        [ -e $LA ] && ! grep -q "$HELPER" $LA && global on >/dev/null || true
        [ -e $LAGL ] && ! grep -q "$HELPER" $LAGL && global_gl on >/dev/null || true
    fi
    status
    echo "installed. Try: $0 --test; then sudo $0 --global on (all LWJGL 3 apps) or ./zink-gl-version.sh (one game)."
}

undo() {
    root
    [ -d "$B" ] || { echo "nothing to undo (not installed from this folder)"; exit 1; }
    [ -e $LA ] && global off
    [ -e $LAGL ] && global_gl off   # first: the libraries it inserts go below
    if [ -d "$B/GL" ]; then place "$B/GL" $GL; else rm -rf $GL; rmdir /Library/IntelXe 2>/dev/null || true; fi
    if [ -e "$B/$VLIB" ]; then install -o root -g wheel -m 755 "$B/$VLIB" $VL/$VLIB
    else rm -f $VL/$VLIB $VL/libvulkan.1.dylib $VL/libvulkan.dylib; fi
    if [ -e "$B/$ICD" ]; then install -o root -g wheel -m 644 "$B/$ICD" $ICDD/$ICD; else rm -f $ICDD/$ICD; fi
    rm -rf "$B"
    status
}

case "${1:-}" in
    "") install_all ;;
    --undo) undo ;;
    --test) sums; exec /usr/bin/perl -e 'alarm shift; exec @ARGV' 30 "$H/bin/zink-gl-selftest" 200 native ;;
    --global) global "${2:-}" ;;
    --global-gl) global_gl "${2:-}" ;;
    --status) status ;;
    *) sed -n '5,20p' "$0"; exit 2 ;;
esac
