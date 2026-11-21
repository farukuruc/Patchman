import QtQuick 2.3
import "file:///data/sony-peq/runtime/AlbumYearCache.js" as Metadata

Image {
    property string artistName: ""
    property bool photoAllowed: false
    readonly property string selectedPhoto: typeof Metadata.photo === "function" ? Metadata.photo(artistName) : ""
    readonly property bool showAlbumCover: !photoAllowed || selectedPhoto === "" || status === Image.Error
    readonly property bool photoReady: photoAllowed && status === Image.Ready
    source: photoAllowed ? selectedPhoto : ""
    sourceSize.width: 84
    sourceSize.height: 84
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: true
    smooth: true
    visible: photoReady
    clip: true
}
