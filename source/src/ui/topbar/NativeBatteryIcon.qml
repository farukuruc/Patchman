import QtQuick 2.3

Item {
    id: statusIcon
    property var animationImage
    property var param
    property bool compactMode: false
    property int numberFontSize: 22
    property string imagePath: "qrc:/assets/images/"
    property var batteryModel: null
    readonly property string iconName: String(animationImage || "")
    readonly property bool nativeBattery: /^stat_sys_battery_(empty|level_[1-4]|full)\.png$/.test(iconName)
    property string currentImage: iconName.length ? imagePath + iconName : ""
    function reportIcon() {
        if (batteryModel && iconName.indexOf("stat_sys_battery_") === 0)
            batteryModel.noteNativeIcon(iconName)
    }
    onIconNameChanged: reportIcon()
    onBatteryModelChanged: reportIcon()
    Component.onCompleted: reportIcon()
    // Preserve Sony's measured slot and the alignment of all other status icons.
    readonly property real compactWidth: replacement.status === Loader.Ready && replacement.item.usable ? replacement.item.preferredWidth : Math.max(40, icon.implicitWidth)
    width: compactMode ? compactWidth : icon.width
    height: compactMode ? 28 : 0
    Image {
        id: icon
        objectName: "nativeStatusIcon"
        anchors.verticalCenter: parent.verticalCenter
        fillMode: Image.PreserveAspectFit
        anchors.right: statusIcon.compactMode ? parent.right : undefined
        source: statusIcon.currentImage
        visible: !(replacement.status === Loader.Ready && replacement.item.usable)
    }
    Loader {
        id: replacement
        active: statusIcon.nativeBattery
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: statusIcon.compactMode && item ? item.preferredWidth : 94
        height: statusIcon.compactMode ? 28 : (icon.height > 0 ? Math.min(icon.height, 24) : 24)
        source: "BatteryIndicator.qml"
    }
    Binding {
        target: replacement.item
        when: replacement.status === Loader.Ready
        property: "batteryModel"
        value: statusIcon.batteryModel
    }
    Binding {
        target: replacement.item
        when: replacement.status === Loader.Ready
        property: "compactMode"
        value: statusIcon.compactMode
    }
    Binding {
        target: replacement.item
        when: replacement.status === Loader.Ready
        property: "numberFontSize"
        value: statusIcon.numberFontSize
    }

}
