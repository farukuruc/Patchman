.pragma library
// Emit the zero-argument signals explicitly declared by Sony's NavigationBar.
// Do not assume the native StateButton's clicked argument signature.
function activate(window,action){
    if(action!=="library" && action!=="play")throw new Error("Unsupported native navigation action")
    var name=window && window.navigationBar ? String(window.navigationBar.objectName || "") : ""
    if(!name)throw new Error("Current window has no native navigation bar identity")
    var pending=[window],matches=[],seen=0
    while(pending.length && seen++<1024){
        var item=pending.shift()
        if(String(item.objectName)===name)matches.push(item)
        var children=item.children || []
        for(var i=0;i<children.length;i++)pending.push(children[i])
    }
    if(pending.length)throw new Error("Native navigation tree exceeds the scan limit")
    if(matches.length!==1)throw new Error("Native navigation bar is missing or ambiguous: "+name)
    var bar=matches[0],wanted=action==="library"?"FunctionTopButton":"NowPlayingButton",button=null
    for(var j=0;j<bar.children.length;j++)if(String(bar.children[j].objectName)===wanted){
        if(button)throw new Error("Native navigation button is ambiguous: "+wanted)
        button=bar.children[j]
    }
    if(!button || !button.enabled || !button.visible)throw new Error("Native navigation button is unavailable: "+wanted)
    if(typeof bar[action]!=="function")throw new Error("Native QML navigation signal is unavailable: "+action)
    bar[action]()
    return true
}
