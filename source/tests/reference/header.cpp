#include <QGuiApplication>
#include <QFont>
#include <QFontMetrics>
#include <QQmlEngine>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQuickItem>
#include <QQuickWindow>
#include <QQuickItemGrabResult>
#include <QAbstractListModel>
#include <QVariant>
#include <QImage>
#include <QFile>
#include <QDir>
#include <QUrl>
#include <QThread>
#include <QElapsedTimer>
#include <QSet>
#include <functional>
#include <memory>
#include <cstdio>
#include <cstdlib>

static void check(bool ok,const char*s){if(!ok){fprintf(stderr,"FAIL compact header: %s\n",s);std::abort();}}
template<class F>static void until(F f){QElapsedTimer t;t.start();while(!f()&&t.elapsed()<4500){QCoreApplication::processEvents();QThread::msleep(3);}check(f(),"asynchronous operation completes");}
static void events(){for(int i=0;i<15;i++){QCoreApplication::processEvents();QThread::msleep(3);}}
// Repeater delegates have a visual parent distinct from QObject ownership.
// Search both trees; testing only findChild() can miss a visible native icon.
static QList<QObject*> descendants(QObject*root,const QString&name){
 QList<QObject*>result;QSet<QObject*>seen;
 std::function<void(QObject*)>visit=[&](QObject*o){
  if(!o||seen.contains(o)) {
   return;
  }
  seen.insert(o);
  if(o->objectName()==name)result.append(o);
  if(auto*i=qobject_cast<QQuickItem*>(o))for(auto*c:i->childItems())visit(c);
  for(auto*c:o->children())visit(c);
 };
 visit(root);return result;
}
static QObject*find(QObject*o,const char*name){auto list=descendants(o,QString::fromLatin1(name));return list.isEmpty()?nullptr:list.first();}
static QObject*child(QObject*o,const char*name){auto*p=find(o,name);check(p,name);return p;}
static QQuickItem*item(QObject*o,const char*name){auto*p=qobject_cast<QQuickItem*>(child(o,name));check(p,name);return p;}
static QObject*create(QQmlEngine&e,const QString&path,const QVariantMap&props={}){
 QQmlComponent c(&e,QUrl::fromLocalFile(path));check(c.isReady(),qPrintable(c.errorString()));QObject*o=c.beginCreate(e.rootContext());check(o,"component created");
 for(auto i=props.begin();i!=props.end();++i)check(o->setProperty(i.key().toUtf8(),i.value()),"declared native-compatible property");
 c.completeCreate();check(!c.isError(),qPrintable(c.errorString()));return o;
}
static void write(const QString&p,const QByteArray&b){QFile f(p);check(f.open(QIODevice::WriteOnly),"fixture file");check(f.write(b)==b.size(),"fixture bytes");}
class Icons:public QAbstractListModel{
public:
 enum{Type=Qt::UserRole+1,Frame,Name,Param};
 struct Row{int type,frame;QString name;};
 QList<Row>rows={{1,20,"stat_notify_audio_track_play.png"},{0,300,""},{1,24,"stat_sys_bluetooth.png"},{1,24,"stat_sys_nfc.png"},{1,40,"stat_sys_battery_level_2.png"}};
 int rowCount(const QModelIndex&p=QModelIndex())const override{return p.isValid()?0:rows.size();}
 QVariant data(const QModelIndex&i,int role)const override{if(!i.isValid()||i.row()<0||i.row()>=rows.size())return {};const auto&r=rows[i.row()];switch(role){case Type:return r.type;case Frame:return r.frame;case Name:return r.name;case Param:return QVariantList{0,75,false,false};default:return {};}}
 QHash<int,QByteArray>roleNames()const override{return {{Type,"QmlIntRole"},{Frame,"ParamIntFrameSize"},{Name,"ParamAnimationImageRole"},{Param,"ParamQvariantRole"}};}
 void wireless(bool bt,bool nfc){rows[2].frame=bt?24:0;rows[3].frame=nfc?24:0;emit dataChanged(index(2),index(3));}
 void playbackIcon(const QString&name){rows[0].name=name;emit dataChanged(index(0),index(0));}
};
int main(int argc,char**argv){
 QGuiApplication app(argc,argv);check(argc==2,"header fixture supplied");
 QString root=QString::fromLocal8Bit(argv[1]);QString assets=root+"/assets/";
 QImage png(24,20,QImage::Format_ARGB32);png.fill(Qt::white);
 for(const char*name:{"stat_notify_hold_on.png","stat_sys_battery_level_2.png","stat_notify_volume.png","ic_volumebar_input_balance_high.png","ic_volumebar_volume_plus.png","ic_volumebar_volume_minus.png","ic_volumebar_input_balance.png","ic_volumebar_output_bluetooth.png","ic_volumebar_output_usb_audio.png"})check(png.save(assets+name),"native icon fixture");
 write(root+"/capacity","75\n");write(root+"/status","Discharging\n");write(root+"/brightness","100\n");
 Icons icons;QQmlEngine engine;QQuickWindow window;window.setGeometry(0,0,480,800);window.show();
 engine.rootContext()->setContextProperty("viewstyle",QVariantMap{{"bgcolor",QVariantMap{{"D1","black"}}},{"textsize",QVariantMap{{"S",18},{"SS",20}}},{"textcolor",QVariantMap{{"L1","white"},{"Y1","yellow"}}},{"font_family","DejaVu Sans"}});
 engine.rootContext()->setContextProperty("screenController",QVariantMap{{"screenID","MusicPlayer"}});
 QVariantMap properties={{"objectName","headerArea"},{"useVolumeArea",true},{"visibleVolumeArea",true},{"volume",30},{"maxVolume",120},{"volumeDisplayType","Numeric"},{"soundQualityText","FLAC 44.1 kHz / 16 bit"},{"outputType","HeadPhone"},{"isEnableVolumeBarMouseArea",true},{"stateIconList",QVariant::fromValue(static_cast<QObject*>(&icons))},{"isEnableStatusBarMouseArea",true}};
 std::unique_ptr<QObject>header(create(engine,root+"/HeaderArea.qml",{{"properties",properties}}));
 auto*visual=qobject_cast<QQuickItem*>(header.get());check(visual,"native header visual root");visual->setParentItem(window.contentItem());
 until([&](){return find(header.get(),"batteryHalfRing")!=nullptr;});
 auto*cluster=item(header.get(),"compactStatusCluster");auto*state=cluster->property("batteryModel").value<QObject*>();
 until([&](){return state->property("available").toBool();});events();
 auto*ring=item(cluster,"batteryHalfRing");auto*percent=item(cluster,"batteryPercentText");
 auto*volume=item(cluster,"compactVolume");auto*format=item(header.get(),"soundQuality");
 auto*indicator=child(cluster,"patchmanBatteryIndicator");
 auto bounds=[&](){
  auto end=cluster->mapToItem(visual,QPointF(cluster->width(),0));
  auto start=cluster->mapToItem(visual,QPointF(0,0));
  auto formatEnd=format->mapToItem(visual,QPointF(format->width(),0));
  check(qAbs(end.x()-468)<0.01,"right group keeps native 12px inset");
  check(format->x()==12&&formatEnd.x()+7.9<=start.x(),"format and right group do not overlap");
  auto percentEnd=percent->mapToItem(visual,QPointF(percent->width(),0));
  check(qAbs(percentEnd.x()-468)<0.01,"percentage right-aligned at original inset");
  auto ringStart=ring->mapToItem(cluster,QPointF(0,0));
  auto volumeEnd=volume->mapToItem(cluster,QPointF(volume->width(),0));
  check(ringStart.x()>=volumeEnd.x()+7.9,"battery remains after volume with spacing");
  auto ringEnd=ring->mapToItem(cluster,QPointF(ring->width(),ring->height()/2));
  auto percentStart=percent->mapToItem(cluster,QPointF(0,percent->height()/2));
  check(qAbs(percentStart.x()-ringEnd.x()-4)<0.01,"4px gap between arc and number");
  check(qAbs(percentStart.y()-ringEnd.y())<0.01,"arc and percentage vertically centered");
  auto a=percent->property("font").value<QFont>();auto b=child(cluster,"compactVolumeText")->property("font").value<QFont>();
  check(a.pixelSize()==b.pixelSize()&&a.weight()==b.weight()&&a.family()==b.family(),"percentage font matches volume");
  check(percent->width()+1>=QFontMetrics(a).boundingRect(percent->property("text").toString()).width(),"100 percent fits without clipping");
  check(percent->property("color").value<QColor>()==QColor(Qt::white),"percentage always white");
  check(!find(cluster,"batteryWhiteFill")&&!find(cluster,"batteryTextClip"),"no rectangular fill or inverted digits");
  check(visual->width()==480&&visual->height()==66,"original header allocation retained");
 };
 for(int bt=0;bt<2;++bt){
  for(int nfc=0;nfc<2;++nfc){
   icons.wireless(bt,nfc);
   for(const char*status:{"Discharging","Charging","Full"}){
    write(root+"/status",QByteArray(status)+"\n");
    state->setProperty("chargeStatus",status);
    for(int p:{0,9,50,99,100}){
     write(root+"/capacity",QByteArray::number(p)+"\n");
     state->setProperty("percent",p);
     for(int v:{0,30,99,100,120}){
      properties["volume"]=v;header->setProperty("properties",properties);events();bounds();
      check(child(cluster,"compactVolumeText")->property("text").toString()==QString::number(v),"volume remains unpadded");
     }
     bool full=QString::fromLatin1(status)=="Full";
     check(qAbs(indicator->property("arcFraction").toDouble()-(full?1.0:p/100.0))<0.001,"arc fraction follows remaining charge");
     check(item(cluster,"batteryChargingBolt")->isVisible()==(QString::fromLatin1(status)=="Charging"),"bolt only while charging");
     check(child(cluster,"batteryFullLabel")->property("text").toString()==(full?"FULL":""),"FULL only on Sony Full signal");
    }
   }
  }
 }
 state->setProperty("chargeStatus","Full");state->setProperty("percent",90);events();bounds();
 check(percent->property("text").toString()=="90%","Battery Care Full keeps raw 90 percent");
 write(root+"/status","Discharging\n");write(root+"/capacity","50\n");
 state->setProperty("chargeStatus","Discharging");state->setProperty("percent",50);events();
 // Inspect the actual painted arc: the lower half is white and upper half dim.
 auto grab=ring->grabToImage();check(bool(grab),"arc can be captured");
 until([&](){return !grab->image().isNull();});
 auto image=grab->image();int upper=0,lower=0;
 for(int y=0;y<image.height();++y){
  for(int x=0;x<image.width();++x){
   auto c=image.pixelColor(x,y);
   if(c.alpha()>80&&c.red()>180){if(y<image.height()/2-1)++upper;if(y>image.height()/2+1)++lower;}
  }
 }
 check(lower>3&&upper==0,"50 percent paints lower arc white and upper arc dim");
 state->setProperty("available",false);events();
 check(item(cluster,"nativeStatusIcon")->isVisible(),"unknown battery keeps Sony fallback");
 puts("PASS half-ring header: actual shared header, 100 percent and 120 volume, all wireless/charging/Full combinations, matching fonts, right inset, arc direction and native fallback");
}
