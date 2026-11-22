#include <QGuiApplication>
#include <QQmlEngine>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQuickItem>
#include <QQuickWindow>
#include <QVariant>
#include <QImage>
#include <QFile>
#include <QThread>
#include <QUrl>
#include <memory>
#include <cstdio>
#include <cstdlib>
static void check(bool ok,const char*s){if(!ok){fprintf(stderr,"FAIL player spacing: %s\n",s);std::abort();}}
static void events(){for(int i=0;i<20;i++){QCoreApplication::processEvents();QThread::msleep(3);}}
static QQuickItem*find(QQuickItem*root,const char*name){
 if(root->objectName()==QString::fromLatin1(name))return root;
 for(auto*c:root->childItems()){if(auto*r=find(c,name))return r;}
 return nullptr;
}
static QQuickItem*item(QQuickItem*root,const char*name){auto*r=find(root,name);check(r,name);return r;}
int main(int argc,char**argv){
 QGuiApplication app(argc,argv);check(argc==2,"fixture supplied");QString path=QString::fromLocal8Bit(argv[1]);
 QImage image(40,28,QImage::Format_ARGB32);image.fill(Qt::white);
 check(image.save(path+"/assets/ic_audio_play_lyrics_mark.png"),"lyrics fixture");
 check(image.save(path+"/assets/ic_audio_play_hr_mark.png"),"HiRes fixture");
 QImage button(110,110,QImage::Format_ARGB32);button.fill(Qt::white);
 for(const char*name:{"previous_track","play","pause","next_track"}){
  for(const char*state:{"normal","pressed","disabled"}){
   check(button.save(path+"/assets/btn_audio_"+name+"_"+state+".png"),"button image fixture");
  }
 }
 QImage panel(480,147,QImage::Format_ARGB32);panel.fill(Qt::black);
 check(panel.save(path+"/assets/panel_controller_background.png"),"mini-player panel fixture");
 QImage shuffleImage(65,110,QImage::Format_ARGB32);shuffleImage.fill(Qt::white);
 for(const char*prefix:{"","hp_amp_"}){
  for(const char*enabled:{"on","off"}){
   for(const char*pressed:{"normal","pressed"}){
    check(shuffleImage.save(path+"/assets/btn_audio_play_"+prefix+"shuffle_"+enabled+"_"+pressed+".png"),"legacy simple-mode shuffle fixture");
   }
  }
  for(const char*mode:{"off","current","all"}){
   for(const char*state:{"normal","pressed"}){
    check(shuffleImage.save(path+"/assets/btn_audio_play_"+prefix+"repeat_"+mode+"_"+state+".png"),"legacy simple-mode repeat fixture");
   }
  }
 }
 QQmlEngine engine;QQuickWindow window;window.setGeometry(0,0,480,800);window.show();
 engine.rootContext()->setContextProperty("viewstyle",QVariantMap{{"bgcolor",QVariantMap{{"D1","black"}}},{"mode","normal"},{"empty_string",""},{"textsize",QVariantMap{{"L",28},{"M",24}}},{"textcolor",QVariantMap{{"L1","white"},{"L2","#ccc"},{"L3","#aaa"}}}});
 QQmlComponent c(&engine,QUrl::fromLocalFile(path+"/Harness.qml"));check(c.isReady(),qPrintable(c.errorString()));
 std::unique_ptr<QObject>object(c.create());check(object&&!c.isError(),qPrintable(c.errorString()));
 auto*root=qobject_cast<QQuickItem*>(object.get());check(root,"fixture visual root");root->setParentItem(window.contentItem());events();
 auto*gotoIcon=item(root,"gotoIcon");
 check(gotoIcon->property("status").toInt()==1,"Qt decodes the exact embedded Go to PNG");
 check(gotoIcon->implicitWidth()==66&&gotoIcon->implicitHeight()==88,"Go to PNG uses native menu icon allocation");
 auto*player=item(root,"player");auto*title=item(player,"labelTitle");auto*artist=item(player,"labelArtist");auto*album=item(player,"labelAlbum");
 auto*meta=title->parentItem();auto*cover=item(player,"cover");auto*scrub=item(player,"scrub");auto*slider=item(player,"scrubBarSlider");
 check(meta->property("compactMetadata").toBool(),"standard player explicitly activates native layout");
 check(meta->height()==179&&meta->y()==408,"metadata allocation and control boundary unchanged");
 check(cover->x()==40&&cover->y()==8&&cover->width()==400&&cover->height()==400,"cover position and size unchanged");
 check(!album->isVisible()&&album->height()==0,"album row removed from standard Now Playing");
 check(title->property("pixelSize").toInt()==30,"Now Playing title is 30 pixels");
 check(title->y()==77&&title->height()==43&&artist->y()==125&&artist->height()==37,"native title/artist sizes retained with balanced gaps");
 check(artist->y()-title->y()-title->height()==5,"title-to-artist breathing room");
 check(meta->height()-artist->y()-artist->height()==17,"bottom inset retained before controls");
 check(scrub->property("labelToTrackGap").toInt()==12,"time labels and seek line separated");
 auto*timeArea=item(player,"currentlyPlayingTimeTextArea");
 check(qAbs(slider->parentItem()->y()-timeArea->y()-timeArea->height()-12)<0.01,"actual native scrub anchor uses increased gap");
 check(scrub->mapToItem(meta,QPointF(0,0)).y()==24,"time row has room below cover");
 auto*legacy=item(root,"legacyMeta");
 check(!legacy->property("compactMetadata").toBool()&&legacy->height()==179,"other player modes retain original allocation");
 check(item(legacy,"labelTitle")->property("pixelSize").toInt()==34,"other playback layouts keep native title size");
 check(item(legacy,"labelAlbum")->height()==37,"other player modes keep album row");
 check(item(legacy,"scrub")->property("labelToTrackGap").toInt()==4,"other timeline users keep Sony gap");
 QVariantMap data={{"play_title","A very long song title remains on the original Sony marquee"},{"artist_name","Billy Idol"},{"album_name","Rebel Yell"},{"is_high_resolution",true},{"lyrics_status",2}};
 player->setProperty("meta_data",data);events();
 check(item(title,"native_centerText")->property("text").toString()==data["play_title"].toString(),"title metadata binding retained");
 check(artist->width()==372&&item(player,"lyricsImage")->isVisible()&&item(player,"hiResIcon")->isVisible(),"lyrics and HiRes move beside artist without overlap");
 for(const char*name:{"lyricsImage","hiResIcon"}){
  auto*i=item(player,name);check(i->y()==artist->y()&&i->x()>=0&&i->x()+i->width()<=480,"native badges remain inside panel");
 }
 slider->setProperty("sliderHoldingPressed",true);events();
 check(qAbs(slider->parentItem()->y()-timeArea->height()-11)<0.01,"pressed gap keeps Sony one-pixel adjustment");
 QMetaObject::invokeMethod(slider,"pressed");
 check(root->property("pressCalls").toInt()==1,"press signal reaches native player");
 slider->setProperty("value",73000);QMetaObject::invokeMethod(slider,"released");
 check(root->property("lastSeek").toInt()==73000,"seek time reaches native player unchanged");
 slider->setProperty("sliderHoldingPressed",false);player->setProperty("currently_playing_time",42000);events();
 check(slider->property("value").toInt()==42000,"playback time updates native seek position");
 check(meta->height()==179&&cover->y()==8,"interaction leaves page geometry stable");
 auto*controls=item(root,"controls");
 QVariantMap controlProps=controls->property("properties").toMap();
 const char*names[]={"previousControl","playControlButton","nextControl"};
 for(int mode:{1,0}){
  controlProps["dispMode"]=mode;controls->setProperty("properties",controlProps);events();
  check(controls->height()==(mode==1?110:147),"control allocation and mini-player panel stay native");
  for(int i=0;i<3;++i){
   auto*b=item(controls,names[i]);
   check(b->width()==110&&b->height()==110,"original button hit target remains 110 square");
   double expected=i==1?0.86:0.90;
   for(int state:{0,1,2}){
    b->setProperty("enable",state!=2);b->setProperty("visualState",state==1?1:0);events();
    auto*visual=item(b,"controlVisual");
    check(qAbs(visual->scale()-expected)<0.001,"normal, pressed and disabled images use same centered scale");
    auto rectangle=visual->mapRectToItem(b,QRectF(0,0,visual->width(),visual->height()));
    check(qAbs(rectangle.center().x()-55)<0.01&&qAbs(rectangle.center().y()-55)<0.01,"visual remains centered in original hit area");
    check(qAbs(rectangle.width()-110*expected)<0.01&&rectangle.top()>=-0.01&&rectangle.bottom()<=110.01,"smaller visible control has symmetric breathing room");
   }
   b->setProperty("enable",true);b->setProperty("visualState",0);
  }
 }
 controlProps["dispMode"]=1;controls->setProperty("properties",controlProps);events();
 QMetaObject::invokeMethod(item(controls,"previousControl"),"clicked");
 QMetaObject::invokeMethod(item(controls,"playControlButton"),"clicked");
 QMetaObject::invokeMethod(item(controls,"nextControl"),"clicked");
 QMetaObject::invokeMethod(item(controls,"previousControl"),"pressAndHold");
 QMetaObject::invokeMethod(item(controls,"nextControl"),"pressAndHold");
 check(root->property("previousClicks").toInt()==1&&root->property("playClicks").toInt()==1&&root->property("nextClicks").toInt()==1,"native transport click signals retained");
 check(root->property("previousHolds").toInt()==1&&root->property("nextHolds").toInt()==1,"native hold-to-seek signals retained");
 auto*shuffle=item(controls,"nativeShuffle");
 check(shuffle->width()==65&&shuffle->height()==110,"shuffle input target keeps its native size");
 QMetaObject::invokeMethod(shuffle,"clicked");
 check(root->property("shuffleClicks").toInt()==1,"shuffle click follows unchanged native control signal");
 check(!shuffle->property("is_shuffle").toBool(),"button does not invent state before native confirmation");
 for(bool simple:{false,true}){
  shuffle->setProperty("is_simple_mode",simple);
  for(bool on:{false,true}){
   controlProps["shuffleState"]=on;controls->setProperty("properties",controlProps);events();
   check(shuffle->property("is_shuffle").toBool()==on,"native properties still control shuffle state");
   QString stem=QString("btn_audio_play_")+(simple?"hp_amp_":"")+"shuffle_"+(on?"on":"off");
   check(shuffle->property("load_image_source").toString().endsWith(stem+"_normal.png"),"normal/native fallback asset mapping preserved");
   check(shuffle->property("pressed_image_source").toString().endsWith(stem+"_pressed.png"),"pressed/simple-mode fallback asset mapping preserved");
  }
 }
 auto*repeat=item(controls,"nativeRepeat");
 check(repeat->width()==65&&repeat->height()==110,"repeat input target keeps its native size");
 QMetaObject::invokeMethod(repeat,"clicked");
 check(root->property("repeatClicks").toInt()==1,"repeat click follows unchanged native control signal");
 check(repeat->property("repeat_mode").toInt()==0,"repeat waits for native state confirmation");
 const char*repeatNames[]={"off","current","all"};
 for(bool simple:{false,true}){
  repeat->setProperty("is_simple_mode",simple);
  for(int mode:{0,1,2}){
   controlProps["repeatModeState"]=mode;controls->setProperty("properties",controlProps);events();
   check(repeat->property("repeat_mode").toInt()==mode,"native properties control all three repeat modes");
   QString stem=QString("btn_audio_play_")+(simple?"hp_amp_":"")+"repeat_"+repeatNames[mode];
   check(repeat->property("load_image_source").toString().endsWith(stem+"_normal.png"),"repeat normal and simple-mode asset mapping retained");
   check(repeat->property("pressed_image_source").toString().endsWith(stem+"_pressed.png"),"repeat pressed asset mapping retained");
  }
 }
 controlProps["repeatModeState"]=3;controls->setProperty("properties",controlProps);events();
 check(repeat->property("load_image_source").toString().isEmpty()&&repeat->property("pressed_image_source").toString().isEmpty(),"unsupported repeat state stays empty");

 meta->setProperty("isTitleMarquee",true);events();
 check(!find(title,"continuousTitle"),"Now Playing does not load the continuous loop");
 auto checkShort=[&](QQuickItem*host,const QString&expected){
  auto*center=item(host,"native_centerText");
  check(center->isVisible()&&center->property("text").toString()==expected,"short title visible in original Sony centered label");
  check(!host->findChild<QObject*>("native_marqueeScroll")->property("running").toBool(),"original scrolling stops for short title");
  check(!host->findChild<QObject*>("native_fixingTime")->property("running").toBool(),"original delay stops for short title");
 };
 auto settle=[&](int ms){for(int i=0;i<ms/10;++i){QCoreApplication::processEvents();QThread::msleep(10);}};
 for(int cycle=0;cycle<2;++cycle){
  data["play_title"]="A very long song title for the original Sony scrolling behavior before a short song follows";
  player->setProperty("meta_data",data);events();settle(2600);
  check(title->findChild<QObject*>("native_marqueeScroll")->property("running").toBool(),"native full-player marquee starts after its original delay");
  data["play_title"]="Next";player->setProperty("meta_data",data);events();checkShort(title,"Next");
  settle(300);checkShort(title,"Next");
 }
 controlProps["dispMode"]=0;controls->setProperty("properties",controlProps);events();
 auto*mini=item(controls,"miniTitle");
 check(!find(mini,"continuousTitle"),"mini-player does not load continuous animation");
 for(int cycle=0;cycle<2;++cycle){
  controlProps["playTitle"]="A very long song title for the original mini-player scrolling before a short song follows";
  controls->setProperty("properties",controlProps);events();settle(2600);
  check(mini->findChild<QObject*>("native_marqueeScroll")->property("running").toBool(),"native mini-player marquee starts after its original delay");
  controlProps["playTitle"]="Next";controls->setProperty("properties",controlProps);events();checkShort(mini,"Next");
  settle(300);checkShort(mini,"Next");
 }
 puts("PASS native title: original Sony marquee resources, full/mini long-to-short transitions, unchanged geometry and native controls");
}
