import QtQuick 2.3

Rectangle {
    id: tape
    color: "black"
    property var playerWindow: null
    property var metadataSource: null
    property var trackMetadata: metadataSource && metadataSource.meta_data ? metadataSource.meta_data : ({})
    property string trackTitle: trackMetadata.play_title || (supported && playerWindow.basicPlayerControls["playTitle"]) || ""
    property string trackArtist: trackMetadata.artist_name || ""
    property string displayTitle: trackTitle.toUpperCase()
    property string displayArtist: trackArtist.toUpperCase()
    property string fontFamily: typeof viewstyle !== "undefined" ? viewstyle.font_family : ""
    property bool nativeHold: false
    property bool screenOn: false
    property bool readPending: false
    property bool brightnessWarned: false
    property string brightnessUrl: "file:///sys/class/leds/lcd-backlight/brightness"
    property string diagnosticRoot: "file:///data/sony-peq/runtime/"
    property var statusModel: playerWindow && playerWindow.headerArea ? playerWindow.headerArea["stateIconList"] : null
    property bool supported: !!(playerWindow && playerWindow.basicPlayerControls)
    property bool holdActive: nativeHold
    property bool playing: !!(supported && playerWindow.basicPlayerControls["playState"])
    property bool displayAwake: screenOn
    property bool animating: visible && displayAwake && playing
    visible: supported && holdActive
    onVisibleChanged: { if (visible) readBrightness() }

    function scanHold() {
        var found = false
        for (var i = 0; i < icons.count; i++) {
            var icon = icons.itemAt(i)
            if (icon && icon.iconName.indexOf("hold") >= 0 && icon.iconWidth > 0) found = true
        }
        nativeHold = found
        diagnostic.restart()
    }
    function saveDiagnostic() {
        var entries = []
        for (var i = 0; i < icons.count; i++) {
            var icon = icons.itemAt(i)
            if (icon) entries.push({image:icon.iconName,width:icon.iconWidth})
        }
        var xhr = new XMLHttpRequest()
        xhr.open("PUT", diagnosticRoot + "cassette-component.json")
        xhr.send(JSON.stringify({version:7,stage:"component",supported:supported,hold:holdActive,playing:playing,screenOn:screenOn,visible:visible,width:width,height:height,title:displayTitle,artist:displayArtist,metadataSource:String(metadataSource),icons:entries}))
    }
    Timer { id: diagnostic; interval:50; onTriggered:tape.saveDiagnostic() }
    function readBrightness() {
        if (readPending || !visible) return
        readPending = true
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            tape.readPending = false
            var value = xhr.responseText.replace(/^\s+|\s+$/g, "")
            if (!/^\d+$/.test(value)) {
                tape.screenOn = false
                if (!tape.brightnessWarned) console.log("sony-cassette: brightness unavailable")
                tape.brightnessWarned = true
                return
            }
            tape.screenOn = Number(value) > 0
            tape.brightnessWarned = false
        }
        xhr.open("GET", brightnessUrl + "?r=" + Date.now())
        xhr.send()
    }
    onHoldActiveChanged: { console.log("sony-cassette: hold=" + holdActive); diagnostic.restart() }
    onPlayingChanged: { console.log("sony-cassette: playing=" + playing); diagnostic.restart() }
    onDisplayAwakeChanged: { console.log("sony-cassette: display=" + displayAwake); diagnostic.restart() }
    onSupportedChanged: { console.log("sony-cassette: supported=" + supported); diagnostic.restart() }
    onTrackTitleChanged: diagnostic.restart()
    onTrackArtistChanged: diagnostic.restart()
    Component.onCompleted: { console.log("sony-cassette: native overlay loaded; supported=" + supported); diagnostic.restart() }
    Timer { id: scan; interval: 0; onTriggered: tape.scanHold() }
    Item {
        visible: false
        Repeater {
            id: icons
            model: tape.statusModel
            onItemAdded: scan.restart()
            onItemRemoved: scan.restart()
            delegate: Item {
                property string iconName: String(ParamAnimationImageRole)
                property int iconWidth: ParamIntFrameSize
                onIconNameChanged: scan.restart()
                onIconWidthChanged: scan.restart()
            }
        }
    }
    // Check the backlight only while HOLD is active. This also detects wakeup
    // when Sony leaves the application/window marked visible during screen-off.
    Timer { objectName: "cassetteDisplayPoll"; interval: tape.screenOn ? 500 : 150; repeat: true; running: tape.visible; onTriggered: tape.readBrightness() }
    Item {
        width: 800; height: 480
        anchors.centerIn: parent
        rotation: 90
        scale: Math.min(tape.width / 480, tape.height / 800)
        Image { anchors.fill: parent; source: "assets/tape.png" }
        Text {
            x: 87; y: 78; width: 600; height: 30
            text: tape.displayTitle; color: "black"
            font.family: tape.fontFamily; font.pixelSize: 24
            elide: Text.ElideRight; textFormat: Text.PlainText
        }
        Text {
            x: 87; y: 110; width: 600; height: 28
            text: tape.displayArtist; color: "black"
            font.family: tape.fontFamily; font.pixelSize: 22
            elide: Text.ElideRight; textFormat: Text.PlainText
        }
        Item {
            id: reels
            objectName: "cassetteReels"
            x: 134; y: 160; width: 528; height: 116
            clip: true
            property int frame: 0
            property bool running: tape.visible && tape.displayAwake
            property bool paused: !tape.playing
            // Keep one static, <= 2048-pixel texture. Avoid AnimatedSprite's
            // texture/shader lifecycle on Sony's old Qt / GPU driver.
            Image {
                objectName: "cassetteAtlasTexture"
                source: "assets/reels.png"
                // 264x58 pixels per frame, with 2-pixel extruded edge padding.
                x: -((reels.frame % 4) * 268 + 2) * 2
                y: -(Math.floor(reels.frame / 4) * 62 + 2) * 2
                width: 2144; height: 1860
                asynchronous: false
                smooth: true
            }
            Timer {
                interval: 55; repeat: true
                running: reels.running && !reels.paused
                onTriggered: reels.frame = (reels.frame + 1) % 57
            }
        }
    }
    MouseArea { anchors.fill: parent }
}
