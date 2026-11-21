#!/bin/sh
# Only the real player receives the preload, after launcher logging is complete.
export LD_PRELOAD="/system/vendor/patchman/libalbum_years.so${LD_PRELOAD:+:$LD_PRELOAD}"
exec "$@"
