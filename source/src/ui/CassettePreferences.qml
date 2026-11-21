import QtQuick 2.3

Item {
    id: preferences
    property string preferenceUrl: "file:///data/sony-peq/runtime/cassette-enabled.txt"
    property bool ready: false
    property bool saving: false
    property bool cassetteEnabled: false
    property string error: ""
    property int generation: 0
    property var request: null

    function read(done) {
        var xhr = new XMLHttpRequest()
        request = xhr
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE)
                done(xhr.responseText.replace(/^\s+|\s+$/g, ""))
        }
        xhr.open("GET", preferenceUrl + "?r=" + Date.now())
        xhr.send()
    }
    function load() {
        var serial = ++generation
        timeout.start()
        read(function(value) {
            if (preferences.generation !== serial) return
            timeout.stop()
            preferences.cassetteEnabled = value === "on"
            preferences.error = value === "on" || value === "off" ? "" : "Cannot read cassette setting. Choose On or Off to save it."
            preferences.ready = true
        })
    }
    function saveCassetteEnabled(value) {
        if (!ready || saving) return
        saving = true
        error = ""
        var serial = ++generation
        var body = value ? "on" : "off"
        var xhr = new XMLHttpRequest()
        request = xhr
        timeout.start()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || !preferences.saving || preferences.generation !== serial) return
            preferences.read(function(actual) {
                if (!preferences.saving || preferences.generation !== serial) return
                timeout.stop()
                preferences.saving = false
                if (actual === body) preferences.cassetteEnabled = value
                else preferences.error = "Could not save cassette setting. Try again."
            })
        }
        xhr.open("PUT", preferenceUrl)
        xhr.send(body + "\n")
    }
    Timer {
        id: timeout
        interval: 3000
        onTriggered: {
            preferences.saving = false
            preferences.ready = true
            preferences.generation++
            if (preferences.request) preferences.request.abort()
            preferences.error = "Cassette setting timed out. Choose On or Off to retry."
        }
    }
    Component.onCompleted: load()
}
