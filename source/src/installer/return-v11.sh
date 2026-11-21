#!/bin/sh
# Adapted from Cinder's updater mount verification. /proc may be absent.
album_mount_data() {
    AM_DATA=${1:-/data}
    AM_MOUNTS=${2:-/proc/mounts}
    if "$BB" grep -q " $AM_DATA " "$AM_MOUNTS" 2>/dev/null; then
        echo "state: data already mounted"
        return 0
    fi
    "$BB" mkdir -p "$AM_DATA" || return 1
    AM_MARKER="$AM_DATA/.sony_album_premount"
    AM_TOKEN="sony-album-premount $$"
    AM_SENTINEL=0
    if (echo "$AM_TOKEN" > "$AM_MARKER") 2>/dev/null; then
        [ "$("$BB" cat "$AM_MARKER" 2>/dev/null)" = "$AM_TOKEN" ] && AM_SENTINEL=1
    fi
    album_data_mounted() {
        if [ "$AM_SENTINEL" = 1 ]; then
            [ "$("$BB" cat "$AM_MARKER" 2>/dev/null)" != "$AM_TOKEN" ]
        else
            "$BB" grep -q " $AM_DATA " "$AM_MOUNTS" 2>/dev/null
        fi
    }
    mount -t ext4 -o rw /emmc@usrdata "$AM_DATA" 2>/dev/null || :
    if ! album_data_mounted; then
        mount -o remount,rw /emmc@usrdata "$AM_DATA" 2>/dev/null || :
    fi
    if ! album_data_mounted; then
        mount -t ext4 -o rw /dev/block/mmcblk0p28 "$AM_DATA" 2>/dev/null || :
    fi
    AM_OK=0
    album_data_mounted && AM_OK=1
    "$BB" rm -f "$AM_MARKER" 2>/dev/null
    [ "$AM_OK" = 1 ] || return 1
    echo "state: data mount verified"
}

#!/bin/sh
BB=/xbin/busybox
[ -x "$BB" ] || BB=/system/xbin/busybox
[ -x "$BB" ] || exit 0
BIN=/system/vendor/sony/bin
ROOT=/system/vendor/sony-peq
STATE=/data/sony-peq
BOOT=/system/bin/bootswitcher.sh
ORIGINAL_HAGO=fe4adf07775dc447c18a22a63fb0b59168cce9159bfc509d122ae3d991248a85
ORIGINAL_BOOT=7675f7d234b0abadf2909f2e9a274d51fe1d02620d776c4ac6d2ce865ecac358
ORIGINAL_LAUNCH=b56b7f7a4d8ba8b450711f8b71fdc19890af2e7fafea467364c3c713def41928
WRAPPER_SHA=74715c1c09cdb0c7b034e4b3629eebb04ed49054748e4e60f6101c8f2e8d6e57
BOOT_SHA=80a34a619b77165ba66018cc845c7f0ba24b21774caab303c2264c2b4bf9323c
LAUNCH_SHA=7e9e4d9ac22a0998e40e7443acb443444e940efb5ea7499dd68e27c17769daac
BUILD_ID=29531c4aef554c17a01bac2eea8d9f8d86201bb417673f40dafb67d59d6e0eeb
fail() { echo "ERROR: $*"; sync; exit 0; }
hash_is() { [ "$("$BB" sha256sum "$1" 2>/dev/null | "$BB" cut -d' ' -f1)" = "$2" ]; }
put() {
    "$BB" cp "$1" "$2.peq-tmp" || return 1
    "$BB" cmp -s "$1" "$2.peq-tmp" || return 1
    "$BB" chown "${4:-0:0}" "$2.peq-tmp" || return 1
    "$BB" chmod "$3" "$2.peq-tmp" || return 1
    "$BB" mv -f "$2.peq-tmp" "$2"
}
restore_daemon() {
    hash_is "$BIN/hagodaemon" "$ORIGINAL_HAGO" && return 0
    if [ "${1:-}" != recovery ]; then
        hash_is "$BIN/hagodaemon" "$WRAPPER_SHA" || return 1
    fi
    hash_is "$BIN/hagodaemon.peq-original" "$ORIGINAL_HAGO" || return 1
    mount -o remount,rw /system 2>/dev/null || mount -o remount,rw /emmc@android /system 2>/dev/null || return 1
    put "$BIN/hagodaemon.peq-original" "$BIN/hagodaemon" 755 0:2000 || return 1
    hash_is "$BIN/hagodaemon" "$ORIGINAL_HAGO"
}

# Never leave an incomplete replacement consuming the destination filesystem.
put() {
    if ! "$BB" cp "$1" "$2.peq-tmp" ||
       ! "$BB" cmp -s "$1" "$2.peq-tmp" ||
       ! "$BB" chown "${4:-0:0}" "$2.peq-tmp" ||
       ! "$BB" chmod "$3" "$2.peq-tmp" ||
       ! "$BB" mv -f "$2.peq-tmp" "$2"; then
        "$BB" rm -f "$2.peq-tmp"
        return 1
    fi
}
restore_if_changed() {
    "$BB" cmp -s "$1" "$2" && return 0
    put "$@"
}
available_kib() {
    FREE_KIB="$("$BB" df -Pk "$1" 2>/dev/null | "$BB" awk 'NR>1 {print $(NF-2)}' | "$BB" tail -1)"
    case "$FREE_KIB" in ''|*[!0-9]*) return 1 ;; esac
    echo "$FREE_KIB"
}
require_space() {
    FREE_KIB="$(available_kib "$1")" || fail "Cannot determine free space: $1"
    echo "space: $1 available=${FREE_KIB}KiB required=${2}KiB"
    [ "$FREE_KIB" -ge "$2" ] || fail "Insufficient space on $1; need ${2}KiB, available ${FREE_KIB}KiB"
}

known_player() {
  hash_is "$1" "3e7bdb894cf9a1a8599f04651168fdcfe524c5c829113900b7b6e99f45413a2d" && return 0
  hash_is "$1" "5dac3d022189a3e940b0cc8fb7ecdb93baebf82c01dc35c86638a72c02397830" && return 0
  hash_is "$1" "9f4dc0e4b9d53c4847d63c2226bc72c30276c2373b6268424f83b0c1e5e5b6c9" && return 0
  hash_is "$1" "a3856572beeea8c39d29f0b0eebe3b1b040e645121ba728ff7a7eab11efc8b0e" && return 0
  hash_is "$1" "c7667d5ce808fc5954c5a28b7f04f35f11fd6f1ad49d2c2be274625141c30e34" && return 0
  hash_is "$1" "eb0ac7270fc7bca791288d632ccab35c75e61e0884a329a965845b709ba037da" && return 0
  hash_is "$1" "04d9e3700173bbd92714318134dc955a1f8c949cf2613717d32d415da53ae7aa" || hash_is "$1" "0bacf756d34d7eae98ca2095ebb6be62150fc2747b6611c31a834478ae362967" || hash_is "$1" "171749afa0a1fba5252e15d308c47602110dfe19ccbc15d389204e215e27bdf9" || hash_is "$1" "18a0715d6f52c4b672679fe455fdfb2477891f9b474e04c955bca93d032153b1" || hash_is "$1" "27346894f118ff80aad15d154e6782862642a71856eea4d7989eb0bf6b00a9ce" || hash_is "$1" "2866d06db0208eafa78ee63bd0d057d1a1b7bb1e7f35a2615bc00124e4488328" || hash_is "$1" "3bfb9cd2e1c19d0cc6b9b4be3340b0f97408d80cafd3eaaa550a5f41f5c26920" || hash_is "$1" "3faa9c835e4d4a0ef5122863fa180b4f3e907b2e64f62ca1deb7b1080a0291a4" || hash_is "$1" "44d65f50b296d341bcb1f952aa5df5c5749c1ba2f32f3ea7b971252b1d3d5b25" || hash_is "$1" "46356ff807d28bce13f91b9d632d3dc36b0e968cd8a672f329e9741b2eaf29da" || hash_is "$1" "4e655e4dc5639dc1fcbad0e8f5162f4ea2b022105464c7a67ea05ceb9b275525" || hash_is "$1" "53efcd59b471600d11c9740c3b1cc851232e10cefa663cedb017438388bcbaed" || hash_is "$1" "5fcc8d9e0feffc47cf475ad9140eda7b3618f78a4adec45c91d13de453a13e78" || hash_is "$1" "66fa72c8462a3b811ff47aef07c35e04a9a03d890e0049406c62e33cb7ebfd5f" || hash_is "$1" "6cf14803937b0a6288edb5051206d0055b83d7edbc12a30e27437ea073f96aad" || hash_is "$1" "6d92e5ab8977baab9cc2c1e8662555b070fdf4a00e2895cd28bc72fc230823a0" || hash_is "$1" "7d869a20c43e39c838caf31b231081df26a6483e51e0c1cbb37c0862a7877b26" || hash_is "$1" "8b5ce95fca8800d4883b9d34b8deed75ad48496e41a4af9d9114a6f038c321e3" || hash_is "$1" "9435227e4f1d86c2e7a4f05c82743836e60be7da8031610b0a74f7e9b026e69d" || hash_is "$1" "9d5c669c6a252529cc1fc95033d55228668d2d8b7269e803e8f3aebb885f1a6a" || hash_is "$1" "af584f917ac0c8b8846a42bfda4fb9735b46fb2e88051ae5da2cfaa21a851eb0" || hash_is "$1" "b6749522f599dc6d618a2af38aba5899dccb11eda1a6cbb19d5759c6194364e6" || hash_is "$1" "c1af5405f827f20c63f52673edf89f435f9d3b51d26df56e29d910ce2a6677b7" || hash_is "$1" "c866867bb5cc7108507f74b982320842f5f8d0264ba4c506d30de18b1363360f" || hash_is "$1" "ca619c7c2bdcf04ee767b9854be641d999699e3eaac9155509eef8c848a8b867" || hash_is "$1" "d3d35c411c3e461c2844e9d1f0308fcc34584faa8cf8753bef7ff24ca8e58f85" || hash_is "$1" "d44c39f1667673547b01c9d3f96943e7602c8abaee2acffae28d4452a2a29b04" || hash_is "$1" "e2290c55ed4d1bb844ff40353fda7b1d87b3b1678a9585beba2796ce4660f70a" || hash_is "$1" "e23f768be43f4bb2e8a164184198904bf5cc81d0a7fc05647e4fb116c7abd92a" || hash_is "$1" "ed2dcbb244c44e651f454dded96a62c6cf5f436f7205fa203eea42c2a7a30a31"
}
known_launcher() {
  hash_is "$1" "1d61751a34427fdb6ad6e362be67aed8cf62c0b945645496aa18729ed849ecc1" && return 0
  hash_is "$1" "16776766acad8995b37f73327543ec9c0d8d9b6ec35742a4e16ee096f0a86659" || hash_is "$1" "2d308c288843ae786a3a245bdcd8a0b7907397b68447ee8be8ea1fe4116590a0" || hash_is "$1" "2f19442a4ab9558ca82c7169f0b44ef538fc432b74f470b04c94fd22513e1b14" || hash_is "$1" "4d5d9965367b417cbbd8cd3c2a620b06e7b3d614a5b6295155a9450f7ac339a6" || hash_is "$1" "5a0206611fae40bda481dacd0db0f32e8a5102ef291547987444292e00b3f951" || hash_is "$1" "63f63ea97b314c0c069fc778c13d2638c6ebae290590ee93091e6e2355c03c42" || hash_is "$1" "65fa43be9aa54fe467ea00be3c988999f3325f32b9b8b93ce98eb8f7a8fc09be" || hash_is "$1" "6ca0bfc02828b9b334637fc1b5d11c8d0b74bd144cd5fd71b671e655a3aa5342" || hash_is "$1" "718403b146ecd5295d1a642a74d763a2a9f66b6336980b3bd27fb89036fd58dc" || hash_is "$1" "73cf038b29b145a91e331ec1e8acdf6a332e0a889ccb96ca617dc1c2b22044e8" || hash_is "$1" "780dd41be79ef581a21d289e19e1778c4ffe592d70fce5e3acd3af03f4a41d02" || hash_is "$1" "7c5b47b678112e6030a50414e58dc774a505bf6d99983c38bbc3ca7db0e0e635" || hash_is "$1" "7e9e4d9ac22a0998e40e7443acb443444e940efb5ea7499dd68e27c17769daac" || hash_is "$1" "abcddb42a6b20ea5e3734b4c8a84834e2b34c5edc875e56f7c38a54ab0157a62" || hash_is "$1" "ad6f7f2af975da1d5b723bffdd2f42ef94053550176cbeeea41b98c8f1dceb87" || hash_is "$1" "b56b7f7a4d8ba8b450711f8b71fdc19890af2e7fafea467364c3c713def41928" || hash_is "$1" "bd1545aeae789141afa18772557a59c6caf0db41d33e411104f78e6c6bbaf8e6" || hash_is "$1" "c06a997ce0d400732152fe79eaad8bc9b7a366a98bb5d7bc53c668c56fc97720" || hash_is "$1" "c53c173613790e602fe8f4bba0f62378726dd12806de4ab7b0edd368a3cffa76" || hash_is "$1" "d746ebe52fd334b3399a9a41451e8c54ae7632295dac40f802a5a69345911490" || hash_is "$1" "e7659aa310adef4fc0485a2bd0b4f40aa31417b9f0ed00bdd94f1b363a6ad3af"
}
exec >>/contents/Patchman-install.log 2>&1
echo "Patchman return to v1.1-stable installer"
PM=/system/vendor/patchman
CFG=$BIN/HgrmMediaPlayerApp.appcfg
TMP=/data/patchman-install-stage
ARCHIVE_STAGE=/contents/.patchman-install-stage
MUTATED=0
STAGING_READY=0
ARCHIVE_READY=0
fail() {
    echo "ERROR: $*"
    RECOVERY_NEEDED=0
    if [ "$MUTATED" = 1 ]; then
        restore_if_changed "$TMP/before-config" "$CFG" 644 || { echo "ERROR: config rollback failed"; RECOVERY_NEEDED=1; }
        restore_if_changed "$TMP/before-daemon" "$BIN/hagodaemon" 755 0:2000 || { echo "ERROR: daemon rollback failed"; RECOVERY_NEEDED=1; }
        restore_if_changed "$TMP/before-boot" "$BOOT" 755 || { echo "ERROR: boot rollback failed"; RECOVERY_NEEDED=1; }
    fi
    if [ "$STAGING_READY" = 1 ] && [ "$RECOVERY_NEEDED" = 0 ]; then
        "$BB" rm -rf "$TMP"
    fi
    if [ "$ARCHIVE_READY" = 1 ] && [ "$RECOVERY_NEEDED" = 0 ]; then "$BB" rm -rf "$ARCHIVE_STAGE"; fi
    if [ "$RECOVERY_NEEDED" = 1 ]; then
        echo 1 > "$TMP/RECOVERY_REQUIRED"
        echo "Recovery snapshots retained: $TMP"
    fi
    sync
    exit 0
}
native_config() {
    "$BB" grep -q '^name: HgrmMediaPlayerApp$' "$1" && "$BB" grep -Eq '^command: (HgrmMediaPlayerApp|/system/vendor/sony/bin/HgrmMediaPlayerApp)$' "$1"
}
mount -t ext4 -o rw /emmc@android /system 2>/dev/null || :
mount -o remount,rw /emmc@android /system 2>/dev/null || :
[ -d /system/etc/.mod ] || fail "Install Walkman One first"
echo "player: expected=f515f75e48e84460c18707e5408c6c09c26a77a13deccdee23e220dc81f49124 actual=$("$BB" sha256sum "$BIN/HgrmMediaPlayerApp" 2>/dev/null | "$BB" cut -d' ' -f1)"
hash_is "$BIN/HgrmMediaPlayerApp" 'f515f75e48e84460c18707e5408c6c09c26a77a13deccdee23e220dc81f49124' || fail "Unsupported Walkman One player version"
{ hash_is "$BIN/hagodaemon" "$ORIGINAL_HAGO" || hash_is "$BIN/hagodaemon" "$WRAPPER_SHA"; } || fail "Unknown audio dispatcher; Wampy/other wrappers not supported"
{ hash_is "$BOOT" "$ORIGINAL_BOOT" || hash_is "$BOOT" "$BOOT_SHA"; } || fail "Unknown boot script"
hash_is /system/vendor/sony/lib/libMediaStoreServiceClient.so "d68beee36cbdd8987ea6e16876a1c9f66cd2936fd0d9ff048761aac64c8ebbaf" || fail "Unknown native media client"
album_mount_data || fail "Data partition unavailable"
"$BB" grep -q '^name: HgrmMediaPlayerApp$' "$CFG" || fail "Unknown app config"
"$BB" grep -Eq '^command: (HgrmMediaPlayerApp|/system/vendor/sony/bin/HgrmMediaPlayerApp|/system/vendor/sony/bin/sony-album-launch.sh)$' "$CFG" || fail "Unknown player launcher"
if [ -e "$BIN/HgrmMediaPlayerApp.album-test" ]; then
    known_player "$BIN/HgrmMediaPlayerApp.album-test" || fail "Unknown alternate player"
fi
if [ -e "$BIN/sony-album-launch.sh" ]; then
    known_launcher "$BIN/sony-album-launch.sh" || fail "Unknown launcher contents"
fi
if [ -e "$ROOT/libsony_peq.so" ]; then hash_is "$ROOT/libsony_peq.so" "38d0fadda997b6b94c8785083436218d722dd1c4831d9c3ed8c20f04bedcdb5d" || fail "Unknown existing shim"; fi
if [ -e "$ROOT/sony-peq-profile" ]; then hash_is "$ROOT/sony-peq-profile" "590d77e4aa4ba1ce750a307283d31d3b41a6dbb8c79b3e711543393009b4ae5a" || fail "Unknown existing profile"; fi
if [ -e "$ROOT/sony-peq-ui" ]; then hash_is "$ROOT/sony-peq-ui" "d4a7936da4e8b6d1a389ef19db1b861f5eb897d33ed116e56c947e6c5b0ce5b0" || fail "Unknown existing ui-helper"; fi
[ ! -f "$TMP/RECOVERY_REQUIRED" ] && [ ! -f "$ARCHIVE_STAGE/work/RECOVERY_REQUIRED" ] || fail "Pending recovery snapshots require review"
[ ! -L "$TMP" ] || fail "Unexpected staging symlink"
"$BB" rm -rf "$TMP" || fail "Clear previous staging directory"
[ ! -L "$ARCHIVE_STAGE" ] || fail "Unexpected archive staging symlink"
"$BB" rm -rf "$ARCHIVE_STAGE" || fail "Clear previous archive staging"
require_space /data 4096
require_space /system 28424
require_space /contents 10525
"$BB" mkdir -p "$ARCHIVE_STAGE" || fail "Archive staging directory"
ARCHIVE_READY=1
UPG="/contents/$(nvpstr ufn).UPG"
fwpchk -f "$UPG" -c -2 "$ARCHIVE_STAGE/bundle.raw" || fail "Extract bundle"
BUNDLE_HASH="$("$BB" head -c 9663367 "$ARCHIVE_STAGE/bundle.raw" | "$BB" sha256sum | "$BB" cut -d' ' -f1)"
[ "$BUNDLE_HASH" = 'dd3c478d49936304144a1e4623e945bc9fd79a152c82db0dbd51f4abda990ef4' ] || fail "Bundle checksum"
STREAM_OK=0
if "$BB" head -c 9663367 "$ARCHIVE_STAGE/bundle.raw" 2>/dev/null | "$BB" tar -xzOf - queue-cache > "$ARCHIVE_STAGE/probe" 2>/dev/null; then
    hash_is "$ARCHIVE_STAGE/probe" '651027e7d13f1d5752a21c9077633b406ff1fc250a5efa6fbb616996f3f82ea3' && STREAM_OK=1
fi
"$BB" rm -f "$ARCHIVE_STAGE/probe"
CONTENTS_FREE="$(available_kib /contents)" || fail "Cannot query extraction space"
if [ "$STREAM_OK" = 1 ] && [ "$CONTENTS_FREE" -ge 20864 ]; then
    TMP=$ARCHIVE_STAGE/work
    MODE=contents
    echo "mode: contents extraction; small data partition reserved for runtime"
else
    MODE=data
    require_space /data 18728
    echo "mode: ext4 fallback; tar stdout unavailable or contents space limited"
fi
"$BB" mkdir -p "$TMP" || fail "Temporary directory"
STAGING_READY=1
if [ "$MODE" = data ]; then "$BB" chmod 700 "$TMP" || fail "Staging permissions"; fi
"$BB" mkdir -p "$TMP/files" || fail "Bundle directory"
if [ "$MODE" = contents ]; then
    for member in shim profile ui-helper guard panel queue-cache log-policy goto-navigator goto-logic goto-native goto-status goto-target audio-path audio-path-labels cassette preferences tape reels wrapper boot original-daemon original-boot gate year-shim year-builder year-view year-exec year-js year-status photo-view photo-component player launcher; do
        "$BB" head -c 9663367 "$ARCHIVE_STAGE/bundle.raw" | "$BB" tar -xzOf - "$member" > "$TMP/files/$member" || fail "Extract member: $member"
    done
else
    "$BB" head -c 9663367 "$ARCHIVE_STAGE/bundle.raw" | "$BB" tar -xzf - -C "$TMP/files" || fail "Unpack bundle"
fi
"$BB" rm -f "$ARCHIVE_STAGE/bundle.raw" || fail "Release archive"
hash_is "$TMP/files/shim" "38d0fadda997b6b94c8785083436218d722dd1c4831d9c3ed8c20f04bedcdb5d" || fail "Payload checksum: shim"
hash_is "$TMP/files/profile" "590d77e4aa4ba1ce750a307283d31d3b41a6dbb8c79b3e711543393009b4ae5a" || fail "Payload checksum: profile"
hash_is "$TMP/files/ui-helper" "d4a7936da4e8b6d1a389ef19db1b861f5eb897d33ed116e56c947e6c5b0ce5b0" || fail "Payload checksum: ui-helper"
hash_is "$TMP/files/guard" "41da865dd8395ffad28121d9ddd51eec5c79fe0ed1ab7d95bcc909b1b707ff0e" || fail "Payload checksum: guard"
hash_is "$TMP/files/panel" "bf7f0e5915dbbdc08ef5c1117c516b9764bf014865b98d8a8631310b54c70039" || fail "Payload checksum: panel"
hash_is "$TMP/files/queue-cache" "651027e7d13f1d5752a21c9077633b406ff1fc250a5efa6fbb616996f3f82ea3" || fail "Payload checksum: queue-cache"
hash_is "$TMP/files/log-policy" "20db2711758b0c05804623d6955ba6ce46695ee02be01a1a9c511f4800b1b032" || fail "Payload checksum: log-policy"
hash_is "$TMP/files/goto-navigator" "a0f8559b39b863b159ebe5031c92ba1e8a8f01451c96f146a85efd4b4ebb4469" || fail "Payload checksum: goto-navigator"
hash_is "$TMP/files/goto-logic" "154ef0af9f800570e840e5c94e918d719b37b703d959a6ba8b321d65596cdfde" || fail "Payload checksum: goto-logic"
hash_is "$TMP/files/goto-native" "a1a79f681cbf12d4f416db4a2df2b782ab95a3d43dfc43ff775f0b9ee177de3f" || fail "Payload checksum: goto-native"
hash_is "$TMP/files/goto-status" "367fdf9d213b882cebc499fdd7a7a1b9deb5ae78b6873127d9a3db9b228592f6" || fail "Payload checksum: goto-status"
hash_is "$TMP/files/goto-target" "ba3e334a06ad58c2dff9c930e8835791c47902d1a9d5466d09603b706328a45d" || fail "Payload checksum: goto-target"
hash_is "$TMP/files/audio-path" "8e8c5a32a04d398048455395c645bdf8120ccfafbf9365546205b001436f2135" || fail "Payload checksum: audio-path"
hash_is "$TMP/files/audio-path-labels" "3a7ed60154738740c835eb20040269ff88fa79612309971212514002405fb179" || fail "Payload checksum: audio-path-labels"
hash_is "$TMP/files/cassette" "703280ff616da59ded809cc4403cb86ec7853d2b223c6066deb7cfd9af2b3c33" || fail "Payload checksum: cassette"
hash_is "$TMP/files/preferences" "7affb5f939a28adbf6c8c3ac1a2daa081cf45d5826c152fc26f7fc4ae9ac5554" || fail "Payload checksum: preferences"
hash_is "$TMP/files/tape" "24b832295153a5891d9fe5ea8358de3d43844330457a81e9068b19aad35bfb36" || fail "Payload checksum: tape"
hash_is "$TMP/files/reels" "3b1091e96145b7f78d8a5b73acadc03931ebdef19fc28d3d6b4c5c1baebbfda4" || fail "Payload checksum: reels"
hash_is "$TMP/files/wrapper" "74715c1c09cdb0c7b034e4b3629eebb04ed49054748e4e60f6101c8f2e8d6e57" || fail "Payload checksum: wrapper"
hash_is "$TMP/files/boot" "80a34a619b77165ba66018cc845c7f0ba24b21774caab303c2264c2b4bf9323c" || fail "Payload checksum: boot"
hash_is "$TMP/files/original-daemon" "fe4adf07775dc447c18a22a63fb0b59168cce9159bfc509d122ae3d991248a85" || fail "Payload checksum: original-daemon"
hash_is "$TMP/files/original-boot" "7675f7d234b0abadf2909f2e9a274d51fe1d02620d776c4ac6d2ce865ecac358" || fail "Payload checksum: original-boot"
hash_is "$TMP/files/gate" "376310df505b7c2089d915607da45fabd871dea10972915bbc9d3d50846a40cd" || fail "Payload checksum: gate"
hash_is "$TMP/files/player" "6d92e5ab8977baab9cc2c1e8662555b070fdf4a00e2895cd28bc72fc230823a0" || fail "Payload checksum: player"
hash_is "$TMP/files/launcher" "c53c173613790e602fe8f4bba0f62378726dd12806de4ab7b0edd368a3cffa76" || fail "Payload checksum: launcher"

hash_is "$TMP/files/year-shim" "eb0457a72e32c4737b4872db977f9fbdfeeae60a249977fdfd5559d24b1a803c" || fail "Payload checksum: year-shim"
hash_is "$TMP/files/year-builder" "152ba6169bf20f434fe1a7cb4f4dc7d53433a61cb9a0da0d9339359690725150" || fail "Payload checksum: year-builder"
hash_is "$TMP/files/year-view" "75a47ea8ae1acc4644f2b30260e993bfc1a7b7264db660ac6ecb8af91cc4e07e" || fail "Payload checksum: year-view"
hash_is "$TMP/files/year-exec" "5be6786d5ce459646ed0c393d6f4b2dbcd4750ce1fbc5c5970dbf9b1f2e7118c" || fail "Payload checksum: year-exec"
hash_is "$TMP/files/year-js" "11749fa796d1aaeadc7b2c4ecdf12b8fdf7f7fab69af7cc7b25c5cccc42cddd8" || fail "Payload checksum: year-js"
hash_is "$TMP/files/year-status" "7919ecd8cc34fa7a9f9aef73a9c0144d4c5ad79d169ed59d80eb395e4ed4b75a" || fail "Payload checksum: year-status"

hash_is "$TMP/files/photo-view" "3c3c872290d110bbd05a9b93ce417badce84faa1c98caaa144cfbb408825f0ea" || fail "Payload checksum: photo-view"
hash_is "$TMP/files/photo-component" "67f98364331017c2850d49ce3a4783e68369b38f6c6d215131983dcc02d43f02" || fail "Payload checksum: photo-component"

# Locate the native config, rather than saving a previously modified command.
CFG_HASH="$("$BB" cat "$PM/backup/appcfg.sha256" 2>/dev/null)"
if native_config "$PM/backup/appcfg" && hash_is "$PM/backup/appcfg" "$CFG_HASH"; then
    CONFIG_SOURCE=$PM/backup/appcfg
elif native_config "$CFG"; then
    CONFIG_SOURCE=$CFG
elif native_config /data/sony-album-test/original.appcfg; then
    CONFIG_SOURCE=/data/sony-album-test/original.appcfg
else
    fail "Original Walkman One config backup unavailable"
fi
"$BB" cp "$CFG" "$TMP/before-config" || fail "Config snapshot"
"$BB" cp "$BIN/hagodaemon" "$TMP/before-daemon" || fail "Daemon snapshot"
"$BB" cp "$BOOT" "$TMP/before-boot" || fail "Boot snapshot"
"$BB" cp "$CONFIG_SOURCE" "$TMP/native-config" || fail "Native config snapshot"
"$BB" sed 's|^command:.*$|command: /system/vendor/sony/bin/sony-album-launch.sh|' "$TMP/native-config" > "$TMP/config" || fail "Prepare config"
"$BB" mkdir -p "$PM/backup" "$ROOT/backup" "$ROOT/ui" /system/vendor/sony-cassette/assets "$STATE/runtime" "$STATE/state" /data/sony-album-test/run /contents/PEQ || fail "Installation directories"
"$BB" chmod 755 "$PM" "$PM/backup" "$ROOT" "$ROOT/backup" "$ROOT/ui" /system/vendor/sony-cassette "$STATE" /data/sony-album-test || fail "Directory permissions"
"$BB" chmod 755 /system/vendor/sony-cassette/assets || fail "Asset permissions"
"$BB" chmod 777 "$STATE/runtime" "$STATE/state" /data/sony-album-test/run || fail "Runtime permissions"
put "$TMP/native-config" "$PM/backup/appcfg" 644 || fail "Native config backup"
"$BB" sha256sum "$PM/backup/appcfg" | "$BB" cut -d' ' -f1 > "$TMP/config.sha256" || fail "Config backup receipt"
put "$TMP/config.sha256" "$PM/backup/appcfg.sha256" 644 || fail "Save config receipt"
put "$TMP/files/original-daemon" "$PM/backup/hagodaemon" 755 0:2000 || fail "Native daemon backup"
put "$TMP/files/original-boot" "$PM/backup/bootswitcher.sh" 755 || fail "Native boot backup"

MUTATED=1
"$BB" mkdir -p /contents/ARTIST-PHOTOS || fail "Artist photo folder"
"$BB" mkdir -p "$PM/native-years" || fail "Artist photo UI directory"
"$BB" chmod 755 "$PM/native-years" || fail "Native library UI permissions"
put "$TMP/files/photo-view" "$PM/native-years/Artists.qml" 644 || fail "Stage photo-view"
put "$TMP/files/photo-component" "$PM/native-years/ArtistPhoto.qml" 644 || fail "Stage photo-component"
"$BB" mkdir -p "$PM/native-years" || fail "Native year UI directory"
put "$TMP/files/year-shim" "$PM/libalbum_years.so" 755 || fail "Stage year-shim"
put "$TMP/files/year-builder" "$PM/album-year-cache" 755 || fail "Stage year-builder"
put "$TMP/files/year-view" "$PM/native-years/ArtistAlbums.qml" 644 || fail "Stage year-view"
put "$TMP/files/year-exec" "$PM/exec-native-years" 755 || fail "Stage year-exec"
put "$TMP/files/year-js" "$STATE/runtime/AlbumYearCache.js" 666 || fail "Stage year-js"
put "$TMP/files/year-status" "$STATE/runtime/album-native-years.log" 666 || fail "Stage year-status"
trap 'fail interrupted' HUP INT TERM
put "$TMP/files/shim" "$ROOT/libsony_peq.so" 755 || fail "Stage shim"
put "$TMP/files/profile" "$ROOT/sony-peq-profile" 755 || fail "Stage profile"
put "$TMP/files/ui-helper" "$ROOT/sony-peq-ui" 755 || fail "Stage ui-helper"
put "$TMP/files/guard" "$ROOT/boot.sh" 755 || fail "Stage guard"
put "$TMP/files/panel" "$ROOT/ui/PeqPanel.qml" 644 || fail "Stage panel"
put "$TMP/files/queue-cache" "$ROOT/ui/QueueCache.js" 644 || fail "Stage queue-cache"
put "$TMP/files/log-policy" "$PM/log-policy.sh" 644 || fail "Stage log-policy"
put "$TMP/files/goto-navigator" "$ROOT/ui/GoToNavigator_v11.qml" 644 || fail "Stage goto-navigator"
put "$TMP/files/goto-logic" "$ROOT/ui/GoToLogic_v11.js" 644 || fail "Stage goto-logic"
put "$TMP/files/goto-native" "$ROOT/ui/GoToNative_v11.js" 644 || fail "Stage goto-native"
put "$TMP/files/goto-status" "$STATE/runtime/goto-navigation-b6.json" 666 || fail "Stage goto-status"
put "$TMP/files/goto-target" "$PM/goto-target" 755 || fail "Stage goto-target"
put "$TMP/files/audio-path" "$ROOT/ui/AudioPath.qml" 644 || fail "Stage audio-path"
put "$TMP/files/audio-path-labels" "$ROOT/ui/AudioPathLabels.js" 644 || fail "Stage audio-path-labels"
put "$TMP/files/cassette" "/system/vendor/sony-cassette/Cassette.qml" 644 || fail "Stage cassette"
put "$TMP/files/preferences" "/system/vendor/sony-cassette/CassettePreferences.qml" 644 || fail "Stage preferences"
put "$TMP/files/tape" "/system/vendor/sony-cassette/assets/tape.png" 644 || fail "Stage tape"
put "$TMP/files/reels" "/system/vendor/sony-cassette/assets/reels.png" 644 || fail "Stage reels"
put "$TMP/files/player" "$BIN/HgrmMediaPlayerApp.album-test" 755 || fail "Stage player"
put "$TMP/files/launcher" "$BIN/sony-album-launch.sh" 755 || fail "Stage launcher"
put "$TMP/files/original-daemon" "$BIN/hagodaemon.peq-original" 755 0:2000 || fail "Audio recovery binary"
put "$TMP/files/original-boot" "$ROOT/backup/bootswitcher.sh" 755 || fail "Audio recovery boot script"
if [ ! -e '/contents/PEQ/Truthear Gate PEQ.txt' ]; then
    put "$TMP/files/gate" '/contents/PEQ/Truthear Gate PEQ.txt' 644 || fail "Example profile"
fi
if [ ! -e /contents/PEQ/active.txt ]; then
    echo off > /contents/PEQ/active.txt || fail "Default PEQ selection"
fi
if [ ! -e "$STATE/runtime/cassette-enabled.txt" ]; then
    echo off > "$STATE/runtime/cassette-enabled.txt" || fail "Default cassette selection"
fi
"$BB" chmod 666 "$STATE/runtime/cassette-enabled.txt" || fail "Cassette preference permissions"

if [ "$("$BB" cat "$STATE/confirmed" 2>/dev/null)" = "$BUILD_ID" ] && [ ! -f "$STATE/off" ]; then
    echo "Preserved verified PEQ backend state"
else
    "$BB" rm -f "$STATE/off" "$STATE/pending" "$STATE/confirmed" "$STATE/current-boot" "$STATE/state/mono_shim_boots" "$STATE/runtime/cinder_mono_shim" "$STATE/runtime/cinder_hpeq"
    echo "$BUILD_ID" > "$STATE/armed" || fail "Arm audio trial"
    echo "Patchman installed; first audio trial pending" > "$STATE/status" || fail "Audio status write"
fi
echo "$BUILD_ID" > "$STATE/armed" || fail "Record audio build"
put "$TMP/files/boot" "$BOOT" 755 || fail "Recovery hook activation"
put "$TMP/files/wrapper" "$BIN/hagodaemon" 755 0:2000 || fail "Audio dispatcher activation"
put "$TMP/config" "$CFG" 644 || fail "Player config activation"
"$BB" sha256sum "$CFG" | "$BB" cut -d' ' -f1 > "$PM/installed-config.sha256" || fail "Installed config receipt"
echo "Patchman v1.1" > "$PM/version.txt" || fail "Version receipt"
MUTATED=0
"$BB" rm -f /system/vendor/sony-peq/ui/QueueDiagnostic.qml /data/sony-peq/runtime/queue-diagnostic.json /data/sony-peq/runtime/queue-root.json /data/sony-peq/runtime/queue-component.json /contents/sony_queue_diagnostic.json /contents/sony_queue_root.json /contents/sony_queue_component.json /contents/sony_queue_launcher.txt || echo "WARN: diagnostic cleanup incomplete"
"$BB" rm -rf "$TMP" || echo "WARN: could not remove staging files"
"$BB" rm -rf "$ARCHIVE_STAGE" || echo "WARN: could not remove archive staging"
sync
echo "SUCCESS: Patchman v1.1 restored; existing profiles and preferences preserved"
echo "First cable-free start: play wired PCM/FLAC audio before restarting again; USB boots defer this check"
