import QtQuick 2.3
import "qrc:/parts"

Item {
    id: loop
    objectName: "continuousTitle"
    property var titleHost: null
    property string brightnessUrl: "file:///sys/class/leds/lcd-backlight/brightness"
    property bool screenAwake: false
    property bool pending: false
    property var request: null
    property int generation: 0
    property real pixelsPerSecond: 32
    property real gap: 56
    readonly property string title: titleHost ? titleHost.loopText : ""
    readonly property bool overflow: first.implicitWidth > width && width > 0
    readonly property real distance: first.implicitWidth + gap
    readonly property int cycleDuration: Math.max(1, Math.round(distance / pixelsPerSecond * 1000))
    readonly property bool wanted: visible && !!titleHost && titleHost.visible && titleHost.isUseMarquee && overflow
    readonly property bool motionRunning: motion.running
    clip: true

    function cancelRead() {
        generation++
        deadline.stop()
        if (request) request.abort()
        request = null
        pending = false
    }
    function readDisplay() {
        if (!wanted || pending) return
        pending = true
        var serial = ++generation
        var xhr = new XMLHttpRequest()
        request = xhr
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || serial !== generation) return
            deadline.stop()
            pending = false
            request = null
            var value = String(xhr.responseText).replace(/^\s+|\s+$/g, "")
            loop.screenAwake = (xhr.status === 0 || xhr.status === 200) && /^\d+$/.test(value) && Number(value) > 0
        }
        deadline.start()
        xhr.open("GET", brightnessUrl + "?r=" + Date.now())
        xhr.send()
    }
    function resetMotion() {
        motion.stop()
        track.x = 0
        if (wanted && screenAwake) motion.start()
    }
    onTitleChanged: resetMotion()
    onDistanceChanged: resetMotion()
    onCycleDurationChanged: resetMotion()
    onWidthChanged: resetMotion()
    onWantedChanged: {
        if (wanted) readDisplay()
        else { cancelRead(); screenAwake = false }
        resetMotion()
    }
    onScreenAwakeChanged: resetMotion()
    onBrightnessUrlChanged: { cancelRead(); screenAwake = false; readDisplay() }
    Component.onCompleted: readDisplay()
    Component.onDestruction: cancelRead()

    Item {
        id: track
        width: loop.distance * 2
        height: first.height
        SCmnLabel {
            id: first
            objectName: "loopFirst"
            width: loop.overflow ? implicitWidth : loop.width
            text: loop.title
            font.pixelSize: loop.titleHost ? loop.titleHost.pixelSize : 30
            font.weight: loop.titleHost ? loop.titleHost.fontWeight : Font.Normal
            color: loop.titleHost ? loop.titleHost.fontColor : "white"
            horizontalAlignment: loop.overflow ? Text.AlignLeft : Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        SCmnLabel {
            objectName: "loopSecond"
            x: loop.distance
            visible: loop.overflow
            text: first.text
            font: first.font
            color: first.color
            verticalAlignment: Text.AlignVCenter
        }
    }
    XAnimator {
        id: motion
        objectName: "loopMotion"
        target: track
        from: 0
        to: -loop.distance
        duration: loop.cycleDuration
        loops: Animation.Infinite
        easing.type: Easing.Linear
    }
    // Read-only display check, only while a visible long title needs motion.
    Timer { interval: 1000; repeat: true; running: loop.wanted; onTriggered: loop.readDisplay() }
    Timer { id: deadline; interval: 1500; onTriggered: { loop.cancelRead(); loop.screenAwake = false } }
    Image {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: loop.overflow && loop.motionRunning
        source: loop.titleHost ? loop.titleHost.left_mask_image_path : ""
    }
    Image {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: loop.overflow
        source: loop.titleHost ? loop.titleHost.right_mask_image_path : ""
    }
}
