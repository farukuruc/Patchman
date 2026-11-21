import QtQuick 2.3

Canvas {
    objectName: "compactVolumeSymbol"
    width: 22
    height: 22
    onPaint: {
        var c = getContext("2d")
        c.clearRect(0, 0, width, height)
        c.fillStyle = "white"
        c.beginPath()
        c.moveTo(1, 7); c.lineTo(5, 7); c.lineTo(11, 1)
        c.lineTo(11, 21); c.lineTo(5, 15); c.lineTo(1, 15)
        c.closePath(); c.fill()
        c.strokeStyle = "white"
        c.lineWidth = 1.5
        c.lineCap = "round"
        c.beginPath(); c.arc(10, 11, 5, -0.8, 0.8, false); c.stroke()
        c.beginPath(); c.arc(10, 11, 10, -0.8, 0.8, false); c.stroke()
    }
}
