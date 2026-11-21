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

# Runs before Sony starts the service class; never restarts a live audio service.
rollback() {
    echo "PEQ disabled: $*" > "$STATE/status" 2>/dev/null
    : > "$STATE/off" 2>/dev/null
    "$BB" rm -f "$STATE/runtime/cinder_hpeq"
    if restore_daemon recovery; then
        echo "Original Sony daemon restored" >> "$STATE/status" 2>/dev/null
        mount -o remount,ro /system 2>/dev/null || :
    fi
    sync
    exit 0
}
album_mount_data >/dev/null 2>&1 || { restore_daemon recovery; mount -o remount,ro /system 2>/dev/null; exit 0; }
[ -d "$STATE/runtime" ] && [ -d "$STATE/state" ] || rollback missing-state
[ -f "$STATE/off" ] && rollback disabled
[ -f /contents/peq_off ] && rollback manual-off
hash_is "$BIN/hagodaemon" "$WRAPPER_SHA" || rollback wrapper-unavailable
hash_is "$ROOT/libsony_peq.so" '38d0fadda997b6b94c8785083436218d722dd1c4831d9c3ed8c20f04bedcdb5d' || rollback shim-checksum
hash_is "$ROOT/sony-peq-profile" '590d77e4aa4ba1ce750a307283d31d3b41a6dbb8c79b3e711543393009b4ae5a' || rollback reader-checksum
[ "$("$BB" cat "$STATE/armed" 2>/dev/null)" = "$BUILD_ID" ] || rollback not-armed
BOOT_ID="$("$BB" cat /proc/sys/kernel/random/boot_id 2>/dev/null)"
[ -n "$BOOT_ID" ] || rollback no-boot-id
[ "$("$BB" cat "$STATE/current-boot" 2>/dev/null)" = "$BOOT_ID" ] && exit 0

# The first trial must reach a successful PCM write before a later boot accepts it.
if [ -f "$STATE/pending" ] && [ "$("$BB" cat "$STATE/confirmed" 2>/dev/null)" != "$BUILD_ID" ]; then
    [ -s "$STATE/runtime/cinder_mono_shim" ] && [ ! -f "$STATE/state/mono_shim_boots" ] || rollback trial-did-not-reach-audio
    echo "$BUILD_ID" > "$STATE/confirmed" || rollback cannot-confirm
fi
COUNT="$("$BB" cat "$STATE/state/mono_shim_boots" 2>/dev/null)"
case "$COUNT" in ''|0|1) ;; *) rollback repeated-audio-load-failure ;; esac
"$BB" chmod 777 "$STATE/runtime" "$STATE/state" || rollback runtime-permissions
"$BB" rm -f "$STATE/runtime/cinder_mono_shim" "$STATE/runtime/cinder_hpeq" "$STATE/state/mono_shim_boots"
echo "$BOOT_ID" > "$STATE/current-boot" || rollback cannot-record-boot
# USB-connected updater boots must not consume the first cable-free playback trial.
# Retain the existing validation above: an earlier failed cable-free trial still
# rolls back. No successful-audio marker or confirmation is fabricated here.
USB_BOOT=0
for node in /sys/class/android_usb/android0/state /sys/class/power_supply/usb/online /sys/class/power_supply/usb/present; do
    [ -r "$node" ] || continue
    case "$(cat "$node" 2>/dev/null)" in
        CONFIGURED|CONNECTED|1) USB_BOOT=1; break ;;
    esac
done
if [ "$USB_BOOT" = 1 ]; then
    "$BB" rm -f "$STATE/pending" || rollback cannot-defer-trial
    echo "PEQ backend armed; USB boot: playback verification deferred" > "$STATE/status"
else
    echo "$BUILD_ID" > "$STATE/pending" || rollback cannot-record-trial
    echo "PEQ backend armed; playback verification pending" > "$STATE/status"
fi
"$ROOT/sony-peq-profile" select /contents/PEQ "$STATE/runtime/cinder_hpeq" >> "$STATE/status" 2>&1 || "$BB" rm -f "$STATE/runtime/cinder_hpeq"
sync
exit 0
