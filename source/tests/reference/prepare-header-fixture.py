import pathlib,sys
HERE=pathlib.Path(__file__).resolve().parent.parent
PROJECT=HERE.parent.parent;WORK=PROJECT/'work/Patchman-v1.5.1'
dest=pathlib.Path(sys.argv[1]).resolve();dest.mkdir(parents=True,exist_ok=True)
for folder in ('assets','parts','icon'):(dest/folder).mkdir(exist_ok=True)
def transform(s):
    s=s.replace('"qrc:/parts"','"./parts"').replace('"qrc:/components/icon"','"."')
    s=s.replace('file:///system/vendor/sony-peq/ui/topbar/RightCluster.qml',(dest/'RightCluster.qml').as_uri())
    s=s.replace('qrc:/assets/images/',(dest/'assets').as_uri()+'/')
    for name in ('capacity','status','brightness'):
        original={'capacity':'/sys/class/power_supply/battery/capacity','status':'/sys/class/power_supply/battery/status','brightness':'/sys/class/leds/lcd-backlight/brightness'}[name]
        s=s.replace('file://'+original,(dest/name).as_uri())
    s=s.replace('file:///data/sony-peq/runtime/battery-diagnostic.json','')
    return s
for p in (HERE/'source/topbar').iterdir():(dest/p.name).write_bytes(transform(p.read_text(encoding='utf-8')).encode())
for name,offset in [('VolumeArea',0x5fefd6),('HeaderArea',0x5eff13),('StatusBar',0x5e7b36)]:
    s=transform((WORK/('%x.qml'%offset)).read_text(encoding='utf-8'))
    for identifier in ('soundQuality','volumeValueText','volumeIcon','stateBar'):
        s=s.replace('id: '+identifier+'\n','id: '+identifier+'\nobjectName: "'+identifier+'"\n')
        s=s.replace('id:'+identifier+'\n','id:'+identifier+'\nobjectName: "'+identifier+'"\n')
    (dest/(name+'.qml')).write_bytes(s.encode())
original=PROJECT/'work/walkman-one/resources'
status_icon=(WORK/'610c5c.qml').read_text(encoding='utf-8')
status_icon=status_icon.replace('property var animationImage','objectName: "commonNativeStatusIcon"\nproperty var animationImage')
(dest/'icon/StatusIcon.qml').write_bytes(transform(status_icon).encode())
(dest/'StatusVolumeBar.qml').write_text('import QtQuick 2.0\nItem { signal statusBarClicked() }\n',encoding='utf-8')
stubs={
 'VolumeBar.qml':'Item { property int maxValue; property int currentValue; property bool visibleAvlsMark; property int avlsVolumeMax; property bool isAvlsOn; height:8 }',
 'ClickArea.qml':'MouseArea { property bool pressedButton: pressed }',
 'SCmnLabel.qml':'Text {}', 'SCmnMonospaceLabel.qml':'Text {}'}
for name,s in stubs.items():(dest/'parts'/name).write_text('import QtQuick 2.0\n'+s+'\n',encoding='utf-8')
print('Prepared actual native HeaderArea/VolumeArea/StatusBar and optional topbar components')

# Use the actual Sony alpha-padded icons, not rectangular test placeholders.
for p in (HERE/"tests/native-icons").glob("*.png"):
    (dest/"assets"/p.name).write_bytes(p.read_bytes())
