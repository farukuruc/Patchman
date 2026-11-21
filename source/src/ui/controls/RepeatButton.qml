import QtQuick 2.3
import "qrc:/components"
SwipeDetectionButton {
id: repeat
property int repeat_mode: 0
property bool is_simple_mode: false
property string load_image_source: ""
property string pressed_image_source: ""
signal startedSwipe()
width: 65
height: 110
loadComponent: is_simple_mode ? normalImage : normalIcon
pressedComponent: is_simple_mode ? pressedImage : pressedIcon
disableComponent: is_simple_mode ? normalImage : normalIcon
onRepeat_modeChanged: changeImage()
onIs_simple_modeChanged: changeImage()
onSwipeDetect: repeat.startedSwipe()
Component.onCompleted: changeImage()
function changeImage() {
if (repeat_mode<0 || repeat_mode>2) { load_image_source=""; pressed_image_source=""; return }
var stem="qrc:/assets/images/btn_audio_play_"+(is_simple_mode?"hp_amp_":"")+"repeat_"+["off","current","all"][repeat_mode]
load_image_source=stem+"_normal.png"
pressed_image_source=stem+"_pressed.png"
}
function paintIcon(canvas, pressed) {
var c=canvas.getContext("2d")
c.clearRect(0,0,canvas.width,canvas.height)
if (repeat_mode<0 || repeat_mode>2) return
c.save();c.translate(15,45)
c.beginPath();c.rect(0,0,33,24);c.clip()
c.strokeStyle="white";c.fillStyle="white"
c.globalAlpha=repeat_mode?1:(pressed?113/255:77/255)
c.lineWidth=pressed?2.5:2
c.lineCap="round";c.lineJoin="round"
c.beginPath()
c.moveTo(3,12);c.lineTo(3,4);c.lineTo(30,4)
c.moveTo(26,0);c.lineTo(30,4);c.lineTo(26,8)
c.moveTo(30,12);c.lineTo(30,20);c.lineTo(3,20)
c.moveTo(7,16);c.lineTo(3,20);c.lineTo(7,24)
c.stroke()
if (repeat_mode===1) {
c.font="bold 12px sans-serif";c.textAlign="center";c.textBaseline="middle"
c.fillText("1",16.5,12)
}
c.restore()
}
Component { id: normalImage; Image { source: repeat.load_image_source } }
Component { id: pressedImage; Image { source: repeat.pressed_image_source } }
Component {
id: normalIcon
Canvas {
id: normalCanvas
onPaint: repeat.paintIcon(this,false)
Connections { target: repeat; onRepeat_modeChanged: normalCanvas.requestPaint() }
}
}
Component {
id: pressedIcon
Canvas {
id: pressedCanvas
onPaint: repeat.paintIcon(this,true)
Connections { target: repeat; onRepeat_modeChanged: pressedCanvas.requestPaint() }
}
}
}
