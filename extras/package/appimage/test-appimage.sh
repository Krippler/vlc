#!/usr/bin/env bash
# Test a VLC AppImage on a system without its build dependencies.
#
# Meant to run as root in a minimal Debian container, see the "Linux
# AppImage" workflow. It installs the base libraries any desktop provides,
# then, as an unprivileged user:
#   - decodes the given clip, to check that the plugins load
#   - starts the Qt interface on a virtual X server, to check that the
#     bundled Qt and its plugins are used (they are not on this system)
#
# usage: test-appimage.sh <VLC AppImage> <clip>

set -euo pipefail

APPIMAGE=$(readlink -f "$1")
CLIP=$(readlink -f "$2")
LOGS=$(mktemp -d)
chmod 755 "$LOGS"

if [ "$(id -u)" = 0 ] && command -v apt-get > /dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    # X server for the test, then the libraries an AppImage expects from the host
    apt-get install -y -qq --no-install-recommends xvfb xauth \
        libx11-6 libx11-xcb1 libxcb1 libxext6 libxrender1 \
        libgl1 libegl1 libopengl0 libglx-mesa0 libgl1-mesa-dri \
        libfontconfig1 fonts-dejavu-core libfreetype6 libharfbuzz0b libfribidi0 \
        libasound2t64 libsm6 libice6 libgpg-error0 libcom-err2 > /dev/null
fi

# VLC refuses to run as root
run=()
if [ "$(id -u)" = 0 ]; then
    id vlctest > /dev/null 2>&1 || useradd -m vlctest
    run=(runuser -u vlctest --)
fi

export APPIMAGE_EXTRACT_AND_RUN=1

# the AppImage is extracted in a temporary directory of the test user
TMPDIR=$(mktemp -d)
export TMPDIR
[ ${#run[@]} -gt 0 ] && chown vlctest "$TMPDIR"

echo "==> version"
"${run[@]}" "$APPIMAGE" --version

echo "==> decoding $CLIP"
"${run[@]}" "$APPIMAGE" -I dummy --vout=dummy --aout=dummy --play-and-exit -vv \
    "$CLIP" > "$LOGS/decode.log" 2>&1 || true
grep -E 'using (video|audio) decoder module' "$LOGS/decode.log"
grep -q 'using video decoder module "avcodec"' "$LOGS/decode.log"
if grep -E 'cannot load plug-in' "$LOGS/decode.log"; then
    echo "error: some plugins cannot be loaded"
    exit 1
fi

echo "==> Qt interface"
"${run[@]}" timeout 20 \
    xvfb-run -a -s '-screen 0 1280x800x24' \
    "$APPIMAGE" -I qt --qt-verbose -vv --no-qt-privacy-ask \
    > "$LOGS/qt.log" 2>&1 || true
if ! grep -q 'using interface module "qt"' "$LOGS/qt.log"; then
    grep -iE 'qt|platform' "$LOGS/qt.log" | tail -n 30
    echo "error: the Qt interface did not start"
    exit 1
fi
echo "the Qt interface started"
