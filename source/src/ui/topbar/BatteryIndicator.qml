import QtQuick 2.3

Item {
    id: indicator
    objectName: "patchmanBatteryIndicator"
    property var batteryModel: null
    property var registeredModel: null
    property bool compactMode: false
    property int numberFontSize: 22
    property string fontFamily: typeof viewstyle !== "undefined" ? viewstyle.font_family : ""
    readonly property bool usable: !!(batteryModel && batteryModel.available)
    readonly property bool full: usable && batteryModel.full
    readonly property bool charging: usable && batteryModel.charging && !full
    readonly property real level: usable ? Math.max(0, Math.min(1, batteryModel.percent / 100)) : 0
    readonly property real arcFraction: full ? 1 : level
    readonly property bool animating: false
    readonly property real preferredWidth: content.width
    width: preferredWidth
    height: 28

    function syncConsumer() {
        var wanted = visible ? batteryModel : null
        if (registeredModel === wanted) return
        if (registeredModel) registeredModel.release()
        registeredModel = wanted
        if (registeredModel) registeredModel.acquire()
    }
    onVisibleChanged: syncConsumer()
    onBatteryModelChanged: syncConsumer()
    onArcFractionChanged: ring.requestPaint()
    Component.onCompleted: { syncConsumer(); ring.requestPaint() }
    Component.onDestruction: { if (registeredModel) registeredModel.release() }

    Row {
        id: content
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: indicator.height
        spacing: 4
        visible: indicator.usable
        Item {
            width: indicator.full ? fullText.implicitWidth : (indicator.charging ? 14 : 0)
            height: content.height
            visible: indicator.full || indicator.charging
            Text {
                id: fullText
                objectName: "batteryFullLabel"
                anchors.verticalCenter: parent.verticalCenter
                text: indicator.full ? "FULL" : ""
                color: "white"
                font.family: indicator.fontFamily
                font.pixelSize: indicator.compactMode ? 16 : 12
                renderType: Text.NativeRendering
            }
            Canvas {
                objectName: "batteryChargingBolt"
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: Math.min(22, indicator.height)
                visible: indicator.charging
                onPaint: {
                    var c = getContext("2d")
                    c.clearRect(0, 0, width, height)
                    c.fillStyle = "white"
                    c.beginPath()
                    c.moveTo(width * 0.64, 0)
                    c.lineTo(width * 0.06, height * 0.57)
                    c.lineTo(width * 0.45, height * 0.57)
                    c.lineTo(width * 0.32, height)
                    c.lineTo(width * 0.96, height * 0.38)
                    c.lineTo(width * 0.57, height * 0.38)
                    c.closePath()
                    c.fill()
                }
            }
        }
        Canvas {
            id: ring
            objectName: "batteryHalfRing"
            anchors.verticalCenter: parent.verticalCenter
            width: height / 2 + 1
            height: Math.min(indicator.compactMode ? 24 : 20, indicator.height)
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()
            onPaint: {
                var c = getContext("2d")
                c.clearRect(0, 0, width, height)
                var radius = height / 2 - 1
                var cx = width - 1
                var cy = height / 2
                var start = Math.PI / 2
                c.lineWidth = 1.6
                c.lineCap = "butt"
                c.strokeStyle = "#555555"
                c.beginPath()
                c.arc(cx, cy, radius, start, start + Math.PI, false)
                c.stroke()
                if (indicator.arcFraction > 0) {
                    c.strokeStyle = "white"
                    c.beginPath()
                    c.arc(cx, cy, radius, start, start + Math.PI * indicator.arcFraction, false)
                    c.stroke()
                }
            }
        }
        Text {
            objectName: "batteryPercentText"
            anchors.verticalCenter: parent.verticalCenter
            width: Math.ceil(implicitWidth)
            height: content.height
            text: indicator.usable ? indicator.batteryModel.percent + "%" : ""
            color: "white"
            font.family: indicator.fontFamily
            font.pixelSize: indicator.compactMode ? indicator.numberFontSize : 12
            font.weight: Font.Normal
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            renderType: Text.NativeRendering
        }
    }
}
