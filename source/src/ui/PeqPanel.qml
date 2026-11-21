import QtQuick 2.3

Rectangle {
    id: panel
    color: "#080808"
    signal closed()
    property string runtimeUrl: "file:///data/sony-peq/runtime/"
    property bool busy: false
    property bool eqEnabled: false
    property bool backendReady: false
    property string selected: ""
    property string message: ""
    property string pendingId: ""
    property int serial: 0
    property int attempts: 0
    property bool reading: false
    property var profiles: []
    property var requestObject: null
    property string fontFamily: typeof viewstyle !== "undefined" ? viewstyle.font_family : ""

    function finishError(text) {
        poll.stop()
        busy = false
        message = text
    }
    function readFile(name, done) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && panel.busy) done(xhr.responseText)
        }
        xhr.open("GET", runtimeUrl + name + "?r=" + Date.now())
        xhr.send()
    }
    function request(command, name) {
        if (busy) return
        pendingId = "p" + Date.now() + "-" + (++serial)
        var body = pendingId + "\n" + command + "\n"
        if (command === "load") body += name + "\n"
        busy = true
        message = "Applying..."
        attempts = 0
        reading = false
        var xhr = new XMLHttpRequest()
        requestObject = xhr
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || !panel.busy) return
            panel.readFile("ui-command", function(actual) {
                if (!panel.busy) return
                if (actual !== body) panel.finishError("Cannot write PEQ request. Refresh and try again.")
                else panel.checkState()
            })
        }
        poll.start()
        xhr.open("PUT", runtimeUrl + "ui-command")
        xhr.send(body)
    }
    function checkState() {
        if (reading || !busy) return
        reading = true
        readFile("ui-state.json", function(text) {
            panel.reading = false
            if (!panel.busy) return
            try {
                var state = JSON.parse(text)
                if (state.requestId !== panel.pendingId) return
                panel.eqEnabled = state.enabled
                panel.backendReady = state.backendReady
                panel.selected = state.selected
                panel.profiles = state.profiles
                panel.pollStop()
                panel.message = !state.ok ? state.error : (!state.backendReady ? "PEQ backend unavailable. Check the PEQ log." : "")
            } catch (error) { }
        })
    }
    function pollStop() { poll.stop(); busy = false }
    function toggle() {
        if (eqEnabled) request("off", "")
        else if (selected.length) request("load", selected)
        else message = "Choose a .txt profile below."
    }
    Component.onCompleted: request("refresh", "")
    Component.onDestruction: { busy = false; poll.stop(); if (requestObject) requestObject.abort() }
    Timer {
        id: poll
        interval: 100
        repeat: true
        onTriggered: {
            panel.attempts++
            if (panel.attempts >= 50) panel.finishError("No response. Refresh to check the current setting.")
            else panel.checkState()
        }
    }
    MouseArea { anchors.fill: parent }
    Text {
        x: 20; y: 18; width: parent.width - 150; height: 48
        text: "Parametric EQ"; color: "white"; font.family: panel.fontFamily; font.pixelSize: 25
        verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
    }
    Rectangle {
        x: parent.width - 112; y: 18; width: 92; height: 48
        color: "#181818"; border.color: "#888888"
        Text { anchors.centerIn: parent; text: "Back"; color: "white"; font.family: panel.fontFamily; font.pixelSize: 21 }
        MouseArea { anchors.fill: parent; enabled: !panel.busy; onClicked: panel.closed() }
    }
    Rectangle { x: 20; y: 78; width: parent.width - 40; height: 1; color: "#555555" }
    Rectangle {
        x: 20; y: 96; width: 130; height: 58
        color: panel.eqEnabled ? "#333333" : "#111111"
        border.color: panel.backendReady ? "white" : "#555555"
        opacity: panel.busy ? 0.5 : 1
        Text { anchors.centerIn: parent; text: panel.eqEnabled ? "PEQ On" : "PEQ Off"; color: "white"; font.family: panel.fontFamily; font.pixelSize: 23 }
        MouseArea { anchors.fill: parent; enabled: !panel.busy && panel.backendReady; onClicked: panel.toggle() }
    }
    Text {
        x: 170; y: 92; width: parent.width - 190; height: 72
        text: panel.selected.length ? panel.selected : "No profile selected"
        color: "#dddddd"; font.family: panel.fontFamily; font.pixelSize: 20; wrapMode: Text.WrapAnywhere
        maximumLineCount: 3; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
    }
    Text { x: 20; y: 180; width: parent.width - 150; height: 40; text: "Load profile (.txt)"; color: "white"; font.family: panel.fontFamily; font.pixelSize: 22; verticalAlignment: Text.AlignVCenter }
    Rectangle {
        x: parent.width - 120; y: 178; width: 100; height: 42
        color: "#181818"; border.color: "#888888"
        Text { anchors.centerIn: parent; text: "Refresh"; color: "white"; font.family: panel.fontFamily; font.pixelSize: 18 }
        MouseArea { anchors.fill: parent; enabled: !panel.busy; onClicked: panel.request("refresh", "") }
    }
    ListView {
        id: profileList
        x: 20; y: 234; width: parent.width - 40; height: Math.max(0, parent.height - y - 100)
        clip: true; model: panel.profiles; spacing: 6
        boundsBehavior: Flickable.StopAtBounds
        delegate: Rectangle {
            width: profileList.width; height: 76
            color: panel.selected === modelData ? "#252525" : "#111111"
            border.color: panel.selected === modelData ? "white" : "#444444"
            Text { x: 12; y: 8; width: parent.width - 24; height: 60; text: modelData; color: "white"; font.family: panel.fontFamily; font.pixelSize: 21; wrapMode: Text.WrapAnywhere; maximumLineCount: 2; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
            MouseArea { anchors.fill: parent; enabled: !panel.busy && panel.backendReady; onClicked: panel.request("load", modelData) }
        }
        Text { anchors.centerIn: parent; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "No .txt profiles in PEQ"; color: "#aaaaaa"; font.family: panel.fontFamily; font.pixelSize: 20; visible: !panel.busy && panel.profiles.length === 0 }
    }
    Text {
        x: 20; y: parent.height - 88; width: parent.width - 40; height: 76
        text: panel.message.length ? panel.message : "Tap a profile to load and enable it."
        color: "#cccccc"; font.family: panel.fontFamily; font.pixelSize: 18; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
    }
}
