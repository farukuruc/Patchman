import QtQuick 2.3

Item {
    id: indicator
    objectName: "patchmanBatteryIndicator"
    property var batteryModel: null
    property var registeredModel: null
    readonly property bool usable: !!(batteryModel && batteryModel.available)
    readonly property bool animating: usable && visible && batteryModel.charging && batteryModel.percent < 100 && batteryModel.screenOn
    readonly property real level: usable ? batteryModel.percent / 100 : 0
    readonly property bool full: usable && batteryModel.full
    property real sweep: 0
    readonly property real fillFraction: animating ? level + (1 - level) * sweep : level
    property string fontFamily: typeof viewstyle !== "undefined" ? viewstyle.font_family : ""
    property bool compactMode: false
    property int numberFontSize: 22
    readonly property real preferredWidth: body.width + terminal.width + (full ? fullText.implicitWidth + 5 : (usable && batteryModel.charging ? 19 : 0))
    width: 94
    height: 24

    function syncConsumer() {
        var wanted = visible ? batteryModel : null
        if (registeredModel === wanted) return
        if (registeredModel) registeredModel.release()
        registeredModel = wanted
        if (registeredModel) registeredModel.acquire()
    }
    onVisibleChanged: syncConsumer()
    onBatteryModelChanged: syncConsumer()
    Component.onCompleted: syncConsumer()
    Component.onDestruction: { if (registeredModel) registeredModel.release() }
    onAnimatingChanged: if (!animating) sweep = 0
    SequentialAnimation on sweep {
        running: indicator.animating
        loops: Animation.Infinite
        NumberAnimation { from: 0; to: 1; duration: 2100; easing.type: Easing.Linear }
        PauseAnimation { duration: 300 }
        PropertyAction { value: 0 }
    }
    Item {
        anchors.fill: parent
        visible: indicator.usable
        Text {
            id: fullText
            objectName: "batteryFullLabel"
            anchors.right: terminal.left
            anchors.rightMargin: 5
            anchors.verticalCenter: body.verticalCenter
            text: indicator.full ? "FULL" : ""
            color: "white"
            font.family: indicator.fontFamily
            font.pixelSize: indicator.compactMode ? 16 : 12
            renderType: Text.NativeRendering
        }
        Canvas {
            objectName: "batteryChargingBolt"
            anchors.right: terminal.left
            anchors.rightMargin: 5
            anchors.verticalCenter: body.verticalCenter
            width: 14
            height: Math.min(indicator.compactMode ? 22 : 16, indicator.height)
            visible: indicator.usable && indicator.batteryModel.charging
            onPaint: {
                var context = getContext("2d")
                context.clearRect(0, 0, width, height)
                context.fillStyle = "white"
                context.beginPath()
                context.moveTo(width * 0.64, 0)
                context.lineTo(width * 0.06, height * 0.57)
                context.lineTo(width * 0.45, height * 0.57)
                context.lineTo(width * 0.32, height)
                context.lineTo(width * 0.96, height * 0.38)
                context.lineTo(width * 0.57, height * 0.38)
                context.closePath()
                context.fill()
            }
        }
        Rectangle {
            id: terminal
            objectName: "batteryLeftTerminal"
            anchors.right: body.left
            anchors.verticalCenter: body.verticalCenter
            width: 3; height: 7
            color: "white"
        }
        Rectangle {
            id: body
            objectName: "batteryBody"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: indicator.compactMode ? Math.max(58, Math.ceil(whiteNumber.implicitWidth) + 12) : 54
            height: Math.min(indicator.compactMode ? 28 : 20, indicator.height)
            radius: 2
            color: "black"
            border.color: "white"
            border.width: 1
            Item {
                id: inside
                anchors.fill: parent
                anchors.margins: 2
                Rectangle {
                    id: fill
                    objectName: "batteryWhiteFill"
                    anchors.right: parent.right
                    height: parent.height
                    width: Math.round(parent.width * indicator.fillFraction)
                    color: "white"
                }
                Text {
                    id: whiteNumber
                    objectName: "batteryPercentText"
                    anchors.fill: parent
                    text: indicator.usable ? indicator.batteryModel.percent + "%" : ""
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: "white"
                    font.family: indicator.fontFamily
                    font.pixelSize: indicator.compactMode ? indicator.numberFontSize : 12
                    font.weight: Font.Normal
                    renderType: Text.NativeRendering
                }
                Item {
                    objectName: "batteryTextClip"
                    anchors.right: parent.right
                    height: parent.height
                    width: fill.width
                    clip: true
                    Text {
                        // Keep both glyph runs at exactly the same position.
                        anchors.right: parent.right
                        width: inside.width
                        height: inside.height
                        text: whiteNumber.text
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: "black"
                        font: whiteNumber.font
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
    }
}
