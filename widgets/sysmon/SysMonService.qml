// qmllint disable import
pragma Singleton
// qmllint enable import
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string _configDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/zesis"
    readonly property string _configPath: _configDir + "/sysmon.json"

    property bool desktopWidgetActive: false
    // Bar items showing the CPU arc (see SysMonItem.inRow); acquire()/release() via ServiceHold.
    property int consumers: 0
    // athroisma only runs while something shows its numbers: a bar item in the row (not
    // collapsed behind the chevron), the popup, the Home panel section or the desktop widget.
    readonly property bool _needed: consumers > 0 || popupOpen || panelOpen || desktopWidgetActive

    function acquire() {
        root.consumers += 1;
    }
    function release() {
        root.consumers = Math.max(0, root.consumers - 1);
    }
    property bool popupOpen: false
    property bool panelOpen: false
    property int activeTab: 0  // 0=CPU, 1=Memory, 2=GPU, 3=Net, 4=Disk, 5=Settings
    property int pullRateMs: sysmonData.pullRateMs
    property int procLimit: sysmonData.procLimit
    property bool filterZero: sysmonData.filterZero

    property var cpu: ({
            percent: 0,
            load: 0,
            procs: []
        })
    property var memory: ({
            used_bytes: 0,
            total_bytes: 1,
            swap_used_bytes: 0,
            swap_total_bytes: 0,
            procs: []
        })
    property var gpu: []
    property var net: []
    property var disk: []
    property int selectedCard: 0

    readonly property var gpuCard: gpu.length > selectedCard ? gpu[selectedCard] : null
    readonly property var gpuComputeSegments: {
        if (!gpuCard)
            return [];
        return (gpuCard.procs || []).filter(p => p.gfx_pct > 0).map(p => ({
                    color: procColor(p.name),
                    value: p.gfx_pct
                }));
    }
    readonly property var gpuVramSegments: {
        if (!gpuCard)
            return [];
        return (gpuCard.procs || []).filter(p => p.vram_kib > 0).map(p => ({
                    color: procColor(p.name),
                    value: p.vram_kib * 1024
                }));
    }

    function procColor(name) {
        var h = 5381;
        for (var i = 0; i < name.length; i++)
            h = ((h << 5) + h ^ name.charCodeAt(i)) >>> 0;
        return Qt.hsla((h % 360) / 360, 0.68, 0.58, 1.0);
    }

    function fmtBytes(n) {
        if (n >= 1073741824)
            return (n / 1073741824).toFixed(1) + "G";
        if (n >= 1048576)
            return Math.round(n / 1048576) + "M";
        if (n >= 1024)
            return Math.round(n / 1024) + "K";
        return n + "B";
    }

    function fmtRate(n) {
        return fmtBytes(n) + "/s";
    }

    readonly property var diskFlat: {
        var out = [];
        for (var i = 0; i < disk.length; i++) {
            out.push({
                name: disk[i].name,
                read: disk[i].read_bytes_per_sec,
                write: disk[i].write_bytes_per_sec,
                depth: 0
            });
            var parts = disk[i].partitions || [];
            for (var j = 0; j < parts.length; j++)
                out.push({
                    name: parts[j].name,
                    read: parts[j].read_bytes_per_sec,
                    write: parts[j].write_bytes_per_sec,
                    depth: 1
                });
        }
        return out;
    }

    readonly property var cpuSegments: (cpu.procs || []).map(p => ({
                color: procColor(p.name),
                value: p.cpu
            }))
    readonly property var memSegments: (memory.procs || []).map(p => ({
                color: procColor(p.name),
                value: p.rss
            }))

    onDesktopWidgetActiveChanged: sendRequest()
    onPopupOpenChanged: sendRequest()
    onPanelOpenChanged: sendRequest()
    onActiveTabChanged: sendRequest()
    onPullRateMsChanged: {
        if (proc.running)
            proc.write("interval " + pullRateMs + "\n");
        _save();
    }
    onProcLimitChanged: {
        sendRequest();
        _save();
    }
    onFilterZeroChanged: {
        sendRequest();
        _save();
    }

    function _save() {
        saveProc.command = ["sh", "-c", "mkdir -p '" + _configDir + "' && printf '%s' '{\"pullRateMs\":" + pullRateMs + ",\"procLimit\":" + procLimit + ",\"filterZero\":" + (filterZero ? "true" : "false") + "}' > '" + _configPath + "'"];
        saveProc.running = true;
    }

    JsonAdapter {
        id: sysmonData
        property int pullRateMs: 1000
        property int procLimit: 10
        property bool filterZero: true
    }

    FileView {
        path: root._configPath
        watchChanges: true
        adapter: sysmonData
        onFileChanged: reload()
    }

    Process {
        id: saveProc
        running: false
    }

    function sendRequest() {
        if (!proc.running)
            return;
        var wantMem = desktopWidgetActive;
        var wantGpu = desktopWidgetActive;
        var wantNet = desktopWidgetActive;
        var wantDisk = desktopWidgetActive;
        var wantProcs = false;

        if (popupOpen || panelOpen) {
            if (activeTab === 0)
                wantProcs = true;
            if (activeTab === 1) {
                wantMem = true;
                wantProcs = true;
            }
            if (activeTab === 2) {
                wantGpu = true;
                wantProcs = true;
            }
            if (activeTab === 3)
                wantNet = true;
            if (activeTab === 4)
                wantDisk = true;
        }

        var tokens = ["cpu"];
        if (wantMem)
            tokens.push("mem");
        if (wantGpu)
            tokens.push("gpu");
        if (wantNet)
            tokens.push("net");
        if (wantDisk)
            tokens.push("disk");
        if (wantProcs) {
            tokens.push("procs");
            if (filterZero)
                tokens.push("nozero");
            tokens.push("limit", String(procLimit));
        }
        proc.write("now " + tokens.join(" ") + "\n");
    }

    Process {
        id: proc
        running: root._needed
        stdinEnabled: true
        command: ["athroisma", "cpu"]
        // A fresh daemon starts with its defaults: resend the rate and what we want.
        onStarted: {
            write("interval " + root.pullRateMs + "\n");
            root.sendRequest();
        }
        stdout: SplitParser {
            onRead: data => {
                try {
                    var s = JSON.parse(data);
                    if (s.cpu !== undefined)
                        root.cpu = s.cpu;
                    if (s.memory !== undefined)
                        root.memory = s.memory;
                    if (s.gpu !== undefined)
                        root.gpu = s.gpu;
                    if (s.net !== undefined)
                        root.net = s.net;
                    if (s.disk !== undefined)
                        root.disk = s.disk;
                } catch (_) {}
            }
        }
    }
}
