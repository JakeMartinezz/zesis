pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// ConnectLife air conditioner state, driven by AirconBackend (direct cloud calls). The
// polling backend only runs while something is looking at the widget (acquire/release);
// with no consumers nothing runs. See the aircon design spec for the protocol.
Singleton {
    id: root

    readonly property int interval: 45
    readonly property int graceMs: 60000
    readonly property int pendingMs: 10000
    readonly property int minTemp: 16
    readonly property int maxTemp: 32

    // Values from the connectlife-ha mapping for device type 009, not yet confirmed
    // on the unit. This is the only place they live.
    readonly property string acIcon: String.fromCodePoint(0xF001B) // md-air_conditioner
    readonly property var modes: [
        { value: 2, key: "modeCool", icon: String.fromCodePoint(0xF0717) }, // md-snowflake
        { value: 1, key: "modeHeat", icon: String.fromCodePoint(0xF0238) }, // md-fire
        { value: 3, key: "modeDry", icon: String.fromCodePoint(0xF058C) },  // md-water
        { value: 0, key: "modeFan", icon: String.fromCodePoint(0xF0210) },  // md-fan
        { value: 4, key: "modeAuto", icon: String.fromCodePoint(0xF006A) } // md-autorenew
    ]
    readonly property var fans: [
        { value: 5, key: "low" }, { value: 6, key: "midLow" }, { value: 7, key: "mid" },
        { value: 8, key: "midHigh" }, { value: 9, key: "high" }
    ]
    readonly property int fanAuto: 0
    readonly property var extras: [
        { prop: "t_eco", key: "extraEco", icon: String.fromCodePoint(0xF032A) },        // md-leaf
        { prop: "t_super", key: "extraTurbo", icon: String.fromCodePoint(0xF14DE) },    // md-rocket_launch
        { prop: "t_sleep", key: "extraSleep", icon: String.fromCodePoint(0xF04B2) },    // md-sleep
        { prop: "t_fan_mute", key: "extraQuiet", icon: String.fromCodePoint(0xF0581) }  // md-volume_off
    ]

    property var props: ({})
    property var _pending: ({}) // prop -> { value, until (ms) }
    property var _staged: ({}) // prop -> value, edits made while off (see set())
    readonly property bool hasStaged: Object.keys(_staged).length > 0
    readonly property var view: {
        var v = Object.assign({}, root.props, root._staged);
        for (var k in root._pending)
            v[k] = root._pending[k].value;
        return v;
    }

    property bool hasState: false
    property bool online: true
    property int lastUpdate: 0
    property int now: 0
    property string errorCode: ""
    property string errorMessage: ""
    property int consumers: 0
    readonly property bool live: _daemon.running && !_daemon.once

    readonly property bool power: view.t_power === 1
    readonly property int targetTemp: view.t_temp ?? 0
    readonly property int roomTemp: view.f_temp_in ?? 0
    readonly property int mode: view.t_work_mode ?? -1
    readonly property int fan: view.t_fan_speed ?? 0
    readonly property real countdown: lastUpdate > 0 ? Math.max(0, Math.min(1, (now - lastUpdate) / interval)) : 0

    readonly property var _fatal: ["no_openssl", "no_keyring", "locked", "no_credentials", "auth", "env_perms"]
    readonly property bool _blocked: _fatal.indexOf(errorCode) >= 0
    property int _nextId: 1
    property var _inflight: ({}) // command id -> [prop keys]
    property var _outbox: []

    function modeInfo(value) {
        for (var i = 0; i < modes.length; i++)
            if (modes[i].value === value)
                return modes[i];
        return null;
    }

    // Cool keeps the theme accent; heat rotates the accent to a warm hue at the same
    // saturation/lightness so it still matches the Matugen palette.
    function modeColor(value, on) {
        if (!on)
            return Colors.muted;
        if (value === 2)
            return Colors.accent;
        if (value === 1) {
            var a = Qt.color(Colors.accent);
            return Qt.hsla(0.05, Math.max(a.hslSaturation, 0.55), a.hslLightness, 1);
        }
        return Colors.text;
    }

    function acquire() {
        root.consumers += 1;
        _grace.stop();
        root._ensureLive();
    }

    function release() {
        root.consumers = Math.max(0, root.consumers - 1);
        if (root.consumers === 0)
            _grace.restart();
    }

    function set(changes) {
        // Every command makes the unit beep, even while it's off. So while off, changes
        // are only staged locally and go out together with the next power-on.
        if (!root.power && !("t_power" in changes)) {
            root._staged = Object.assign({}, root._staged, changes);
            return;
        }
        if (changes.t_power === 1 && root.hasStaged) {
            changes = Object.assign({}, root._staged, changes);
            root._staged = ({});
        }
        var id = root._nextId++;
        var until = Date.now() + root.pendingMs;
        var pending = Object.assign({}, root._pending);
        for (var k in changes)
            pending[k] = { value: changes[k], until: until };
        root._pending = pending;
        var inflight = Object.assign({}, root._inflight);
        inflight[id] = Object.keys(changes);
        root._inflight = inflight;
        _pendingExpiry.restart();
        root._send({ id: id, set: changes });
    }

    function toggle(prop) {
        var change = {};
        change[prop] = root.view[prop] === 1 ? 0 : 1;
        root.set(change);
    }

    function refresh() {
        root._send({ refresh: true });
    }

    function retry() {
        root.errorCode = "";
        root.errorMessage = "";
        _retryTimer.stop();
        if (root.live)
            root.refresh();
        else if (root.consumers > 0)
            root._ensureLive();
        else
            root._start(true);
    }

    function saveCredentials(user, pass) {
        _store.queue = [["user", user], ["pass", pass]];
        _store.next();
    }

    function _send(obj) {
        if (root.live)
            _daemon.send(obj);
        else {
            root._outbox = root._outbox.concat([obj]);
            root._ensureLive();
        }
    }

    function _ensureLive() {
        if (root.consumers === 0 || root._blocked || _daemon.running)
            return;
        root._start(false);
    }

    function _start(once) {
        if (_daemon.running)
            return;
        _daemon.start(once);
        if (once)
            return;
        var queued = root._outbox;
        root._outbox = [];
        queued.forEach(_daemon.send); // the backend holds them until it's logged in
    }

    function _handle(msg) {
        if (msg.type === "state") {
            root.props = msg.props || {};
            // Turned on elsewhere (remote, app): what's staged no longer applies.
            if (root.props.t_power === 1)
                root._staged = ({});
            root.online = msg.online === true;
            root.lastUpdate = msg.ts || Math.floor(Date.now() / 1000);
            root.now = Math.floor(Date.now() / 1000);
            root.hasState = true;
            if (!root._blocked) {
                root.errorCode = "";
                root.errorMessage = "";
            }
            root._prunePending();
        } else if (msg.type === "ack") {
            root._dropInflight(msg.id, false);
        } else if (msg.type === "error") {
            root.errorCode = msg.code || "network";
            root.errorMessage = msg.message || "";
            if (msg.id !== null && msg.id !== undefined)
                root._dropInflight(msg.id, true);
        }
    }

    // A pending value stays until the gateway reports it or it expires.
    function _prunePending() {
        var t = Date.now();
        var pending = {};
        for (var k in root._pending) {
            var p = root._pending[k];
            if (root.props[k] !== p.value && t < p.until)
                pending[k] = p;
        }
        root._pending = pending;
    }

    function _dropInflight(id, revert) {
        var keys = root._inflight[id] || [];
        var inflight = Object.assign({}, root._inflight);
        delete inflight[id];
        root._inflight = inflight;
        if (!revert)
            return;
        var pending = Object.assign({}, root._pending);
        for (var i = 0; i < keys.length; i++)
            delete pending[keys[i]];
        root._pending = pending;
    }

    // One fetch at startup so the bar starts with real state.
    Component.onCompleted: root._start(true)

    AirconBackend {
        id: _daemon
        onMessage: msg => root._handle(msg)
        onExited: {
            if (!once) {
                // Nothing will confirm or revert these any more.
                root._pending = ({});
                root._inflight = ({});
            }
            if (root.consumers === 0 || root._blocked)
                return;
            if (once)
                root._start(false);
            else
                _retryTimer.restart();
        }
    }

    Timer {
        id: _grace
        interval: root.graceMs
        onTriggered: {
            _retryTimer.stop();
            if (root.consumers === 0)
                _daemon.stop();
        }
    }

    // Expires optimistic values even if no state line arrives; only runs after a set().
    Timer {
        id: _pendingExpiry
        interval: root.pendingMs
        onTriggered: root._prunePending()
    }

    Timer {
        id: _retryTimer
        interval: root.interval * 1000
        onTriggered: root._ensureLive()
    }

    Timer {
        running: root.consumers > 0
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Math.floor(Date.now() / 1000)
    }

    // Writes each credential to `secret-tool store` through stdin, one at a time,
    // so it never shows up in argv. The value is cleared as soon as it's written.
    Process {
        id: _store
        property var queue: []
        property string _value: ""

        function next() {
            if (queue.length === 0) {
                root.retry();
                return;
            }
            var item = queue[0];
            queue = queue.slice(1);
            _value = item[1];
            command = ["secret-tool", "store", "--label=ConnectLife " + item[0], "service", "connectlife", "key", item[0]];
            stdinEnabled = true;
            running = true;
        }

        onStarted: {
            write(_value);
            _value = "";
            stdinEnabled = false; // closes stdin, secret-tool stores on EOF
        }
        onExited: code => {
            if (code === 0) {
                next();
            } else {
                queue = [];
                root.errorCode = "store";
                root.errorMessage = "";
            }
        }
    }
}
