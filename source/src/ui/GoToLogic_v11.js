.pragma library
function validTarget(data,playing){
    if(!data || !data.ok || !playing || !playing.meta_data)return false
    var id=Number(playing.entry_id),object=Number(data.objectId),m=playing.meta_data
    if(Number(data.entryId)!==id || !isFinite(id) || id<=0 || id>4294967295 || Math.floor(id)!==id)return false
    if(data.resolution==="exact"){if(object!==id)return false}
    else if(data.resolution==="native-type-0x1-candidate"){
        if(Math.floor(id/268435456)!==1 || object!==id%268435456)return false
    }else return false
    if(typeof data.album!=="string" || !data.album || typeof data.albumArtist!=="string" || !data.albumArtist)return false
    if(!m.play_title || !m.album_name || !m.artist_name)return false
    if(data.title!==m.play_title || data.album!==m.album_name || data.trackArtist!==m.artist_name)return false
    return key(data.albumId) && key(data.albumArtistId)
}
function key(id){return typeof id==="number" && isFinite(id) && Math.floor(id)===id && id>0 && id<=16777215}
function artistCover(target){return 2214592512+target.albumArtistId}
function albumCover(target){return 2164260864+target.albumId}
function findRow(kind,target,rows,hasAll){
    var expected=kind==="artist"?artistCover(target):kind==="album"?albumCover(target):Number(target.entryId)
    var name=kind==="artist"?target.albumArtist:kind==="album"?target.album:target.title
    var found=-1
    for(var i=0;i<rows.length;i++){
        var row=rows[i]
        if(!row.ready)return {pending:true}
        if(!isFinite(row.index) || row.index<0 || Math.floor(row.index)!==row.index)return {error:"Native row index is unavailable."}
        if(hasAll && row.index===0)continue
        if(Number(row.cover)===expected && row.name===name){
            if(found>=0)return {error:"More than one native row matches this record."}
            found=row.index
        }
    }
    if(found<0)return {error:kind==="artist"?"Album Artist not found. Check Playback Settings > Artist list display.":"The matching native library record was not found."}
    return {index:found,name:name}
}
