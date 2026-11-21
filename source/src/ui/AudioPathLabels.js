.pragma library

function normalized(value) {
    return value === undefined || value === null ? "" : String(value).replace(/\s+/g," ").trim().toLowerCase()
}
function kind(value, translated) {
    var name=normalized(value), nativeName=normalized(translated)
    if (!name.length) return 0
    var knownTranslation=nativeName.length && nativeName!=="020031"
    if (name==="bookmark list" || (knownTranslation && name===nativeName)) return 1
    if (name.indexOf("bookmark")>=0 || (knownTranslation && name.indexOf(nativeName)>=0)) return 2
    return 0
}
function label(value, translated) {
    return kind(value,translated)===1 ? "Audio Path" : (value===undefined || value===null ? "" : String(value))
}
