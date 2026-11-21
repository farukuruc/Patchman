.pragma library
    function step(screen, rows) {
        try {
            var count = rows.count
            if (count <= 0) return
            var end = Math.min(count, screen.modCursor + 8)
            var missing = 0
            for (var i = screen.modCursor; i < end; i++) {
                if (screen.modDurations[i] >= 0) continue
                var row = rows.items.get(i).model
                var seconds = screen.modParseTime(row.TrackDurationUint32Role)
                screen.modDurations[i] = seconds
                if (seconds < 0) missing++
            }
            screen.modMissing = missing
            if (missing) {
                if (++screen.modPass >= 20 * Math.max(1, Math.ceil(count / 8))) screen.modStopped = true
                return
            }
            screen.modPass = 0
            screen.modCursor = end
            if (screen.modCursor < count) return
            var suffix = []
            suffix[count] = 0
            for (var j = count - 1; j >= 0; j--) suffix[j] = screen.modDurations[j] + suffix[j + 1]
            screen.modSuffix = suffix
            screen.modReady = true
            screen.modUpdateRemaining()
        } catch (error) {
            screen.modStopped = true
            console.log("QR model", error)
        }
    }
