import QtQuick 2.3

Rectangle {
    id: panel
    color: "#080808"
    signal closed()
    property string preferenceUrl: "file:///data/sony-peq/runtime/album-sort.txt"
    property string selected: "newest"
    property bool ready: false
    property bool saving: false
    property string message: ""
    property int generation: 0
    property var request: null
    property string fontFamily: typeof viewstyle !== "undefined" ? viewstyle.font_family : ""
    readonly property var choices: ["newest", "oldest", "az", "za"]
    readonly property var labels: ["Newest first", "Oldest first", "A–Z", "Z–A"]

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
            if (generation !== serial) return
            timeout.stop()
            selected = choices.indexOf(value) >= 0 ? value : "newest"
            ready = true
        })
    }
    function select(value) {
        if (!ready || saving || choices.indexOf(value) < 0) return
        saving = true
        message = ""
        var serial = ++generation
        var xhr = new XMLHttpRequest()
        request = xhr
        timeout.start()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || generation !== serial) return
            read(function(actual) {
                if (generation !== serial) return
                timeout.stop()
                saving = false
                if (actual === value) {
                    selected = value
                    message = "Saved. Open an artist to use this order."
                } else message = "Could not save. Please try again."
            })
        }
        xhr.open("PUT", preferenceUrl)
        xhr.send(value + "\n")
    }
    Component.onCompleted: load()
    Component.onDestruction: {
        generation++
        timeout.stop()
        if (request) request.abort()
    }
    Timer {
        id: timeout
        interval: 3000
        onTriggered: {
            generation++
            if (request) request.abort()
            saving = false
            ready = true
            message = "Setting timed out. Please try again."
        }
    }
    // Consume taps over the settings page underneath this panel.
    MouseArea { anchors.fill: parent }
    Text {
        x: 24; y: 26; width: parent.width - 48
        text: "Sorting Options"
        color: "white"; font.family: panel.fontFamily; font.pixelSize: 28
    }
    Text {
        x: 24; y: 80; width: parent.width - 48
        text: "Albums inside an artist"
        color: "#cccccc"; font.family: panel.fontFamily; font.pixelSize: 21
    }
    Column {
        x: 16; y: 130; width: parent.width - 32
        Repeater {
            model: panel.labels
            delegate: Rectangle {
                objectName: "sortChoice" + index
                width: 448; height: 82
                color: panel.selected === panel.choices[index] ? "#252525" : "#080808"
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#444444" }
                Text {
                    x: 16; anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    color: "white"; font.family: panel.fontFamily; font.pixelSize: 25
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.selected === panel.choices[index] ? "●" : "○"
                    color: "white"; font.pixelSize: 25
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: panel.ready && !panel.saving
                    onClicked: panel.select(panel.choices[index])
                }
            }
        }
    }
    Text {
        x: 24; y: 484; width: parent.width - 48
        text: panel.message.length ? panel.message : "Albums without a year stay at the end of year order."
        wrapMode: Text.WordWrap
        color: "#cccccc"; font.family: panel.fontFamily; font.pixelSize: 20
    }
    Rectangle {
        x: 24; anchors.bottom: parent.bottom; anchors.bottomMargin: 20
        width: parent.width - 48; height: 56
        color: "#181818"; border.color: "#cccccc"
        Text { anchors.centerIn: parent; text: "Back"; color: "white"; font.family: panel.fontFamily; font.pixelSize: 24 }
        MouseArea { anchors.fill: parent; enabled: !panel.saving; onClicked: panel.closed() }
    }
}
