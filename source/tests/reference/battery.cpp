#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QTemporaryDir>
#include <QFile>
#include <QImage>
#include <QColor>
#include <QElapsedTimer>
#include <QThread>
#include <QUrl>
#include <QVariant>
#include <cstdio>
#include <cstdlib>
#include <memory>

static void check(bool ok,const char*label){if(!ok){fprintf(stderr,"FAIL battery: %s\n",label);std::abort();}}
template<class F> static void until(F condition){QElapsedTimer t;t.start();while(!condition()&&t.elapsed()<4500){QCoreApplication::processEvents();QThread::msleep(3);}check(condition(),"async operation completed");}
static void events(int ms){QElapsedTimer t;t.start();while(t.elapsed()<ms){QCoreApplication::processEvents();QThread::msleep(3);}}
static void write(const QString&path,const QByteArray&data){QFile f(path);check(f.open(QIODevice::WriteOnly),"fixture open");check(f.write(data)==data.size(),"fixture write");}
static QObject*create(QQmlEngine&engine,const QString&path,const QVariantMap&properties={}){
 QQmlComponent c(&engine,QUrl::fromLocalFile(path));check(c.isReady(),qPrintable(c.errorString()));
 QObject*o=c.beginCreate(engine.rootContext());check(o,"object created");
 for(auto i=properties.begin();i!=properties.end();++i)check(o->setProperty(i.key().toUtf8(),i.value()),"initial property");
 c.completeCreate();check(!c.isError(),qPrintable(c.errorString()));return o;
}
static QObject*child(QObject*o,const char*name){auto*c=o->findChild<QObject*>(name);check(c,name);return c;}
int main(int argc,char**argv){
 QGuiApplication app(argc,argv);check(argc==2,"source directory supplied");
 QString source=QString::fromLocal8Bit(argv[1]);QTemporaryDir temp;check(temp.isValid(),"temporary directory");
 QString cap=temp.path()+"/capacity",status=temp.path()+"/status",brightness=temp.path()+"/brightness";
 auto url=[](const QString&p){return QUrl::fromLocalFile(p).toString();};
 write(cap,"75\n");write(status,"Charging\n");write(brightness,"100\n");
 QQmlEngine engine;
 std::unique_ptr<QObject> state(create(engine,source+"/BatteryState.qml",{{"capacityUrl",url(cap)},{"statusUrl",url(status)},{"brightnessUrl",url(brightness)},{"voltageUrl",url(cap)},{"usbOnlineUrl",url(brightness)},{"diagnosticUrl",url(temp.path()+"/battery.json")}}));
 check(!state->property("displayPollRunning").toBool()&&!state->property("refreshRunning").toBool(),"no polls without visible consumer");
 engine.rootContext()->setContextProperty("patchmanBattery",state.get());
 QImage image(40,24,QImage::Format_ARGB32);image.fill(Qt::white);
 for(const auto&name:{"stat_sys_battery_level_2.png","stat_sys_battery_error_temperature.png","stat_notify_hold.png"})check(image.save(temp.path()+"/"+name),"native fixture image");
 std::unique_ptr<QObject> icon(create(engine,source+"/NativeBatteryIcon.qml",{{"imagePath",url(temp.path())+"/"},{"animationImage","stat_sys_battery_level_2.png"},{"batteryModel",QVariant::fromValue(state.get())}}));
 until([&](){return state->property("available").toBool()&&state->property("screenOn").toBool();});
 until([&](){return icon->findChild<QObject*>("batteryHalfRing")!=nullptr;});
 auto*indicator=child(icon.get(),"patchmanBatteryIndicator");
 check(indicator->property("batteryModel").value<QObject*>()==state.get(),"shared model resolved from root context");
 check(state->property("percent").toInt()==75&&state->property("charging").toBool(),"actual capacity and Charging parsed");
 check(child(icon.get(),"batteryChargingBolt")->property("visible").toBool(),"charging bolt shown left of battery");
 check(!child(icon.get(),"nativeStatusIcon")->property("visible").toBool(),"native icon replaced only after valid reading");
 check(child(icon.get(),"batteryPercentText")->property("text").toString()=="75%","reported percentage remains fixed");
 check(child(icon.get(),"batteryFullLabel")->property("text").toString().isEmpty(),"no FULL while charging");
 events(120);
 check(!indicator->property("animating").toBool(),"half-ring does not run an animated fill");
 check(!icon->findChild<QObject*>("batteryWhiteFill")&&!icon->findChild<QObject*>("batteryTextClip"),"no fill or inverted percentage layer");
 check(child(icon.get(),"batteryPercentText")->property("color").value<QColor>()==QColor(Qt::white),"percentage remains white");
 auto reload=[&](const QByteArray&p,const QByteArray&s){
  write(cap,p);write(status,s);QMetaObject::invokeMethod(state.get(),"reload");
  until([&](){return !state->property("reading").toBool();});
 };
 reload("90\n","Full\n");
 check(state->property("full").toBool()&&!state->property("charging").toBool(),"Full comes from status, not 100 threshold");
 check(child(icon.get(),"batteryPercentText")->property("text").toString()=="90%","Battery Care data never rescaled to 100");
 check(child(icon.get(),"batteryFullLabel")->property("text").toString()=="FULL","system Full label");
 check(!indicator->property("animating").toBool(),"Full stops animation");
 check(!child(icon.get(),"batteryChargingBolt")->property("visible").toBool(),"Full hides charging bolt");
 reload("100\n","Discharging\n");check(!state->property("full").toBool(),"100 percent alone is not Full");
 reload("75\n","Not charging\n");check(!indicator->property("animating").toBool()&&!state->property("full").toBool(),"Not charging is neither charging nor full");
 reload("75\n","Charging\n");write(brightness,"0\n");QMetaObject::invokeMethod(state.get(),"readBrightness");
 until([&](){return !state->property("brightnessPending").toBool();});
 check(!state->property("screenOn").toBool()&&!indicator->property("animating").toBool(),"screen-off stops animation");
 check(!state->property("refreshRunning").toBool(),"screen-off stops percent polling");
 // Linux virtual files report size 0. Verify real XMLHttpRequest reads them.
 state->setProperty("brightnessUrl",url("/proc/sys/kernel/pid_max"));QMetaObject::invokeMethod(state.get(),"readBrightness");
 until([&](){return !state->property("brightnessPending").toBool();});check(state->property("screenOn").toBool(),"zero-size proc file read through real Qt file backend");
 until([&](){return !state->property("reading").toBool();});
 reload("999\n","Full\n");check(!state->property("available").toBool(),"invalid capacity rejected");
 check(child(icon.get(),"nativeStatusIcon")->property("visible").toBool(),"failed reading restores Sony icon");
 reload("75\n","Invented state\n");check(!state->property("available").toBool(),"unknown status spelling rejected");
 reload("0\n","Discharging\n");check(state->property("available").toBool()&&state->property("percent").toInt()==0,"zero is valid");
 icon->setProperty("animationImage","stat_sys_battery_error_temperature.png");events(30);
 check(!icon->property("nativeBattery").toBool()&&child(icon.get(),"nativeStatusIcon")->property("visible").toBool(),"Sony temperature warning kept");
 until([&](){return state->property("consumers").toInt()==0;});
 check(!state->property("displayPollRunning").toBool(),"no polling for warning/non-battery icons");
 icon->setProperty("animationImage","stat_notify_hold.png");events(20);check(!icon->property("nativeBattery").toBool(),"HOLD icon untouched");
 icon->setProperty("animationImage","stat_sys_battery_level_2.png");until([&](){return state->property("consumers").toInt()==1;});
 icon->setProperty("visible",false);events(20);check(state->property("consumers").toInt()==0,"hidden cached screen releases consumer");
 check(!state->property("displayPollRunning").toBool()&&!state->property("refreshRunning").toBool(),"hidden cached screen stops all polling");
 events(2100);
 QFile diagnostic(temp.path()+"/battery.json");check(diagnostic.open(QIODevice::ReadOnly),"diagnostic JSON written");
 QByteArray saved=diagnostic.readAll();check(saved.contains("topbar-balanced-3")&&saved.contains("capacityRaw")&&saved.contains("nativeIcon")&&saved.size()<32769,"bounded diagnostic contains raw readings and native image");
 icon.reset();events(10);check(state->property("consumers").toInt()==0,"destruction balances registration");
 puts("PASS battery QML: real file and proc reads, shared native icon hook, reported percent/Full/Charging, no forced 90/100, native warning/failure fallback, left terminal, clipped text, bounded layout, screen-off and hidden lifecycle");
}
