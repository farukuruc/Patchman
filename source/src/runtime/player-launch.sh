#!/bin/sh
# BEGIN PATCHMAN LOG POLICY
if [ -r /system/vendor/patchman/log-policy.sh ]; then
    . /system/vendor/patchman/log-policy.sh
    pm_boot_caps
fi
# END PATCHMAN LOG POLICY
# BEGIN SONY PEQ PROFILE LOADER
if [ -x /system/vendor/sony-peq/sony-peq-profile ] && [ -d /data/sony-peq/runtime ]; then
    (
        cat /data/sony-peq/status 2>/dev/null
        if [ -f /data/sony-peq/off ]; then
            echo "PEQ backend disabled; reinstall after reviewing the log"
        else
            /system/vendor/sony-peq/sony-peq-profile select /contents/PEQ /data/sony-peq/runtime/cinder_hpeq || /system/vendor/sony-peq/sony-peq-profile off /data/sony-peq/runtime/cinder_hpeq
        fi
        [ ! -r /data/sony-peq/runtime/cinder_mono.log ] || cat /data/sony-peq/runtime/cinder_mono.log
        [ ! -r /data/sony-peq/runtime/ui-server.log ] || cat /data/sony-peq/runtime/ui-server.log
    ) > /contents/sony_peq_status.log 2>&1
fi
# END SONY PEQ PROFILE LOADER
REAL=/system/vendor/sony/bin/HgrmMediaPlayerApp
MOD=/system/vendor/sony/bin/HgrmMediaPlayerApp.album-test
STATE=/data/sony-album-test/run

# Export the preceding cable-free run before considering the USB fallback.
for file in album-native-years.log album-year-cache.log goto-navigation-b6.json goto-target.json cassette-root.json cassette-component.json cassette-launch.txt; do
    if [ -r "/data/sony-peq/runtime/$file" ]; then
        (cp "/data/sony-peq/runtime/$file" "/contents/sony_$file") 2>/dev/null
    fi
done

original() {
    REASON=$1
    shift
    (echo "sony-album: $REASON -> original" >> /contents/sony_album_launch.log) 2>/dev/null
    if [ -r "$STATE/player.log" ]; then
        if command -v pm_prepare_player_log >/dev/null 2>&1; then pm_prepare_player_log; fi
    fi
    exec "$REAL" "$@"
}
for node in /sys/class/android_usb/android0/state /sys/class/power_supply/usb/online /sys/class/power_supply/usb/present; do
    [ -r "$node" ] || continue
    case "$(cat "$node" 2>/dev/null)" in
        CONFIGURED|CONNECTED|1) original usb "$@" ;;
    esac
done
[ -f /contents/sony_album_test_off ] && original disabled "$@"
[ -x "$MOD" ] || original missing-player "$@"
mkdir -p "$STATE" 2>/dev/null || original state-unavailable "$@"

# Permit the modified player on each boot. A crash restart in the same boot
# falls back to Sony, while a later normal boot tries the modified player again.
BOOT="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)"
[ -n "$BOOT" ] || original no-boot-id "$@"
CLAIM="$STATE/boot-$BOOT"
if ! mkdir "$CLAIM" 2>/dev/null; then
    [ -d "$CLAIM" ] && original process-restarted "$@"
    original state-claim-failed "$@"
fi
# Atomic directory creation claims this boot without depending on Sony's mv.
# Keep only the current boot's empty directory.
for previous in "$STATE"/boot-*; do
    [ "$previous" = "$CLAIM" ] && continue
    rmdir "$previous" 2>/dev/null || :
done
sync
# BEGIN PEQ UI HELPER
export QML_XHR_ALLOW_FILE_READ=1
export QML_XHR_ALLOW_FILE_WRITE=1
if [ -x /system/vendor/sony-peq/sony-peq-ui ]; then
    /system/vendor/sony-peq/sony-peq-ui serve /contents/PEQ /data/sony-peq/runtime > /data/sony-peq/runtime/ui-server.log 2>&1 < /dev/null &
fi
# END PEQ UI HELPER
# GoTo metadata probe: read-only SQLite; blocks on inotify between requests.
if [ -x /system/vendor/patchman/goto-target ]; then
    /system/vendor/patchman/goto-target serve /db/MTPDB.dat /data/sony-peq/runtime </dev/null >/dev/null 2>&1 &
fi
# Native years are prepared once before the player creates any album model.
YEAR_READY=0
printf 'native-years-1 boot
' > /data/sony-peq/runtime/album-native-years.log
chmod 666 /data/sony-peq/runtime/album-native-years.log 2>/dev/null || :
if printf '.pragma library
function year(artist,album){return ""}
' > /data/sony-peq/runtime/AlbumYearCache.js && [ -x /system/vendor/patchman/album-year-cache ]; then
    if /system/vendor/patchman/album-year-cache once /db/MTPDB.dat /data/sony-peq/runtime > /data/sony-peq/runtime/album-year-cache.log 2>&1; then
        YEAR_READY=1
    fi
fi
# Fresh evidence for the actual modified-player attempt in this boot.
(rm -f /data/sony-peq/runtime/cassette-root.json /data/sony-peq/runtime/cassette-component.json) 2>/dev/null
(echo "cassette diagnostics v9: modified player launch attempted"; cat /proc/sys/kernel/random/boot_id) > /data/sony-peq/runtime/cassette-launch.txt 2>/dev/null
export LD_LIBRARY_PATH="/system/vendor/sony/lib:/system/lib:/usr/lib:/lib:$LD_LIBRARY_PATH"
if [ "$YEAR_READY" = 1 ]; then
    if command -v pm_exec_player >/dev/null 2>&1; then pm_exec_player /system/vendor/patchman/exec-native-years "$MOD" "$@"; fi
    exec /system/vendor/patchman/exec-native-years "$MOD" "$@" 2>/dev/null
fi
if command -v pm_exec_player >/dev/null 2>&1; then pm_exec_player "$MOD" "$@"; fi
exec "$MOD" "$@" 2>/dev/null
