import QtQuick 2.3
import "qrc:/components"
SwipeDetectionButton {
id: shuffle
property bool is_shuffle: false
property bool is_simple_mode: false
property string load_image_source: ""
property string pressed_image_source: ""
signal startedSwipe()
width: 65
height: 110
loadComponent: is_simple_mode ? normalImage : normalIcon
pressedComponent: is_simple_mode ? pressedImage : pressedIcon
disableComponent: is_simple_mode ? normalImage : normalIcon
onIs_shuffleChanged: changeImage()
onIs_simple_modeChanged: changeImage()
onSwipeDetect: shuffle.startedSwipe()
Component.onCompleted: changeImage()
function changeImage() {
var stem="qrc:/assets/images/btn_audio_play_"+(is_simple_mode?"hp_amp_":"")+"shuffle_"+(is_shuffle?"on":"off")
load_image_source=stem+"_normal.png"
pressed_image_source=stem+"_pressed.png"
}
function paintIcon(canvas, pressed) {
var c=canvas.getContext("2d")
c.clearRect(0,0,canvas.width,canvas.height)
c.save()
c.translate(18,40)
c.beginPath();c.rect(0,0,32,26);c.clip()
c.strokeStyle="white"
c.globalAlpha=is_shuffle?1:(pressed?113/255:77/255)
c.lineWidth=pressed?2.5:2
c.lineCap="round";c.lineJoin="round"
c.beginPath()
c.moveTo(1,5.5);c.lineTo(8,5.5);c.bezierCurveTo(14,5.5,18,20.5,24,20.5);c.lineTo(30,20.5)
c.moveTo(26,16.5);c.lineTo(30,20.5);c.lineTo(26,24.5)
c.moveTo(1,20.5);c.lineTo(8,20.5);c.bezierCurveTo(14,20.5,18,5.5,24,5.5);c.lineTo(30,5.5)
c.moveTo(26,1.5);c.lineTo(30,5.5);c.lineTo(26,9.5)
c.stroke();c.restore()
}
Component { id: normalImage; Image { source: shuffle.load_image_source } }
Component { id: pressedImage; Image { source: shuffle.pressed_image_source } }
Component {
id: normalIcon
Canvas {
id: normalCanvas
onPaint: shuffle.paintIcon(this,false)
Connections { target: shuffle; onIs_shuffleChanged: normalCanvas.requestPaint() }
}
}
Component {
id: pressedIcon
Canvas {
id: pressedCanvas
onPaint: shuffle.paintIcon(this,true)
Connections { target: shuffle; onIs_shuffleChanged: pressedCanvas.requestPaint() }
}
}
}
