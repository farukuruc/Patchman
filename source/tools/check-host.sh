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
for file in "$HERE"/src/runtime/*.sh "$HERE"/src/installer/*.sh; do sh -n "$file"; done
echo 'PASS portable host source checks; no firmware or device writes performed'
