import QtQuick 2.3

Item {
    id: battery
    // Shared by the native status icons; no daemon, audio hook or charger writes.
    property string capacityUrl: "file:///sys/class/power_supply/battery/capacity"
    property string statusUrl: "file:///sys/class/power_supply/battery/status"
    property string brightnessUrl: "file:///sys/class/leds/lcd-backlight/brightness"
    property string voltageUrl: "file:///sys/class/power_supply/battery/voltage_now"
    property string usbOnlineUrl: "file:///sys/class/power_supply/usb/online"
    property string diagnosticUrl: "file:///data/sony-peq/runtime/battery-diagnostic.json"
    property string rawCapacity: ""
    property string rawStatus: ""
    property string rawBrightness: ""
    property string rawVoltage: ""
    property string rawUsbOnline: ""
    property string nativeIcon: ""
    property double startedAt: Date.now()
    property var history: []
    property int diagnosticWrites: 0
    property bool diagnosticWriting: false
    property var diagnosticRequest: null
    property int consumers: 0
    property bool available: false
    property int percent: -1
    property string chargeStatus: ""
    property bool screenOn: false
    readonly property bool charging: available && chargeStatus === "Charging"
    readonly property bool full: available && chargeStatus === "Full"
    property bool reading: false
    property bool brightnessPending: false
    property int generation: 0
    property var requests: []
    property int brightnessGeneration: 0
    property var brightnessRequest: null
    readonly property bool refreshRunning: refresh.running
    readonly property bool displayPollRunning: displayPoll.running

    function noteNativeIcon(name) {
        if (nativeIcon === name) return
        nativeIcon = String(name).slice(0, 120)
        record("native-icon")
    }
    function record(reason) {
        if (diagnosticWrites >= 120) return
        var rows = history.slice(0)
        rows.push({ms:Math.round(Date.now()-startedAt),reason:reason,
                   capacityRaw:rawCapacity,statusRaw:rawStatus,
                   brightnessRaw:rawBrightness,voltageRaw:rawVoltage,usbOnlineRaw:rawUsbOnline,
                   nativeIcon:nativeIcon,percent:percent,available:available,
                   charging:charging,full:full,screenOn:screenOn,consumers:consumers})
        while (rows.length > 64) rows.shift()
        history = rows
        if (!diagnosticFlush.running) diagnosticFlush.start()
    }
    function writeDiagnostic() {
        if (!diagnosticUrl.length || diagnosticWriting || diagnosticWrites >= 120) return
        var body = JSON.stringify({version:1,build:"topbar-balanced-3",events:history})
        while (body.length > 32768 && history.length > 1) {
            history = history.slice(1)
            body = JSON.stringify({version:1,build:"topbar-balanced-3",events:history})
        }
        if (body.length > 32768) return
        diagnosticWrites++
        diagnosticWriting = true
        var xhr = new XMLHttpRequest()
        diagnosticRequest = xhr
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            diagnosticDeadline.stop()
            diagnosticWriting = false
            diagnosticRequest = null
        }
        diagnosticDeadline.start()
        xhr.open("PUT", diagnosticUrl)
        xhr.send(body + "\n")
    }
    Timer { id: diagnosticFlush; interval: 2000; onTriggered: battery.writeDiagnostic() }
    Timer {
        id: diagnosticDeadline
        interval: 2000
        onTriggered: {
            if (battery.diagnosticRequest) battery.diagnosticRequest.abort()
            battery.diagnosticRequest = null
            battery.diagnosticWriting = false
        }
    }

    function acquire() {
        consumers++
        if (consumers === 1) { readBrightness(); reload() }
    }
    function release() {
        consumers = Math.max(0, consumers - 1)
        if (!consumers) { cancel(); screenOn = false }
        record("consumer-release")
    }
    function cancel() {
        generation++
        brightnessGeneration++
        deadline.stop()
        brightnessDeadline.stop()
        for (var i = 0; i < requests.length; i++) requests[i].abort()
        requests = []
        if (brightnessRequest) brightnessRequest.abort()
        brightnessRequest = null
        reading = false
        brightnessPending = false
    }
    function readText(url, done) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE)
                done(xhr.responseText.replace(/^\s+|\s+$/g, ""))
        }
        xhr.open("GET", url + "?r=" + Date.now())
        xhr.send()
        return xhr
    }
    function reload() {
        if (!consumers || reading) return
        reading = true
        var serial = ++generation
        var left = 4
        var capacity = "", status = "", voltage = "", usb = ""
        requests = []
        deadline.start()
        function finish() {
            if (generation !== serial || --left) return
            deadline.stop()
            reading = false
            requests = []
            var number = /^\d{1,3}$/.test(capacity) ? Number(capacity) : -1
            var known = ["Charging", "Discharging", "Not charging", "Full", "Unknown"].indexOf(status) >= 0
            available = number >= 0 && number <= 100 && known
            percent = available ? number : -1
            chargeStatus = available ? status : ""
            rawCapacity = capacity.slice(0, 40)
            rawStatus = status.slice(0, 40)
            rawVoltage = voltage.slice(0, 40)
            rawUsbOnline = usb.slice(0, 40)
            record("battery-read")
        }
        requests.push(readText(capacityUrl, function(value) {
            if (generation !== serial) return
            capacity = value; finish()
        }))
        requests.push(readText(statusUrl, function(value) {
            if (generation !== serial) return
            status = value; finish()
        }))
        requests.push(readText(voltageUrl, function(value) {
            if (generation !== serial) return
            voltage = value; finish()
        }))
        requests.push(readText(usbOnlineUrl, function(value) {
            if (generation !== serial) return
            usb = value; finish()
        }))
    }
    function readBrightness() {
        if (!consumers || brightnessPending) return
        brightnessPending = true
        var serial = ++brightnessGeneration
        brightnessDeadline.start()
        brightnessRequest = readText(brightnessUrl, function(value) {
            if (brightnessGeneration !== serial) return
            brightnessDeadline.stop()
            brightnessPending = false
            brightnessRequest = null
            var awake = /^\d+$/.test(value) && Number(value) > 0
            var waking = awake && !screenOn
            var changed = rawBrightness !== value
            rawBrightness = value.slice(0, 40)
            screenOn = awake
            if (changed) record("brightness-read")
            if (waking) reload()
        })
    }
    Timer {
        id: refresh
        interval: 10000
        repeat: true
        running: battery.consumers > 0 && battery.screenOn
        onTriggered: battery.reload()
    }
    // QQuickWindow can remain visible while Sony turns off the backlight.
    // One shared low-rate check stops the fill animation during screen-off.
    Timer {
        id: displayPoll
        interval: battery.charging ? (battery.screenOn ? 1000 : 1500) : (battery.screenOn ? 10000 : 5000)
        repeat: true
        running: battery.consumers > 0
        onTriggered: battery.readBrightness()
    }
    Timer {
        id: deadline
        interval: 3000
        onTriggered: {
            battery.generation++
            for (var i = 0; i < battery.requests.length; i++) battery.requests[i].abort()
            battery.requests = []
            battery.reading = false
            battery.available = false
            battery.percent = -1
            battery.chargeStatus = ""
        }
    }
    Timer {
        id: brightnessDeadline
        interval: 2500
        onTriggered: {
            battery.brightnessGeneration++
            if (battery.brightnessRequest) battery.brightnessRequest.abort()
            battery.brightnessRequest = null
            battery.brightnessPending = false
            battery.screenOn = false
        }
    }
    Component.onDestruction: cancel()
}
