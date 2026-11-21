import QtQuick 2.3

Rectangle {
    id: panel
    color: "black"
    property var playerWindow: null
    property alias scrollArea: pathRows
    property string fontFamily: typeof viewstyle !== "undefined" ? viewstyle.font_family : ""
    property string runtimeUrl: "file:///data/sony-peq/runtime/"
    property string profilesUrl: "file:///contents/PEQ/"
    property string selectedProfile: "Unknown"
    property string preamp: "Unknown"
    property string peqState: "Unknown"
    property bool reading: false
    property int generation: 0
    property var pendingReads: []
    property var header: playerWindow && playerWindow.headerArea ? playerWindow.headerArea : ({})
    property string liveTitle: playerWindow && playerWindow.basicPlayerControls && playerWindow.basicPlayerControls.playTitle ? String(playerWindow.basicPlayerControls.playTitle) : ""
    // Only use the native window header. A cached music screen can belong to
    // another track with the same title, so title matching is not a safe ID.
    property string sourceFormat: header.soundQualityText ? String(header.soundQualityText) : "Unknown"
    property string trackTitle: liveTitle || "No track information"
    property string directSource: {
        var p = playerWindow && playerWindow.sourceDirectOrClearAudio ? playerWindow.sourceDirectOrClearAudio : null
        return p && typeof p.is_source_direct === "boolean" ? (p.is_source_direct ? "ON" : "OFF") : "Unknown"
    }
    property string outputDevice: {
        var kind = header.outputType
        if (kind === "HeadPhone") return "Wired headphones"
        if (kind === "Bluetooth") return "Bluetooth"
        if (kind === "USB Audio") return "USB audio"
        if (kind === "LineOut") return "Line out"
        return "Unknown"
    }
    function validName(s) {
        return s.length > 0 && s.length <= 255 && !/[\/\\\r\n\x00]/.test(s) && /\.txt$/i.test(s) && s.toLowerCase() !== "active.txt"
    }
    function read(url, epoch, done) {
        var xhr = new XMLHttpRequest()
        pendingReads.push(xhr)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            var at = pendingReads.indexOf(xhr)
            if (at >= 0) pendingReads.splice(at, 1)
            if (epoch === generation && panel.visible) done(xhr.responseText || "")
        }
        xhr.open("GET", url + "?r=" + Date.now())
        xhr.send()
    }
    function cancelReads() {
        generation++
        reading = false
        var current = pendingReads
        pendingReads = []
        for (var i=0;i<current.length;i++) {
            current[i].onreadystatechange = null
            if (current[i].readyState !== XMLHttpRequest.DONE) current[i].abort()
        }
    }
    function refresh() {
        if (!visible || reading) return
        reading = true
        var epoch = ++generation
        read(profilesUrl + "active.txt", epoch, function(text) {
            var name = text.replace(/^\uFEFF/, "").trim()
            var nextProfile = validName(name) ? name : name.toLowerCase() === "off" ? "None (PEQ off)" : "Unknown"
            var nextPreamp = "Unknown"
            var nextState = name.toLowerCase() === "off" ? "OFF" : "Unknown"
            function finish() {
                panel.selectedProfile = nextProfile
                panel.preamp = nextPreamp
                panel.peqState = nextState
                panel.reading = false
            }
            read(runtimeUrl + "cinder_hpeq", epoch, function(control) {
                if (validName(name) && control.length) nextState = "ON (configured)"
                if (!validName(name)) { finish(); return }
                read(profilesUrl + encodeURIComponent(name), epoch, function(profile) {
                    if (!profile.length) nextState = "Unknown"
                    if (profile.length <= 65536) {
                        var match = profile.match(/^\s*Preamp\s*:\s*([+-]?(?:\d+(?:\.\d*)?|\.\d+))\s*dB\s*(?:#.*)?$/im)
                        if (match && isFinite(Number(match[1]))) nextPreamp = Number(match[1]) + " dB (profile)"
                        else if (profile.trim().length && !/^\s*Preamp\s*:/im.test(profile)) nextPreamp = "Not specified (profile)"
                    }
                    finish()
                })
            })
        })
    }
    onVisibleChanged: {
        cancelReads()
        if (visible) refresh()
    }
    Component.onCompleted: refresh()
    Component.onDestruction: cancelReads()
    // Configuration is read on entry/return. Native playback fields are live
    // bindings; no periodic file polling is needed on this read-only page.
    Text {
        id: heading
        x: 20; y: 8; width: parent.width - 40; height: 50
        text: "Audio Path"; color: "white"; font.family: panel.fontFamily; font.pixelSize: 28; font.weight: Font.Light
        verticalAlignment: Text.AlignVCenter
    }
    Rectangle { x: 20; y: heading.y + heading.height; width: parent.width - 40; height: 1; color: "#777777" }
    Flickable {
        id: pathRows
        anchors { top: heading.bottom; topMargin: 12; left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 12 }
        contentWidth: width; contentHeight: rows.height; clip: true; boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        Column {
            id: rows
            x: 20; width: parent.width - 40; spacing: 14
            Repeater {
                model: [
                    {label: "SONY FORMAT INFO", value: panel.sourceFormat},
                    {label: "DIRECT SOURCE", value: panel.directSource},
                    {label: "PARAMETRIC EQ", value: panel.peqState},
                    {label: "SELECTED PROFILE", value: panel.selectedProfile},
                    {label: "PROFILE PREAMP", value: panel.preamp},
                    {label: "OUTPUT CONNECTION", value: panel.outputDevice}
                ]
                delegate: Item {
                    width: rows.width; height: 62
                    Text { y: 0; width: parent.width; height: 23; text: modelData.label; textFormat: Text.PlainText; color: "#aaaaaa"; font.family: panel.fontFamily; font.pixelSize: 16 }
                    Text { y: 24; width: parent.width; height: 34; text: modelData.value; textFormat: Text.PlainText; color: "white"; font.family: panel.fontFamily; font.pixelSize: 24; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
                }
            }
            Text { width: parent.width; text: panel.trackTitle; textFormat: Text.PlainText; color: "#aaaaaa"; font.family: panel.fontFamily; font.pixelSize: 19; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
            Text {
                width: parent.width
                text: "Format text is reported by Sony. Output stream format is not verified. PEQ status shows configuration, not proof of live processing."
                color: "#aaaaaa"; font.family: panel.fontFamily; font.pixelSize: 16; wrapMode: Text.WordWrap
            }
        }
    }
}
