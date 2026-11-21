import QtQuick 2.3

// Sony PNG canvas sizes include unequal transparent margins. Scale the actual
// alpha bounds, not the surrounding canvas. No new image files or decoder.
Item {
    id: glyph
    property url source
    property real imageWidth: 30
    property real imageHeight: 28
    property rect inkRect: Qt.rect(0, 0, 30, 28)
    property real inkHeight: 22
    readonly property real inkScale: inkHeight / Math.max(1, inkRect.height)
    readonly property real naturalWidth: Math.ceil(inkRect.width * inkScale)
    width: naturalWidth
    height: 28
    clip: true
    Image {
        objectName: "scaledNativeGlyph"
        x: (glyph.width - glyph.inkRect.width * glyph.inkScale) / 2 - glyph.inkRect.x * glyph.inkScale
        y: (glyph.height - glyph.inkHeight) / 2 - glyph.inkRect.y * glyph.inkScale
        width: glyph.imageWidth * glyph.inkScale
        height: glyph.imageHeight * glyph.inkScale
        source: glyph.source
        fillMode: Image.Stretch
        smooth: true
    }
}
