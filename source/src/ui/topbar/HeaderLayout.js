.pragma library

function wireless(name) {
    return name === "stat_sys_bluetooth.png" || name === "stat_sys_nfc.png"
}
function batteryIcon(type, name) {
    return Number(type) === 1 && /^stat_sys_battery_[a-z0-9_]+\.png$/.test(String(name))
}
function moved(type, name) {
    return Number(type) === 1 && (wireless(String(name)) || batteryIcon(type, name))
}

var playbackIcons = {"stat_notify_audio_track_rewind.png":{"width":36,"height":28,"ink":[6,9,24,11]},"stat_notify_audio_track_just_rewind.png":{"width":36,"height":28,"ink":[5,8,24,12]},"stat_notify_audio_track_fast_forward.png":{"width":36,"height":28,"ink":[6,9,24,11]},"stat_notify_audio_track_just_fast_forward.png":{"width":36,"height":28,"ink":[6,8,24,12]},"stat_notify_audio_track_play.png":{"width":36,"height":28,"ink":[9,6,20,17]},"stat_notify_audio_track_next.png":{"width":36,"height":28,"ink":[6,8,24,13]},"stat_notify_audio_track_previous.png":{"width":36,"height":28,"ink":[6,8,24,13]},"stat_notify_audio_track_pause.png":{"width":36,"height":28,"ink":[9,5,18,18]}}

function playback(name) {
    return Object.prototype.hasOwnProperty.call(playbackIcons, String(name))
}
function playbackMetrics(name) {
    return playbackIcons[String(name)] || {width:36,height:28,ink:[0,0,1,1]}
}
