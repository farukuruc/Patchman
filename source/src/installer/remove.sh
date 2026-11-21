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
  hash_is "$1" "5dac3d022189a3e940b0cc8fb7ecdb93baebf82c01dc35c86638a72c02397830" && return 0
  hash_is "$1" "9f4dc0e4b9d53c4847d63c2226bc72c30276c2373b6268424f83b0c1e5e5b6c9" && return 0
  hash_is "$1" "a3856572beeea8c39d29f0b0eebe3b1b040e645121ba728ff7a7eab11efc8b0e" && return 0
  hash_is "$1" "eb0ac7270fc7bca791288d632ccab35c75e61e0884a329a965845b709ba037da" && return 0
  hash_is "$1" "ff6b170cf5cce72fa90335a7e77ffe3d29c2282a89c2fd0a02c65fc1b1c47660" && return 0
  hash_is "$1" "5dac3d022189a3e940b0cc8fb7ecdb93baebf82c01dc35c86638a72c02397830" && return 0
  hash_is "$1" "8c61237d1193790029042aac947d21692eb19315220f9c52db86eaa89373f93a" && return 0
  hash_is "$1" "9f4dc0e4b9d53c4847d63c2226bc72c30276c2373b6268424f83b0c1e5e5b6c9" && return 0
  hash_is "$1" "a1bd12df6426dcb1cbb1bf19dd60a211828da19ddcd40cd34145a47d55e9a2f9" && return 0
  hash_is "$1" "23a5e1cd971b701dcf5d86e4fdbccfcd4573670d8ca3bdd4746bf9e4f425e056" && return 0
  hash_is "$1" "603c2a1c1a93a66132b85ee9b001232f5be967d7c0d5d5432f6c86a3d97f42a4" && return 0
  hash_is "$1" "5edc193715299e07238ea18f41bf778564df23f4b6788e98a2b9ba65ceb1330f" && return 0
  hash_is "$1" "981335589c7fdc5380764d51a8d3ea9f3a55789e1e66e5b4588a7536185a061d" && return 0
  hash_is "$1" "4019059b3bfc8e5296ccc18eeac5b1d9b57be1c4886717c9ae797a8b59e096a9" && return 0
  hash_is "$1" "63cec578f8eb75ac35ccaee2cead180ebe987cd1d3d6fbc04d02080bba3b9ecb" && return 0
  hash_is "$1" "04d9e3700173bbd92714318134dc955a1f8c949cf2613717d32d415da53ae7aa" || hash_is "$1" "0bacf756d34d7eae98ca2095ebb6be62150fc2747b6611c31a834478ae362967" || hash_is "$1" "171749afa0a1fba5252e15d308c47602110dfe19ccbc15d389204e215e27bdf9" || hash_is "$1" "18a0715d6f52c4b672679fe455fdfb2477891f9b474e04c955bca93d032153b1" || hash_is "$1" "27346894f118ff80aad15d154e6782862642a71856eea4d7989eb0bf6b00a9ce" || hash_is "$1" "2866d06db0208eafa78ee63bd0d057d1a1b7bb1e7f35a2615bc00124e4488328" || hash_is "$1" "3bfb9cd2e1c19d0cc6b9b4be3340b0f97408d80cafd3eaaa550a5f41f5c26920" || hash_is "$1" "3faa9c835e4d4a0ef5122863fa180b4f3e907b2e64f62ca1deb7b1080a0291a4" || hash_is "$1" "44d65f50b296d341bcb1f952aa5df5c5749c1ba2f32f3ea7b971252b1d3d5b25" || hash_is "$1" "46356ff807d28bce13f91b9d632d3dc36b0e968cd8a672f329e9741b2eaf29da" || hash_is "$1" "4e655e4dc5639dc1fcbad0e8f5162f4ea2b022105464c7a67ea05ceb9b275525" || hash_is "$1" "53efcd59b471600d11c9740c3b1cc851232e10cefa663cedb017438388bcbaed" || hash_is "$1" "5fcc8d9e0feffc47cf475ad9140eda7b3618f78a4adec45c91d13de453a13e78" || hash_is "$1" "66fa72c8462a3b811ff47aef07c35e04a9a03d890e0049406c62e33cb7ebfd5f" || hash_is "$1" "6cf14803937b0a6288edb5051206d0055b83d7edbc12a30e27437ea073f96aad" || hash_is "$1" "6d92e5ab8977baab9cc2c1e8662555b070fdf4a00e2895cd28bc72fc230823a0" || hash_is "$1" "7d869a20c43e39c838caf31b231081df26a6483e51e0c1cbb37c0862a7877b26" || hash_is "$1" "8b5ce95fca8800d4883b9d34b8deed75ad48496e41a4af9d9114a6f038c321e3" || hash_is "$1" "9435227e4f1d86c2e7a4f05c82743836e60be7da8031610b0a74f7e9b026e69d" || hash_is "$1" "9d5c669c6a252529cc1fc95033d55228668d2d8b7269e803e8f3aebb885f1a6a" || hash_is "$1" "af584f917ac0c8b8846a42bfda4fb9735b46fb2e88051ae5da2cfaa21a851eb0" || hash_is "$1" "b6749522f599dc6d618a2af38aba5899dccb11eda1a6cbb19d5759c6194364e6" || hash_is "$1" "c1af5405f827f20c63f52673edf89f435f9d3b51d26df56e29d910ce2a6677b7" || hash_is "$1" "c866867bb5cc7108507f74b982320842f5f8d0264ba4c506d30de18b1363360f" || hash_is "$1" "ca619c7c2bdcf04ee767b9854be641d999699e3eaac9155509eef8c848a8b867" || hash_is "$1" "d3d35c411c3e461c2844e9d1f0308fcc34584faa8cf8753bef7ff24ca8e58f85" || hash_is "$1" "d44c39f1667673547b01c9d3f96943e7602c8abaee2acffae28d4452a2a29b04" || hash_is "$1" "e2290c55ed4d1bb844ff40353fda7b1d87b3b1678a9585beba2796ce4660f70a" || hash_is "$1" "e23f768be43f4bb2e8a164184198904bf5cc81d0a7fc05647e4fb116c7abd92a" || hash_is "$1" "ed2dcbb244c44e651f454dded96a62c6cf5f436f7205fa203eea42c2a7a30a31"
}
known_launcher() {
  hash_is "$1" "1d61751a34427fdb6ad6e362be67aed8cf62c0b945645496aa18729ed849ecc1" && return 0
  hash_is "$1" "1d61751a34427fdb6ad6e362be67aed8cf62c0b945645496aa18729ed849ecc1" && return 0
  hash_is "$1" "1d61751a34427fdb6ad6e362be67aed8cf62c0b945645496aa18729ed849ecc1" && return 0
  hash_is "$1" "1d61751a34427fdb6ad6e362be67aed8cf62c0b945645496aa18729ed849ecc1" && return 0
  hash_is "$1" "1d61751a34427fdb6ad6e362be67aed8cf62c0b945645496aa18729ed849ecc1" && return 0
  hash_is "$1" "a370f558d9ae32c73bf00f98a9bb1f6936c19d593bb988f3f9573abcf09f51eb" && return 0
  hash_is "$1" "16776766acad8995b37f73327543ec9c0d8d9b6ec35742a4e16ee096f0a86659" || hash_is "$1" "2d308c288843ae786a3a245bdcd8a0b7907397b68447ee8be8ea1fe4116590a0" || hash_is "$1" "2f19442a4ab9558ca82c7169f0b44ef538fc432b74f470b04c94fd22513e1b14" || hash_is "$1" "4d5d9965367b417cbbd8cd3c2a620b06e7b3d614a5b6295155a9450f7ac339a6" || hash_is "$1" "5a0206611fae40bda481dacd0db0f32e8a5102ef291547987444292e00b3f951" || hash_is "$1" "63f63ea97b314c0c069fc778c13d2638c6ebae290590ee93091e6e2355c03c42" || hash_is "$1" "65fa43be9aa54fe467ea00be3c988999f3325f32b9b8b93ce98eb8f7a8fc09be" || hash_is "$1" "6ca0bfc02828b9b334637fc1b5d11c8d0b74bd144cd5fd71b671e655a3aa5342" || hash_is "$1" "718403b146ecd5295d1a642a74d763a2a9f66b6336980b3bd27fb89036fd58dc" || hash_is "$1" "73cf038b29b145a91e331ec1e8acdf6a332e0a889ccb96ca617dc1c2b22044e8" || hash_is "$1" "780dd41be79ef581a21d289e19e1778c4ffe592d70fce5e3acd3af03f4a41d02" || hash_is "$1" "7c5b47b678112e6030a50414e58dc774a505bf6d99983c38bbc3ca7db0e0e635" || hash_is "$1" "7e9e4d9ac22a0998e40e7443acb443444e940efb5ea7499dd68e27c17769daac" || hash_is "$1" "abcddb42a6b20ea5e3734b4c8a84834e2b34c5edc875e56f7c38a54ab0157a62" || hash_is "$1" "ad6f7f2af975da1d5b723bffdd2f42ef94053550176cbeeea41b98c8f1dceb87" || hash_is "$1" "b56b7f7a4d8ba8b450711f8b71fdc19890af2e7fafea467364c3c713def41928" || hash_is "$1" "bd1545aeae789141afa18772557a59c6caf0db41d33e411104f78e6c6bbaf8e6" || hash_is "$1" "c06a997ce0d400732152fe79eaad8bc9b7a366a98bb5d7bc53c668c56fc97720" || hash_is "$1" "c53c173613790e602fe8f4bba0f62378726dd12806de4ab7b0edd368a3cffa76" || hash_is "$1" "d746ebe52fd334b3399a9a41451e8c54ae7632295dac40f802a5a69345911490" || hash_is "$1" "e7659aa310adef4fc0485a2bd0b4f40aa31417b9f0ed00bdd94f1b363a6ad3af"
}
exec >>/contents/Patchman-remove.log 2>&1
echo "Patchman remover - restore Walkman One"
PM=/system/vendor/patchman
CFG=$BIN/HgrmMediaPlayerApp.appcfg
mount -t ext4 -o rw /emmc@android /system 2>/dev/null || :
mount -o remount,rw /emmc@android /system 2>/dev/null || :
album_mount_data || fail "Data partition unavailable"
hash_is "$BIN/HgrmMediaPlayerApp" 'f515f75e48e84460c18707e5408c6c09c26a77a13deccdee23e220dc81f49124' || fail "Original player unavailable"
hash_is "$PM/backup/hagodaemon" "$ORIGINAL_HAGO" || fail "Native daemon backup mismatch"
hash_is "$PM/backup/bootswitcher.sh" "$ORIGINAL_BOOT" || fail "Native boot backup mismatch"
CFG_HASH="$("$BB" cat "$PM/backup/appcfg.sha256" 2>/dev/null)"
hash_is "$PM/backup/appcfg" "$CFG_HASH" || fail "Native config backup mismatch"
"$BB" grep -Eq '^command: (HgrmMediaPlayerApp|/system/vendor/sony/bin/HgrmMediaPlayerApp)$' "$PM/backup/appcfg" || fail "Invalid native config"
INSTALLED_HASH="$("$BB" cat "$PM/installed-config.sha256" 2>/dev/null)"
{ hash_is "$CFG" "$INSTALLED_HASH" || hash_is "$CFG" "$CFG_HASH"; } || fail "Player config changed externally"
{ hash_is "$BIN/hagodaemon" "$WRAPPER_SHA" || hash_is "$BIN/hagodaemon" "$ORIGINAL_HAGO"; } || fail "Audio dispatcher changed externally"
{ hash_is "$BOOT" "$BOOT_SHA" || hash_is "$BOOT" "$ORIGINAL_BOOT"; } || fail "Boot script changed externally"
require_space /system 1024
require_space /data 64
put "$PM/backup/appcfg" "$CFG" 644 || fail "Restore native config"
put "$PM/backup/hagodaemon" "$BIN/hagodaemon" 755 0:2000 || fail "Restore native daemon"
put "$PM/backup/bootswitcher.sh" "$BOOT" 755 || fail "Restore native boot"
"$BB" rm -f "$STATE/runtime/cinder_hpeq" "$STATE/armed" "$STATE/pending" "$STATE/confirmed"
: > "$STATE/off"
echo "Patchman removed; native Walkman One active" > "$STATE/status"
"$BB" rm -f "$PM/version.txt"
sync
echo "SUCCESS: Patchman removed; Walkman One, music, profiles and cassette preference preserved"
