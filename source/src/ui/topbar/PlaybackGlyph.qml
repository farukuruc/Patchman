import QtQuick 2.3
import "HeaderLayout.js" as Layout

// One fixed slot follows Sony's native status; no separate audio state or keys.
Item {
    id: playback
    objectName: "compactPlaybackGlyph"
    property var statusModel: null
    property string imagePath: "qrc:/assets/images/"
    property string nativeName: ""
    readonly property var metrics: Layout.playbackMetrics(nativeName)
    width: 28
    height: 28
    visible: Layout.playback(nativeName)
    function updateState() {
        var selected = ""
        for (var i = 0; i < rows.count; i++) {
            var row = rows.itemAt(i)
            if (row && row.eligible) { selected = row.name; break }
        }
        nativeName = selected
    }
    Timer { id: playbackRefresh; interval: 0; onTriggered: playback.updateState() }
    Repeater {
        id: rows
        model: playback.statusModel
        onItemAdded: playbackRefresh.restart()
        onItemRemoved: playbackRefresh.restart()
        delegate: Item {
            width: 0; height: 0; visible: false
            property string name: String(ParamAnimationImageRole)
            property bool eligible: Number(QmlIntRole) === 1 && Number(ParamIntFrameSize) > 0 && Layout.playback(name)
            onNameChanged: playbackRefresh.restart()
            onEligibleChanged: playbackRefresh.restart()
        }
    }
    NativeGlyph {
        objectName: "nativePlaybackSymbol"
        anchors.centerIn: parent
        imageWidth: playback.metrics.width
        imageHeight: playback.metrics.height
        inkRect: Qt.rect(playback.metrics.ink[0], playback.metrics.ink[1], playback.metrics.ink[2], playback.metrics.ink[3])
        inkHeight: Math.min(22, 28 * inkRect.height / Math.max(1, inkRect.width))
        source: playback.visible ? playback.imagePath + playback.nativeName : ""
    }
}
