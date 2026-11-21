import QtQuick 2.3
import "HeaderLayout.js" as Layout

Row {
    id: cluster
    objectName: "compactStatusCluster"
    property var headerValues: null
    property var statusModel: headerValues ? headerValues.stateIconList : null
    property int volume: headerValues ? headerValues.volume : 0
    property string volumeDisplayType: headerValues ? headerValues.volumeDisplayType : "Numeric"
    property bool volumePopupOpen: headerValues ? headerValues.isVolPopupOpen : false
    property bool visibleVolumeChange: headerValues ? headerValues.visibleVolumeChange : false
    property bool plusVolume: headerValues ? headerValues.isChgPlusVolume : false
    property bool highGain: headerValues ? headerValues.isHighGain : false
    property string imagePath: "qrc:/assets/images/"
    property var batteryModel: batteryState
    BatteryState { id: batteryState; visible: false }
    property string fontFamily: typeof viewstyle !== "undefined" ? viewstyle.font_family : ""
    property int volumeFontSize: 22
    spacing: 8
    height: 28

    PlaybackGlyph {
        id: playback
        statusModel: cluster.statusModel
        imagePath: cluster.imagePath
    }
    Row {
        id: wireless
        objectName: "compactWireless"
        height: cluster.height
        spacing: 8
        property bool hasWireless: false
        visible: hasWireless
        function updateVisibility() {
            var found = false
            for (var i = 0; i < bluetoothIcons.count; i++) {
                var bt = bluetoothIcons.itemAt(i)
                if (bt && bt.enabledIcon) found = true
            }
            for (var j = 0; j < nfcIcons.count; j++) {
                var nfc = nfcIcons.itemAt(j)
                if (nfc && nfc.enabledIcon) found = true
            }
            hasWireless = found
        }
        Timer { id: wirelessRefresh; interval: 0; onTriggered: wireless.updateVisibility() }
        Repeater {
            id: bluetoothIcons
            model: cluster.statusModel
            onItemAdded: wirelessRefresh.restart()
            onItemRemoved: wirelessRefresh.restart()
            delegate: NativeGlyph {
                objectName: "compactBluetooth"
                imageWidth: 19
                inkRect: Qt.rect(2, 3, 15, 22)
                readonly property bool enabledIcon: Number(QmlIntRole) === 1 && String(ParamAnimationImageRole) === "stat_sys_bluetooth.png" && Number(ParamIntFrameSize) > 0
                visible: enabledIcon
                onEnabledIconChanged: wirelessRefresh.restart()
                width: enabledIcon ? naturalWidth : 0
                height: cluster.height
                source: enabledIcon ? cluster.imagePath + "stat_sys_bluetooth.png" : ""
            }
        }
        Repeater {
            id: nfcIcons
            model: cluster.statusModel
            onItemAdded: wirelessRefresh.restart()
            onItemRemoved: wirelessRefresh.restart()
            delegate: NativeGlyph {
                objectName: "compactNfc"
                imageWidth: 30
                inkRect: Qt.rect(5, 4, 20, 20)
                readonly property bool enabledIcon: Number(QmlIntRole) === 1 && String(ParamAnimationImageRole) === "stat_sys_nfc.png" && Number(ParamIntFrameSize) > 0
                visible: enabledIcon
                onEnabledIconChanged: wirelessRefresh.restart()
                width: enabledIcon ? naturalWidth : 0
                height: cluster.height
                source: enabledIcon ? cluster.imagePath + "stat_sys_nfc.png" : ""
            }
        }
    }
    Rectangle {
        id: volumeBox
        objectName: "compactVolume"
        width: Math.ceil(volumeContent.implicitWidth) + 12
        height: cluster.height
        radius: 5
        color: "black"
        border.color: "white"
        border.width: 0
        visible: !cluster.volumePopupOpen && (cluster.volumeDisplayType === "Numeric" || (cluster.volumeDisplayType === "PlusMinus" && cluster.visibleVolumeChange))
        Row {
            id: volumeContent
            anchors.centerIn: parent
            height: cluster.height
            spacing: 5
            SpeakerGlyph { anchors.verticalCenter: parent.verticalCenter }
            Text {
                objectName: "compactVolumeText"
                height: cluster.height
                visible: cluster.volumeDisplayType === "Numeric"
                text: String(cluster.volume)
                font.family: cluster.fontFamily
                font.pixelSize: cluster.volumeFontSize
                font.weight: Font.Normal
                color: "#f1f1f1"
                verticalAlignment: Text.AlignVCenter
                renderType: Text.NativeRendering
            }
            Text {
                height: cluster.height
                visible: cluster.volumeDisplayType === "PlusMinus"
                text: cluster.plusVolume ? "+" : "\u2212"
                font.family: cluster.fontFamily
                font.pixelSize: cluster.volumeFontSize
                color: "white"
                verticalAlignment: Text.AlignVCenter
                renderType: Text.NativeRendering
            }
        }
    }
    Repeater {
        model: cluster.statusModel
        delegate: Loader {
            id: batterySlot
            objectName: "compactBatterySlot"
            property string nativeName: String(ParamAnimationImageRole)
            property var nativeParam: ParamQvariantRole
            readonly property bool eligible: Layout.batteryIcon(QmlIntRole, nativeName) && Number(ParamIntFrameSize) > 0
            visible: eligible
            active: eligible
            // Never derive Loader.width from item.width: the Loader can itself
            // resize item.width. Reserve a real slot before the image loads.
            width: item ? item.compactWidth : 40
            height: cluster.height
            source: "NativeBatteryIcon.qml"
            onLoaded: {
                item.compactMode = true
                item.numberFontSize = Qt.binding(function(){return cluster.volumeFontSize})
                item.animationImage = Qt.binding(function(){return batterySlot.nativeName})
                item.param = Qt.binding(function(){return batterySlot.nativeParam})
                item.imagePath = Qt.binding(function(){return cluster.imagePath})
                item.batteryModel = Qt.binding(function(){return cluster.batteryModel})
            }
        }
    }
}
