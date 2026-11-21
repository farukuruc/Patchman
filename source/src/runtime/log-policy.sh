# Sourced by the existing Sony launcher; no audio controls are read or changed.
PATCHMAN_BB=/xbin/busybox
[ -x "$PATCHMAN_BB" ] || PATCHMAN_BB=/system/xbin/busybox
PATCHMAN_RUN=/data/sony-album-test/run
PATCHMAN_RUNTIME=/data/sony-peq/runtime
PATCHMAN_DEBUG=1
# HeaderProbe1: use the existing capped stderr logger for this temporary test.
[ ! -f /contents/Patchman-debug ] || PATCHMAN_DEBUG=1

pm_cap_log() {
    [ -f "$1" ] && [ ! -L "$1" ] || return 0
    pm_bytes="$("$PATCHMAN_BB" wc -c < "$1" 2>/dev/null | "$PATCHMAN_BB" awk '{print $1}')"
    case "$pm_bytes" in ''|*[!0-9]*) return 0 ;; esac
    [ "$pm_bytes" -gt "$2" ] || return 0
    pm_tail=/contents/.patchman-log-tail-$$
    if "$PATCHMAN_BB" tail -c "$2" "$1" > "$pm_tail" 2>/dev/null; then
        "$PATCHMAN_BB" cat "$pm_tail" > "$1" 2>/dev/null || :
    else
        # These are exclusively generated logs. A full music partition must
        # not prevent freeing an oversized diagnostic file on /data.
        : > "$1" 2>/dev/null || :
    fi
    "$PATCHMAN_BB" rm -f "$pm_tail"
}
pm_boot_caps() {
    pm_cap_log "$PATCHMAN_RUNTIME/cinder_mono.log" 65536
    pm_cap_log "$PATCHMAN_RUNTIME/ui-server.log" 65536
}
pm_export_player() {
    [ -s "$PATCHMAN_RUN/player.log" ] || [ -s "$PATCHMAN_RUN/player.log.part" ] || return 0
    pm_output=/contents/sony_album_player.log.patchman-new
    if (
        if [ -f "$PATCHMAN_RUN/player.log" ] && [ ! -L "$PATCHMAN_RUN/player.log" ]; then "$PATCHMAN_BB" tail -c 131072 "$PATCHMAN_RUN/player.log" || exit 1; fi
        if [ -f "$PATCHMAN_RUN/player.log.part" ] && [ ! -L "$PATCHMAN_RUN/player.log.part" ]; then "$PATCHMAN_BB" tail -c 131072 "$PATCHMAN_RUN/player.log.part" || exit 1; fi
    ) > "$pm_output" 2>/dev/null; then
        "$PATCHMAN_BB" mv -f "$pm_output" /contents/sony_album_player.log || :
    fi
    "$PATCHMAN_BB" rm -f "$pm_output"
}
pm_prepare_player_log() {
    pm_export_player
    if [ -f "$PATCHMAN_RUN/player.log" ] && [ ! -L "$PATCHMAN_RUN/player.log" ]; then : > "$PATCHMAN_RUN/player.log" 2>/dev/null || :; fi
    "$PATCHMAN_BB" rm -f "$PATCHMAN_RUN/player.log.part" "$PATCHMAN_RUN/debug-stderr.fifo" 2>/dev/null || :
}
pm_exec_player() {
    pm_prepare_player_log
    if [ "$PATCHMAN_DEBUG" = 1 ] && "$PATCHMAN_BB" mkfifo "$PATCHMAN_RUN/debug-stderr.fifo" 2>/dev/null; then
        # At most one complete 128-KiB chunk plus one current chunk. Keep the
        # FIFO open and drain it even if logging fails, so stderr cannot SIGPIPE.
        (
            while :; do
                if ! "$PATCHMAN_BB" head -c 131072 > "$PATCHMAN_RUN/player.log.part"; then
                    "$PATCHMAN_BB" rm -f "$PATCHMAN_RUN/player.log.part"
                    "$PATCHMAN_BB" cat > /dev/null
                    break
                fi
                if [ ! -s "$PATCHMAN_RUN/player.log.part" ]; then "$PATCHMAN_BB" rm -f "$PATCHMAN_RUN/player.log.part"; break; fi
                pm_chunk="$("$PATCHMAN_BB" wc -c < "$PATCHMAN_RUN/player.log.part" | "$PATCHMAN_BB" awk '{print $1}')"
                case "$pm_chunk" in ''|*[!0-9]*) "$PATCHMAN_BB" cat > /dev/null; break ;; esac
                if [ "$pm_chunk" -lt 131072 ]; then break; fi
                if ! "$PATCHMAN_BB" mv -f "$PATCHMAN_RUN/player.log.part" "$PATCHMAN_RUN/player.log"; then
                    "$PATCHMAN_BB" cat > /dev/null
                    break
                fi
            done
        ) < "$PATCHMAN_RUN/debug-stderr.fifo" &
        exec "$@" 2> "$PATCHMAN_RUN/debug-stderr.fifo"
    fi
    exec "$@" 2>/dev/null
}
