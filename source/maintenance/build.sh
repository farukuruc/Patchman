#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/../.." && pwd)"
WORK="$PROJECT/work/Patchman-v1.5-Final"
BUILD="$PROJECT/work/Patchman-v1.5-Final-build"
TOOL="$HOME/cinder-build/artifacts/repos/nw-installer/tools/upgtool/upgtools/upgtool"
test -x "$TOOL"
mkdir -p "$WORK" "$BUILD"
python3 "$HERE/prepare.py"
python3 "$HERE/tests/test-prepare.py"
bash "$HERE/test-ui.sh" 2>&1 | tee "$WORK/ui-test-results.log"
for file in "$HERE"/scripts/*.sh "$WORK/guard"; do sh -n "$file"; done
python3 "$HERE/tests/test-package.py" 2>&1 | tee "$WORK/test-results.log"
pack(){
    local action="$1";shift
    local upg="$HERE/$action/Data/Device/NW_WM_FW.UPG"
    "$TOOL" -w -m nw-wm1a --create "$upg" "$HERE/scripts/exec_file.sh" "$@"
    mkdir -p "$BUILD/verify-$action"
    "$TOOL" -w -m nw-wm1a -e -o "$BUILD/verify-$action/" "$upg"
    local i=0
    for file in "$HERE/scripts/exec_file.sh" "$@"; do
        cmp -s -n "$(stat -c%s "$file")" "$file" "$BUILD/verify-$action/$i.bin"
        i=$((i+1))
    done
    echo "PASS full installer UPG round-trip: $action"
}
pack Install "$HERE/scripts/install.sh" "$WORK/bundle.tar.gz"
pack Remove "$HERE/scripts/remove.sh"
pack ReturnToConfirmed "$HERE/scripts/return-stable.sh" "$WORK/return-stable.tar.gz"
pack ReturnToV1.1 "$HERE/scripts/return-v11.sh" "$WORK/return-v11.tar.gz"
(cd "$HERE" && sha256sum Install/Data/Device/NW_WM_FW.UPG Remove/Data/Device/NW_WM_FW.UPG ReturnToConfirmed/Data/Device/NW_WM_FW.UPG ReturnToV1.1/Data/Device/NW_WM_FW.UPG > SHA256SUMS.txt)
python3 "$HERE/zip-release.py"
echo 'DONE: Patchman_NW-A55.zip; v1.5-stable complete installer and v1.1 update; Unit Information v1.5; Install/Remove/ReturnToV1.1 included'
