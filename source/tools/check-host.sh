#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$(mktemp -d /tmp/patchman-source-check.XXXXXX)"
cleanup(){ case "$BUILD" in /tmp/patchman-source-check.*) rm -rf -- "$BUILD" ;; esac; }
trap cleanup EXIT
python3 "$HERE/tools/check-source.py"
export CARGO_MANIFEST_DIR="$HERE/third_party/cinder/player/cinder-ui"
python3 - "$HERE" "$BUILD" <<'PY'
import pathlib,sys
here,build=map(pathlib.Path,sys.argv[1:])
common='#[allow(dead_code)]\n#[path = r#"'+(here/'third_party/cinder/player/cinder-ui/src/hp_eq.rs').as_posix()+'"#]\nmod hp_eq;\n'
(build/'profile.rs').write_text(common+'include!(r#"'+(here/'src/peq/profile-main.rs').as_posix()+'"#);\n')
(build/'ui.rs').write_text(common+'#[allow(dead_code)]\nmod profile { use crate::hp_eq;\ninclude!(r#"'+(here/'src/peq/profile-main.rs').as_posix()+'"#);\ninclude!(r#"'+(here/'src/peq/ui-core.rs').as_posix()+'"#);\n}\nfn main(){profile::ui_main();}\n')
PY
rustc --edition=2021 --test "$BUILD/profile.rs" -o "$BUILD/profile-tests"
"$BUILD/profile-tests"
rustc --edition=2021 --test "$BUILD/ui.rs" -o "$BUILD/ui-tests"
"$BUILD/ui-tests"
cc -std=c11 -O2 -Wall -Wextra -Wno-misleading-indentation -I"$HERE/src/library" "$HERE/src/library/cache-builder.c" -lsqlite3 -o "$BUILD/cache-host"
python3 "$HERE/tests/test-photos.py" "$BUILD/cache-host"
# LD_PRELOAD cannot use a path containing spaces, so binaries live in /tmp.
python3 "$HERE/tests/sort-fixture.py" "$BUILD"
FLAGS=(-std=c11 -O2 -Wall -Wextra -Werror -Wno-misleading-indentation -I"$HERE/src/library")
cc -shared -fPIC "${FLAGS[@]}" "$HERE/tests/media-client-mock.c" -o "$BUILD/libMediaStoreServiceClient.so"
cc "${FLAGS[@]}" "$HERE/tests/native-order-driver.c" -L"$BUILD" -lMediaStoreServiceClient -Wl,-rpath,"$BUILD" -o "$BUILD/order-driver"
cc "${FLAGS[@]}" "$HERE/tests/sorting.c" -L"$BUILD" -lMediaStoreServiceClient -Wl,-rpath,"$BUILD" -o "$BUILD/sorting"
DEFS=(-DPM_YEAR_TEST "-DCACHE_PATH=\"$BUILD/album-years.bin\"" "-DSORT_PATH=\"$BUILD/album-sort.txt\"" "-DLOG_PATH=\"$BUILD/order.log\"")
cc -shared -fPIC "${FLAGS[@]}" "${DEFS[@]}" "$HERE/src/library/native-years.c" -ldl -lpthread -o "$BUILD/sort.so"
LD_PRELOAD="$BUILD/sort.so" "$BUILD/order-driver"
LD_PRELOAD="$BUILD/sort.so" "$BUILD/sorting" "$BUILD/album-sort.txt"
printf bad > "$BUILD/album-years.bin"
LD_PRELOAD="$BUILD/sort.so" "$BUILD/order-driver" fallback
LD_PRELOAD="$BUILD/sort.so" "$BUILD/sorting" "$BUILD/album-sort.txt" no-cache
for file in "$HERE"/src/runtime/*.sh "$HERE"/src/installer/*.sh; do sh -n "$file"; done
echo 'PASS portable host source checks; no firmware or device writes performed'
