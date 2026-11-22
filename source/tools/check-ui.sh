#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
[ "$#" = 1 ] || { echo 'Usage: bash source/tools/check-ui.sh ORIGINAL_PLAYER'; exit 2; }
BUILD="$(mktemp -d /tmp/patchman-source-ui.XXXXXX)"
cleanup(){ case "$BUILD" in /tmp/patchman-source-ui.*) rm -rf -- "$BUILD" ;; esac; }
trap cleanup EXIT
python3 "$HERE/tools/check-source.py"
python3 "$HERE/tools/apply-player-patches.py" "$1" "$BUILD/player"
python3 "$HERE/tests/ui/prepare-fixture.py" "$BUILD/player/HgrmMediaPlayerApp" "$BUILD/fixture"
g++ -std=c++17 -fPIC -no-pie -Wall -Wextra -Werror "$HERE/tests/ui/layout.cpp" $(pkg-config --cflags --libs Qt5Quick Qt5Qml Qt5Gui Qt5Core) -o "$BUILD/layout-test"
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software "$BUILD/layout-test" "$BUILD/fixture"
echo 'PASS public v1.5.1 source UI checks; no device writes performed'
