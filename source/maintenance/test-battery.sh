#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/../.." && pwd)"
BUILD="$PROJECT/work/Patchman-v1.5.1-build"
python3 "$HERE/tests/setup-battery.py"
g++ -std=c++17 -fPIC -no-pie -Wall -Wextra -Werror "$HERE/tests/battery.cpp" $(pkg-config --cflags --libs Qt5Quick Qt5Qml Qt5Gui Qt5Core) -o "$BUILD/battery-test"
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_XHR_ALLOW_FILE_READ=1 QML_XHR_ALLOW_FILE_WRITE=1 "$BUILD/battery-test" "$HERE/source/topbar"
python3 "$HERE/tests/prepare-header-fixture.py" "$BUILD/header-fixture"
g++ -std=c++17 -fPIC -no-pie -Wall -Wextra -Werror "$HERE/tests/header.cpp" $(pkg-config --cflags --libs Qt5Quick Qt5Qml Qt5Gui Qt5Core) -o "$BUILD/header-test"
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_XHR_ALLOW_FILE_READ=1 QML_XHR_ALLOW_FILE_WRITE=1 "$BUILD/header-test" "$BUILD/header-fixture"
