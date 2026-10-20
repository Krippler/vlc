#!/usr/bin/env bash
# Build VLC and package it as an x86_64 AppImage.
#
# The build dependencies listed in ubuntu-deps.txt must be installed
# (Ubuntu 24.04), the media library and the AppImage tools are fetched
# by this script.
#
# usage: extras/package/appimage/build-appimage.sh
#
# environment:
#   WORK_DIR   build directory (default: <source>/build-appimage)
#   VERSION    version written in the file name (default: git describe)
#   JOBS       number of parallel jobs (default: nproc)

set -euo pipefail

SRC_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
PKG_DIR="$SRC_DIR/extras/package/appimage"
WORK_DIR=${WORK_DIR:-"$SRC_DIR/build-appimage"}
VERSION=${VERSION:-$(git -C "$SRC_DIR" describe --tags --always --dirty 2>/dev/null || echo dev)}
JOBS=${JOBS:-$(nproc)}

MEDIALIBRARY_VERSION=0.13.2
LINUXDEPLOY_URL=https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
LINUXDEPLOY_QT_URL=https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage

APPDIR="$WORK_DIR/AppDir"
DEPS_PREFIX="$WORK_DIR/deps"
TOOLS_DIR="$WORK_DIR/tools"
OUTPUT="$WORK_DIR/VLC-${VERSION#v}-x86_64.AppImage"

# the AppImage tools are themselves AppImages, run them without FUSE
export APPIMAGE_EXTRACT_AND_RUN=1

log() { printf '\n==> %s\n' "$*"; }

mkdir -p "$WORK_DIR" "$TOOLS_DIR"

# --- meson ------------------------------------------------------------------
# VLC requires a recent meson, newer than the one of the distribution
log "meson"
if [ ! -x "$TOOLS_DIR/venv/bin/meson" ]; then
    python3 -m venv "$TOOLS_DIR/venv"
    "$TOOLS_DIR/venv/bin/pip" install --quiet "meson>=1.10"
fi
MESON="$TOOLS_DIR/venv/bin/meson"
"$MESON" --version

# --- media library ------------------------------------------------------------
# the distribution package is too old for VLC 4
log "medialibrary $MEDIALIBRARY_VERSION"
if [ ! -f "$DEPS_PREFIX/lib/pkgconfig/medialibrary.pc" ]; then
    ML_SRC="$WORK_DIR/medialibrary-$MEDIALIBRARY_VERSION"
    if [ ! -d "$ML_SRC" ]; then
        curl -fsSL "https://code.videolan.org/videolan/medialibrary/-/archive/$MEDIALIBRARY_VERSION/medialibrary-$MEDIALIBRARY_VERSION.tar.bz2" \
            | tar -xj -C "$WORK_DIR"
    fi
    "$MESON" setup --reconfigure "$WORK_DIR/medialibrary-build" "$ML_SRC" \
        --prefix="$DEPS_PREFIX" --libdir=lib --buildtype=release \
        -Dlibvlc=disabled -Dtests=disabled
    "$MESON" compile -C "$WORK_DIR/medialibrary-build" -j "$JOBS"
    "$MESON" install -C "$WORK_DIR/medialibrary-build" --quiet
fi
export PKG_CONFIG_PATH="$DEPS_PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export LD_LIBRARY_PATH="$DEPS_PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# --- VLC ----------------------------------------------------------------------
# installed in /usr/lib (not the multiarch directory) so that the libraries
# deployed next to libvlccore keep the plugins at the expected relative path
log "VLC"
"$MESON" setup --reconfigure "$WORK_DIR/vlc-build" "$SRC_DIR" \
    --prefix=/usr --libdir=lib --buildtype=release \
    -Dqt=enabled -Dmedialibrary=enabled -Dlua=enabled \
    -Dwayland=disabled -Dtests=disabled
"$MESON" compile -C "$WORK_DIR/vlc-build" -j "$JOBS"

rm -rf "$APPDIR"
DESTDIR="$APPDIR" "$MESON" install -C "$WORK_DIR/vlc-build" --no-rebuild --quiet

# development files are not needed at runtime
rm -rf "$APPDIR/usr/include" "$APPDIR/usr/lib/pkgconfig"
find "$APPDIR/usr/lib" -name '*.a' -delete

# the lua scripts (playlist parsers, extensions...) are not installed by meson
mkdir -p "$APPDIR/usr/share/vlc"
cp -r "$SRC_DIR/share/lua" "$APPDIR/usr/share/vlc/lua"
find "$APPDIR/usr/share/vlc/lua" -name '*.am' -delete

# desktop entry and icon
install -Dm644 "$PKG_DIR/vlc.desktop" "$APPDIR/usr/share/applications/vlc.desktop"
install -Dm644 "$SRC_DIR/share/icons/256x256/vlc.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/vlc.png"

# --- AppImage -----------------------------------------------------------------
log "AppImage tools"
for url in "$LINUXDEPLOY_URL" "$LINUXDEPLOY_QT_URL"; do
    tool="$TOOLS_DIR/$(basename "$url")"
    [ -x "$tool" ] || { curl -fsSL -o "$tool" "$url"; chmod +x "$tool"; }
done

log "deploying the dependencies"
# the dependencies of the plugins are deployed too, they are loaded at runtime
deploy_args=()
while IFS= read -r dir; do
    deploy_args+=(--deploy-deps-only="$dir")
done < <(find "$APPDIR/usr/lib/vlc" -name '*.so' -printf '%h\n' | sort -u)
for helper in "$APPDIR"/usr/libexec/vlc/vlc-*; do
    [ -x "$helper" ] && deploy_args+=(--deploy-deps-only="$helper")
done

# libvlc, libvlccore and the private libraries used by the plugins
export LD_LIBRARY_PATH="$APPDIR/usr/lib:$APPDIR/usr/lib/vlc:$LD_LIBRARY_PATH"

export QMAKE=${QMAKE:-$(command -v qmake6)}
export QML_SOURCES_PATHS="$SRC_DIR/modules/gui/qt"
export EXTRA_QT_MODULES="svg"
export LDAI_OUTPUT="$OUTPUT"
export LINUXDEPLOY_OUTPUT_VERSION="${VERSION#v}"

"$TOOLS_DIR/linuxdeploy-x86_64.AppImage" \
    --appdir "$APPDIR" \
    --executable "$APPDIR/usr/bin/vlc" \
    --desktop-file "$APPDIR/usr/share/applications/vlc.desktop" \
    --icon-file "$APPDIR/usr/share/icons/hicolor/256x256/apps/vlc.png" \
    --custom-apprun "$PKG_DIR/AppRun" \
    "${deploy_args[@]}" \
    --plugin qt

# Qt reads qt.conf next to the executable: the helpers running Qt need it too
cp "$APPDIR/usr/bin/qt.conf" "$APPDIR/usr/libexec/vlc/qt.conf"
sed -i 's|^Prefix = .*|Prefix = ../../|' "$APPDIR/usr/libexec/vlc/qt.conf"

# the plugins cache speeds up the startup, it is generated once deployed
log "plugins cache"
"$APPDIR/usr/libexec/vlc/vlc-cache-gen" "$APPDIR/usr/lib/vlc/plugins"

"$TOOLS_DIR/linuxdeploy-x86_64.AppImage" --appdir "$APPDIR" --output appimage

log "done: $OUTPUT"
