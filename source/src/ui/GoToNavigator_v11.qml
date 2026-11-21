import QtQuick 2.3
import QtQml.Models 2.1
import "GoToLogic_v11.js" as Logic
Item {
    id:nav
    visible:false
    property var snapshot:null
    property var goHome:null
    property var goPlayer:null
    property var chooseNative:null
    property string runtimeUrl:"file:///data/sony-peq/runtime/"
    property string fontFamily:typeof viewstyle!=="undefined"?viewstyle.font_family:""
    property string stage:"closed"
    property string destination:""
    property string message:""
    property var target:null
    property var original:null
    property var sampleModel:null
    property var scanModel:null
    property var scanned:[]
    property int cursor:0
    property real started:0
    property string requestId:""
    property var xhr:null
    property var commandXhr:null
    property bool reading:false
    property bool routed:false
    property int completed:0
    property string diagnosticDetail:""
    property var statusXhr:null
    property string pendingStatus:""
    property string statusError:""
    function nativeRowCount(){try{return rows && rows.items?Number(rows.items.count):0}catch(e){return -1}}
    function saveStatus(force){
        if(!destination && !force)return
        // Diagnostics must never throw into a navigation property-change handler.
        try{
            var s=snapshot?snapshot():null
            pendingStatus=JSON.stringify({version:1,build:"1.1-stable",stage:stage,destination:destination,message:message,detail:diagnosticDetail,screen:s?String(s.screen):"",title:s&&s.current&&s.current.title?String(s.current.title):"",entryId:original?original.entry_id:null,albumId:target?target.albumId:null,albumArtistId:target?target.albumArtistId:null,cursor:cursor,count:nativeRowCount()})
            flushStatus()
        }catch(e){statusError=String(e)}
    }
    function flushStatus(){
        if(statusXhr || !pendingStatus)return
        var q=null
        try{
            var body=pendingStatus;pendingStatus="";q=new XMLHttpRequest();statusXhr=q
            q.onreadystatechange=function(){if(q.readyState===XMLHttpRequest.DONE){statusXhr=null;flushStatus()}}
            q.open("PUT",runtimeUrl+"goto-navigation-b6.json");q.send(body)
        }catch(e){if(q)q.onreadystatechange=null;statusXhr=null;statusError=String(e)}
    }
    onStageChanged:saveStatus()
    DelegateModel {id:rows;model:nav.sampleModel;delegate:Item {}}
    function open(){
        stop();target=null;message="";destination="";diagnosticDetail="";statusError="";routed=false
        var s=snapshot?snapshot():null
        if(!s || s.screen!=="MusicPlayer" || !s.playing || !s.playing.entry_id)return
        visible=true;stage="menu"
    }
    function stop(){tick.stop();reading=false;if(xhr){xhr.onreadystatechange=null;xhr.abort();xhr=null}if(commandXhr){commandXhr.onreadystatechange=null;commandXhr.abort();commandXhr=null}}
    function cancel(){var back=routed;stop();visible=false;stage="closed";sampleModel=null;scanModel=null;if(back&&goPlayer)try{goPlayer()}catch(e){diagnosticDetail=String(e);saveStatus()}}
    function fail(text){stop();message=text;stage="error";sampleModel=null;scanModel=null}
    function begin(kind){
        if(stage!=="menu" || (kind!=="album"&&kind!=="artist"))return
        var s=snapshot();var p=s.playing
        if(!p || !p.meta_data || !p.entry_id){fail("Playing track information is unavailable.");return}
        original={entry_id:Number(p.entry_id),meta_data:{play_title:p.meta_data.play_title,album_name:p.meta_data.album_name,artist_name:p.meta_data.artist_name}}
        destination=kind;stage="query";started=Date.now();requestId="n"+started+"-"+original.entry_id
        var command=new XMLHttpRequest();commandXhr=command
        command.onreadystatechange=function(){if(command.readyState===XMLHttpRequest.DONE)commandXhr=null}
        command.open("PUT",runtimeUrl+"goto-target-command");command.send(requestId+"\n"+original.entry_id)
        tick.start()
    }
    function acceptMetadata(data){
        if(stage!=="query" || !data || data.requestId!==requestId || String(data.entryId)!==String(original.entry_id))return
        var s=snapshot()
        if(s.screen!=="MusicPlayer"){routed=false;cancel();return}
        if(!s.playing || Number(s.playing.entry_id)!==original.entry_id){fail("The playing track changed. Open Go to again.");return}
        if(!Logic.validTarget(data,original)){fail(data.error || "Library metadata does not match the playing track.");return}
        target=data;stage="home";started=Date.now()
    }
    function readMetadata(){
        if(reading)return
        reading=true;var q=new XMLHttpRequest();xhr=q
        q.onreadystatechange=function(){
            if(q.readyState!==XMLHttpRequest.DONE)return
            reading=false;xhr=null
            try{acceptMetadata(JSON.parse(q.responseText))}catch(e){}
        }
        q.open("GET",runtimeUrl+"goto-target.json");q.send()
    }
    function scan(s,kind){
        if(!s.current || !s.current.list)return null
        sampleModel=s.current.list
        if(scanModel!==sampleModel){scanModel=sampleModel;cursor=0;scanned=[]}
        if(!rows.items)return null
        var count=rows.items.count
        if(!count)return null
        if(count>20000){fail("Library list is too large for this trial.");return null}
        var expected=kind==="artist"?Logic.artistCover(target):kind==="album"?Logic.albumCover(target):Number(target.entryId)
        var expectedName=kind==="artist"?target.albumArtist:kind==="album"?target.album:target.title
        var end=Math.min(cursor+8,count)
        for(var i=cursor;i<end;i++){
            var m=rows.items.get(i).model
            var index=Number(m.index)
            if(s.current.isAllRowExists && index===0){cursor++;continue}
            // Reading the actual roles requests Sony's lazy metadata. The generic
            // track-cache flag is not a readiness contract for Artist/Album rows.
            var cover=Number(m.MainCoverArtRole),name=""
            if(!isFinite(cover) || cover<=0){var requestedName=m.NameQstringRole;return null}
            if(cover===expected){
                name=String(m.NameQstringRole)
                if(name!==expectedName)return null
            }
            scanned.push({index:index,name:name,cover:cover,ready:true});cursor++
        }
        if(cursor!==count)return null
        var result=Logic.findRow(kind,target,scanned,!!s.current.isAllRowExists)
        if(result.error){fail(result.error);return null}
        var live=rows.items.get(result.index).model
        if(Number(live.MainCoverArtRole)!==expected || String(live.NameQstringRole)!==result.name){nextScan();return null}
        return result
    }
    function nextScan(){sampleModel=null;scanModel=null;cursor=0;scanned=[]}
    function finish(){stop();visible=false;stage="closed";nextScan();completed++}
    function step(){
        try{
            if(!visible || stage==="menu" || stage==="error")return
            if(Date.now()-started>(stage==="query"?6500:30000)){fail("Opening the library timed out. Please try again.");return}
            if(stage==="query"){readMetadata();return}
            var s=snapshot();if(!s)return
            if(s.screen && ["MusicPlayer","MusicPlayerTop","ArtistList","ArtistAlbumList","ArtistAlbumTrackList"].indexOf(s.screen)<0){routed=false;cancel();return}
            if(stage==="home"){
                stage="waitHome";routed=true;goHome();return
            }
            if(stage==="waitHome"){
                if(s.screen!=="MusicPlayerTop" || !s.library || !s.library.icon_list)return
                var icons=s.library.icon_list,selected=-1
                for(var i=0;i<icons.count();i++)if(Number(icons.get(i).id)===2){if(selected>=0){fail("Artist library icon is ambiguous.");return}selected=i}
                if(selected<0){fail("Enable the Artist icon in the music library first.");return}
                stage="waitArtist";nextScan();if(!chooseNative(selected,""))fail("Cannot open the Artist list.");return
            }
            if(stage==="waitArtist"){
                if(s.screen!=="ArtistList")return
                var artist=scan(s,"artist");if(!artist)return
                stage="waitAlbums";nextScan();if(!chooseNative(artist.index,artist.name))fail("Cannot open the Album Artist.");return
            }
            if(stage==="waitAlbums"){
                if(s.screen!=="ArtistAlbumList" || !s.current || s.current.title!==target.albumArtist)return
                if(destination==="artist"){if(!s.transitioning)finish();return}
                var album=scan(s,"album");if(!album)return
                stage="waitTracks";nextScan();if(!chooseNative(album.index,album.name))fail("Cannot open the album.");return
            }
            if(stage==="waitTracks"){
                if(s.screen!=="ArtistAlbumTrackList" || !s.current || s.current.title!==target.album)return
                if(scan(s,"track") && !s.transitioning)finish()
            }
        }catch(e){diagnosticDetail=String(e);fail("Native library navigation is unavailable.")}
    }
    Connections {target:nav.sampleModel;onModelReset:nav.nextScan();onRowsInserted:nav.nextScan();onRowsRemoved:nav.nextScan();onLayoutChanged:nav.nextScan()}
    Timer {id:tick;interval:100;repeat:true;onTriggered:nav.step()}
    Rectangle {objectName:"goToBackdrop";anchors.fill:parent;color:"black";opacity:nav.stage==="menu"?0.7:1}
    MouseArea {anchors.fill:parent;onClicked:if(nav.stage==="menu")nav.cancel()}
    Rectangle {
        objectName:"goToCard"
        width:360;height:content.height+24;color:"#111111";border.color:"#777777"
        x:nav.stage==="menu"?parent.width-width-20:(parent.width-width)/2
        y:nav.stage==="menu"?parent.height-height-75:(parent.height-height)/2
        MouseArea {anchors.fill:parent}
        Column {
            id:content;x:12;y:12;width:parent.width-24;spacing:10
            Text {text:"Go to";color:"white";font.family:nav.fontFamily;font.pixelSize:25}
            Repeater {
                model:nav.stage==="menu"?["Album","Album Artist"]:[]
                Rectangle {
                    width:content.width;height:58;color:"#222222";border.color:"#555555"
                    Text {anchors.centerIn:parent;text:modelData;color:"white";font.family:nav.fontFamily;font.pixelSize:23}
                    MouseArea {anchors.fill:parent;onClicked:nav.begin(index===0?"album":"artist")}
                }
            }
            Text {visible:nav.stage!=="menu";width:content.width;text:nav.message || "Opening library...";color:"white";font.family:nav.fontFamily;font.pixelSize:20;wrapMode:Text.Wrap}
            Text {visible:nav.stage==="error" && text.length>0;width:content.width;text:nav.diagnosticDetail || nav.statusError;color:"#cccccc";font.family:nav.fontFamily;font.pixelSize:17;wrapMode:Text.WrapAnywhere;maximumLineCount:6;elide:Text.ElideRight}
            Rectangle {
                width:content.width;height:48;color:"#222222"
                Text {anchors.centerIn:parent;text:"Cancel";color:"white";font.family:nav.fontFamily;font.pixelSize:21}
                MouseArea {anchors.fill:parent;onClicked:nav.cancel()}
            }
        }
    }
    Component.onCompleted:{diagnosticDetail="component-loaded";saveStatus(true);diagnosticDetail=""}
    Component.onDestruction:{stop();pendingStatus="";if(statusXhr){statusXhr.onreadystatechange=null;statusXhr.abort()}}
}
