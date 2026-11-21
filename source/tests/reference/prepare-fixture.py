import pathlib,sys,re,zlib
HERE=pathlib.Path(__file__).resolve().parent.parent
WORK=HERE.parent.parent/'work/Patchman-v1.5-Final'
dest=pathlib.Path(sys.argv[1]).resolve();dest.mkdir(parents=True,exist_ok=True)
(dest/'parts').mkdir(exist_ok=True);(dest/'assets').mkdir(exist_ok=True)
def transform(s):
    # Only unchanged firmware widgets are stubbed. Exercise the actual patched
    # metadata, scrub layout, seek handlers and standard-player activation.
    s=s.replace('import QtQuick.Controls 1.2','').replace('import QtQuick.Controls.Styles 1.2','')
    s=s.replace('"qrc:/parts"','"./parts"').replace('"qrc:/components"','"."').replace('"qrc:/framework"','"./parts"').replace('import "qrc:/"','import "."')
    s=s.replace('qrc:/assets/images/',(dest/'assets').as_uri()+'/').replace('qrc:/',(dest/'assets').as_uri()+'/')
    s=s.replace('file:/opt2/appresouce/',(dest/'assets').as_uri()+'/')
    for name in ('labelTitle','labelArtist','labelAlbum','scrubBar','scrub','lyricsImage','hiResIcon','currentlyPlayingTimeTextArea','scrubBarSlider'):
        s=s.replace('id: '+name+'\n','id: '+name+'\nobjectName: "'+name+'"\n')
    return s
binary=(WORK/'player').read_bytes()
for name,off in [('PlayerMetaDataArea',0x6315a1),('ScrubBar',0x5edccc),('StandardPlayer',0x634b92),('BasicPlayerControls',0x5ec469),('ShuffleButton',0x5fbb51),('RepeatButton',0x5f9527)]:
    n=int.from_bytes(binary[off:off+4],'big')
    data=binary[off+4:off+4+n] if off in (0x634b92,0x5fbb51) else zlib.decompress(binary[off+8:off+4+n])
    text=transform(data.decode('utf-8'))
    if name=='ShuffleButton':
        text=text.replace('import QtQuick 2.3','import QtQuick 2.3\nimport "./parts"')
        text=text.replace('id: shuffle','id: shuffle\nobjectName: "nativeShuffle"')
    if name=='RepeatButton':
        text=text.replace('import QtQuick 2.3','import QtQuick 2.3\nimport "./parts"')
        text=text.replace('id: repeat','id: repeat\nobjectName: "nativeRepeat"')
    if name=='BasicPlayerControls':
        text=text.replace('id: playTitleText\n','id: playTitleText\nobjectName: "miniTitle"\n')
        labels=iter(('previousControl','playControlButton','nextControl'))
        text=re.sub(r'SwipeDetectionButton \{',lambda m:m[0]+'\nobjectName: "'+next(labels)+'"',text)
        for kind in ('loadComponent','pressedComponent','disableComponent'):
            text=text.replace(kind+': Image {',kind+': Image {\nobjectName: "controlVisual"')
    (dest/(name+'.qml')).write_bytes(text.encode())
stubs={
'SCmnMonospaceLabel.qml':'Text {}',
'SCmnMarquee.qml':'''Item {
property string displayText: ""
property int pixelSize; property int fontWeight; property color fontColor
property bool isUseMarquee; property string left_mask_image_path; property string right_mask_image_path
function setMainText(value) { displayText=value }
Text { width: parent.width; text: parent.displayText; font.pixelSize: parent.pixelSize; font.weight: parent.fontWeight; color: parent.fontColor; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
}''',
'SliderStyle.qml':'QtObject { property Component groove; property Component handle }',
'SCmnSlider.qml':'''Item {
property real value; property real maxValue; property real sliderStep
property bool tapEnable; property int pressAndHoldDuration
property int expandTapHeightBottom; property int expandTapWidth
property bool sliderHoldingPressed: false
property real grooveHeight: 2
property var slider_style
signal pressed(); signal released(); signal startedSwipe()
}''',
'SwipeDetectionButton.qml':'''Item {
property bool enable: true; property bool isEnablePressAndHold: false
property Component loadComponent; property Component pressedComponent; property Component disableComponent
property int visualState: 0
signal clicked(); signal pressAndHold(); signal released(); signal swipeDetect()
Loader { anchors.fill: parent; sourceComponent: !parent.enable ? parent.disableComponent : parent.visualState === 1 ? parent.pressedComponent : parent.loadComponent }
}'''}
for name,s in stubs.items():(dest/'parts'/name).write_text('import QtQuick 2.3\n'+s+'\n',encoding='utf-8')
(dest/'ScreenBase.qml').write_text('import QtQuick 2.3\nItem { property QtObject controller: QtObject { signal available(); signal unavailable() } }\n',encoding='utf-8')
(dest/'CoverArt.qml').write_text('import QtQuick 2.3\nItem { objectName:"cover"; property string loading_image_path; property var contents_id; property var update_db_counter }\n',encoding='utf-8')
(dest/'SwipeSelectorViewJudge.qml').write_text('import QtQuick 2.3\nItem { property var target; signal reqSwipe() }\n',encoding='utf-8')
(dest/'Harness.qml').write_text('''import QtQuick 2.3
Item {
id: harness; width:480; height:800
property int lastSeek: -1
property int pressCalls: 0
property int endedCalls: 0
property int previousClicks: 0
property int playClicks: 0
property int nextClicks: 0
property int previousHolds: 0
property int nextHolds: 0
property int shuffleClicks: 0
property int repeatClicks: 0
StandardPlayer {
    id: player; objectName:"player"; anchors.fill: parent
    meta_data: ({play_title:"Eyes Without a Face",artist_name:"Billy Idol",album_name:"Rebel Yell",is_high_resolution:false,lyrics_status:0})
    total_playback_time:300000; currently_playing_time:24000
    currentry_playtrack_num:5; total_playtrack_num:8
    onReleased: harness.lastSeek=time
    onPressed: harness.pressCalls++
    onPlayEnded: harness.endedCalls++
}
PlayerMetaDataArea { objectName:"legacyMeta"; visible:false }
BasicPlayerControls {
    objectName:"controls"; y:600
    properties: ({objectName:"controls",dispMode:1,playTitle:"Test track",playState:false,playerButtonEnabled:true,shuffleState:false,shuffleVisible:true,repeatModeState:0,repeatModeVisible:true})
    onPrevButtonClicked: harness.previousClicks++
    onPlayButtonClicked: harness.playClicks++
    onNextButtonClicked: harness.nextClicks++
    onShuffleButtonClicked: harness.shuffleClicks++
    onRepeatButtonClicked: harness.repeatClicks++
    onPrevButtonLongPressed: harness.previousHolds++
    onNextButtonLongPressed: harness.nextHolds++
}
}
''',encoding='utf-8')
print('Prepared actual patched Sony standard player, metadata and scrub components; unchanged firmware widgets stubbed')
off=0x60eaae;n=int.from_bytes(binary[off:off+4],'big')
menu=binary[off+4:off+4+n].decode('utf-8')
icon=re.search(r'coverIcon:go\?"(data:image/png;base64,[^"]+)"',menu).group(1)
harness=dest/'Harness.qml'
text=harness.read_text(encoding='utf-8').rstrip()
assert text.endswith('}')
harness.write_text(text[:-1]+'Image { objectName:"gotoIcon"; visible:false; source:"'+icon+'" }\n}\n',encoding='utf-8')

# Replace the old marquee stub with the actual opt-in Sony resource.
off=0x61f1db;n=int.from_bytes(binary[off:off+4],'big')
marquee=binary[off+4:off+4+n].decode('utf-8')
marquee=marquee.replace('"qrc:/parts"','"."').replace('file:///system/vendor/sony-peq/ui/ContinuousTitle.qml',(dest/'ContinuousTitle.qml').as_uri())
(dest/'parts/SCmnMarquee.qml').write_text(marquee,encoding='utf-8')
(dest/'parts/SCmnLabel.qml').write_text('import QtQuick 2.3\nText {}\n',encoding='utf-8')
loop=(HERE/'source/ContinuousTitle.qml').read_text(encoding='utf-8').replace('"qrc:/parts"','"./parts"').replace('file:///sys/class/leds/lcd-backlight/brightness',(dest/'brightness.txt').as_uri())
(dest/'ContinuousTitle.qml').write_text(loop,encoding='utf-8')
(dest/'brightness.txt').write_text('17\n',encoding='utf-8')
# A missing optional file must leave the original Sony text available.
failure=marquee.replace((dest/'ContinuousTitle.qml').as_uri(),(dest/'missing-title.qml').as_uri())
(dest/'parts/FailureMarquee.qml').write_text(failure,encoding='utf-8')
harness=dest/'Harness.qml';text=harness.read_text(encoding='utf-8').rstrip()
text=text.replace('import QtQuick 2.3','import QtQuick 2.3\nimport "./parts" as RecoveryTest',1)
text=text[:-1]+'''RecoveryTest.FailureMarquee {
objectName:"fallbackTitle"; x:800; width:200; height:43
continuous:true; isUseMarquee:true
Component.onCompleted: setMainText("This long title keeps the native Sony fallback")
}
}
'''
harness.write_text(text,encoding='utf-8')
