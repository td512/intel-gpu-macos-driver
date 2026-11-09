#!/bin/bash
# SPDX-License-Identifier: MIT
# cglzink-app.sh: one native OpenGL application (CGL / NSOpenGL) through zink instead of Apple's OpenGL, opt-in per
# application. Experimental. Needs `sudo ./install.sh` from this package (it puts libcglzink.dylib beside zink).
#
#   ./cglzink-app.sh list                    applications that look like OpenGL users (/Applications, ~/Applications)
#   ./cglzink-app.sh add  /Applications/X.app    makes "~/Applications/X (zink).app": open that one for zink, X for Apple's GL
#   ./cglzink-app.sh remove X                 deletes "X (zink).app"
#   ./cglzink-app.sh status                   the "(zink)" applications made so far
#   ./cglzink-app.sh run  /Applications/X.app [args]   starts X once through zink in this terminal, the layer's log here
#
# "X (zink).app" starts the real X through LaunchServices with DYLD_INSERT_LIBRARIES set for that launch only; X keeps its
# own name, icon, documents and settings. If X is already running, quit it first: a running application is only brought
# to the front. Nothing system-wide is changed. (With AMFI off, launchctl setenv would pass DYLD_* to every application
# started later; such a switch is not offered until the gains are measured: it loads the layer into every process.)
# Off: open X itself, or remove "X (zink).app". The layer's log of the last start: ~/Library/Logs/cglzink/X.log
set -euo pipefail
GL=${CGLZINK_GL_DIR:-/Library/IntelXe/GL}            # the overrides are for tests
LIB=$GL/libcglzink.dylib
APPS=${CGLZINK_APPS_DIR:-$HOME/Applications}
LOGS="$HOME/Library/Logs/cglzink"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

usage() { sed -n '5,10p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
plist() { /usr/bin/plutil -extract "$2" raw -o - "$1/Contents/Info.plist" 2>/dev/null || true; }
app_path() {   # an .app path, or a name found in /Applications, ~/Applications, /System/Applications
    local a=${1%/} d
    [ -d "$a" ] && { (cd "$a" && pwd); return; }
    for d in /Applications "$APPS" /System/Applications /Applications/Utilities; do
        [ -d "$d/$a.app" ] && { echo "$d/$a.app"; return; }; [ -d "$d/$a" ] && { echo "$d/$a"; return; }
    done
    echo "no application $1" >&2; exit 1
}
check_lib() {
    [ -f "$LIB" ] && [ -f "$GL/libEGL.1.dylib" ] && return
    echo "missing $LIB or $GL/libEGL.1.dylib: run 'sudo ./install.sh' from this package first"; exit 1
}
# The bundle's own Mach-O files (main executable, top-level frameworks and dylibs) that link Apple's OpenGL (the load
# commands, in the first 256 KB), import NSOpenGL or CGL, or SDL, which opens OpenGL with dlopen. Chromium/Electron bundles name it for ANGLE but
# draw with Metal: left out.
uses_gl() {
    local f
    for f in "$1/Contents/Frameworks/Electron Framework.framework" "$1/Contents/Frameworks/Chromium Embedded Framework.framework"; do
        [ -d "$f" ] && return
    done
    for f in "$1"/Contents/MacOS/* "$1"/Contents/Frameworks/*.dylib "$1"/Contents/Frameworks/*.framework/Versions/A/*; do
        [ -f "$f" ] && [ -x "$f" ] || continue
        case "$f" in *SDL*) echo yes; return ;; esac
        if /usr/bin/head -c 262144 "$f" | /usr/bin/grep -a -q -m1 -e 'OpenGL.framework' -e 'libGL.dylib'; then echo yes; return; fi
        # a main executable below 32 MB: also what it imports (NSOpenGL classes, CGL calls), at the end of the file
        case "$f" in */Contents/MacOS/*)
            [ "$(/usr/bin/stat -f %z "$f")" -lt 33554432 ] &&
                /usr/bin/grep -a -q -m1 -e '_OBJC_CLASS_$_NSOpenGL' -e '_CGLChoosePixelFormat' -e '_CGLCreateContext' "$f" &&
                { echo yes; return; } ;;
        esac
    done
}

list() {
    local a n
    for a in /Applications/*.app /Applications/*/*.app "$APPS"/*.app /System/Applications/Chess.app; do
        [ -d "$a" ] || continue
        case "$a" in *" (zink).app") continue ;; esac
        [ -n "$(uses_gl "$a")" ] || continue
        n=$(basename "$a" .app)
        if [ -d "$APPS/$n (zink).app" ]; then echo "  $a   (has $n (zink).app)"; else echo "  $a"; fi
    done
    echo "These link or import Apple's OpenGL; whether they draw with it (not with Metal) shows only when they run."
}

add() {
    check_lib
    local a n id exe w icon q
    a=$(app_path "$1"); n=$(basename "$a" .app); id=$(plist "$a" CFBundleIdentifier); exe=$(plist "$a" CFBundleExecutable)
    [ -n "$exe" ] || { echo "$a has no CFBundleExecutable"; exit 1; }
    [ -n "$(uses_gl "$a")" ] || echo "note: nothing in $a names OpenGL; it may draw with Metal, and then this changes nothing"
    w="$APPS/$n (zink).app"
    q=$(printf %q "$a")
    mkdir -p "$APPS" "$LOGS"
    rm -rf "$w.new"; mkdir -p "$w.new/Contents/MacOS" "$w.new/Contents/Resources"
    icon=$(plist "$a" CFBundleIconFile)
    if [ -n "$icon" ]; then
        case "$icon" in *.icns) ;; *) icon=$icon.icns ;; esac
        if [ -f "$a/Contents/Resources/$icon" ]; then cp "$a/Contents/Resources/$icon" "$w.new/Contents/Resources/AppIcon.icns"; else icon=; fi
    fi
    cat > "$w.new/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>cglzink-launch</string>
	<key>CFBundleIdentifier</key><string>io.github.yusufklncc.intelxe.cglzink.$(echo "${id:-$n}" | tr -c 'A-Za-z0-9.\n' '-')</string>
	<key>CFBundleName</key><string>$n (zink)</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleIconFile</key><string>${icon:+AppIcon}</string>
	<key>LSUIElement</key><true/>
	<key>IntelXeTarget</key><string>$a</string>
</dict>
</plist>
EOF
    # The launcher checks the layer at every start: DYLD_INSERT_LIBRARIES naming a missing file would stop the application.
    cat > "$w.new/Contents/MacOS/cglzink-launch" <<EOF
#!/bin/bash
# made by cglzink-app.sh: starts $n with its OpenGL through zink (DYLD_INSERT_LIBRARIES for this launch only)
APP=$q
EXE="\$APP/Contents/MacOS/$exe"
LOG="$LOGS/$n.log"
if /bin/ps -axo comm= | /usr/bin/grep -Fxq -- "\$EXE"; then
    /usr/bin/osascript -e 'display dialog "$n is already running on Apple'"'"'s OpenGL. Quit it, then open $n (zink) again." buttons {"OK"} default button 1 with icon caution' >/dev/null 2>&1
    exit 0
fi
if [ -f '$LIB' ] && [ -f '$GL/libEGL.1.dylib' ]; then
    mkdir -p "$LOGS"; : > "\$LOG"
    exec /usr/bin/open -a "\$APP" --stderr "\$LOG" --env 'DYLD_INSERT_LIBRARIES=$LIB' --env CGLZINK_LOG=1 --args "\$@"
fi
exec /usr/bin/open -a "\$APP" --args "\$@"
EOF
    chmod 755 "$w.new/Contents/MacOS/cglzink-launch"
    /usr/bin/codesign -s - -f "$w.new" >/dev/null 2>&1 || true
    rm -rf "$w"; mv "$w.new" "$w"
    "$LSREGISTER" -f "$w" 2>/dev/null || true
    echo "made $w"
    echo "open \"$n (zink)\" for zink, \"$n\" for Apple's OpenGL. Log of the last start: $LOGS/$n.log"
}

remove() {
    local n=${1%/}; n=$(basename "$n" .app); n=${n% (zink)}
    local w="$APPS/$n (zink).app"
    [ -d "$w" ] || { echo "no $w"; exit 1; }
    "$LSREGISTER" -u "$w" 2>/dev/null || true
    rm -rf "$w"; echo "removed $w; $n opens on Apple's OpenGL as before"
}

status() {
    if [ -f "$LIB" ]; then echo "layer: $LIB"; else echo "layer: not installed (sudo ./install.sh)"; fi
    local w found=0
    for w in "$APPS"/*" (zink).app"; do
        [ -d "$w" ] || continue
        found=1; echo "  $(basename "$w") -> $(plist "$w" IntelXeTarget)"
    done
    [ $found = 1 ] || echo "  no (zink) applications"
}

run() {
    check_lib
    local a=$1 exe; shift
    if [ -d "$a" ] || [[ "$a" != */* ]]; then a=$(app_path "$a"); exe="$a/Contents/MacOS/$(plist "$a" CFBundleExecutable)"; else exe=$a; fi
    echo "starting $exe through zink; the layer's log follows (Ctrl-C quits the application)"
    CGLZINK_LOG=${CGLZINK_LOG:-1} DYLD_INSERT_LIBRARIES=$LIB exec "$exe" "$@"
}

case "${1:-}" in
    list) list ;;
    add) [ $# -ge 2 ] || usage; add "$2" ;;
    remove) [ $# -ge 2 ] || usage; remove "$2" ;;
    status) status ;;
    run) [ $# -ge 2 ] || usage; shift; run "$@" ;;
    *) usage ;;
esac
