pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../shared"

// Tapo L530-style bulb on the LAN, driven by tapo-klap.sh (KLAP v2: curl + openssl for a
// few ms per call). Reads the state once at startup and then only while something shows
// it (acquire/release via ServiceHold), polling every 15s; no process lives in between.
// Same rules as AirconService: optimistic updates, bursts merged into one call, and
// changes made while the light is off are staged and sent with the next power-on
// (the bulb ignores brightness/colour while off).
Singleton {
    id: root

    readonly property int pollMs: 15000
    readonly property int minTemp: 2500
    readonly property int maxTemp: 6500
    readonly property string icon: String.fromCodePoint(0xF0335) // md-lightbulb
    readonly property string offIcon: String.fromCodePoint(0xF0336) // md-lightbulb_outline

    property var props: ({}) // last get_device_info result
    property var _staged: ({})
    property var _pending: ({}) // optimistic values until the bulb confirms
    readonly property var view: Object.assign({}, root.props, root._staged, root._pending)

    property bool hasState: false
    property string nickname: ""
    property string _nicknameRaw: ""
    property string errorCode: ""
    property string errorMessage: ""
    property int consumers: 0
    property bool busy: false

    readonly property bool power: view.device_on === true
    readonly property int brightness: view.brightness ?? 100
    readonly property bool isWhite: (view.color_temp ?? 0) > 0
    // Colour mode reports color_temp 0; remember the last white so switching back keeps it.
    property int _lastWhite: 4000
    readonly property int _viewTemp: view.color_temp ?? 0
    on_ViewTempChanged: if (_viewTemp > 0)
        _lastWhite = _viewTemp
    readonly property int colorTemp: _viewTemp || _lastWhite
    readonly property int hue: view.hue ?? 0
    readonly property int saturation: view.saturation ?? 100
    readonly property color lightColor: isWhite ? kelvinColor(colorTemp) : Qt.hsva(hue / 360, saturation / 100, 1, 1)
    readonly property bool _blocked: ["no_credentials", "no_keyring", "locked", "env_perms", "no_host", "auth", "no_openssl", "no_curl"].indexOf(errorCode) >= 0

    // Warm-to-cool white tint for 2500-6500 K, for the UI only.
    function kelvinColor(k) {
        var t = Math.max(0, Math.min(1, (k - minTemp) / (maxTemp - minTemp)));
        return Qt.rgba(1.0 - 0.13 * t, 0.71 + 0.2 * t, 0.42 + 0.58 * t, 1);
    }

    function acquire() {
        root.consumers += 1;
        root.refresh();
    }
    function release() {
        root.consumers = Math.max(0, root.consumers - 1);
    }

    function refresh() {
        root._send({});
    }

    function retry() {
        root.errorCode = "";
        root.errorMessage = "";
        root._login = null;
        root.refresh();
    }

    function set(changes) {
        if (!root.power && !("device_on" in changes)) {
            root._staged = Object.assign({}, root._staged, changes);
            return;
        }
        if (changes.device_on === true && Object.keys(root._staged).length > 0) {
            changes = Object.assign({}, root._staged, changes);
            root._staged = ({});
        }
        root._pending = Object.assign({}, root._pending, changes);
        root._send(changes);
    }

    function toggle() {
        root.set({ device_on: !root.power });
    }

    // ---- transport -------------------------------------------------------------------

    property var _login: null // {user, pass, host} once read
    property var _queued: null // changes waiting while a call is in flight (merged)

    function _send(changes) {
        root._queued = Object.assign({}, root._queued || {}, changes);
        if (!root.busy)
            root._flush();
    }

    function _flush() {
        if (root._queued === null)
            return;
        var changes = root._queued;
        root._queued = null;
        root.busy = true;
        root._withLogin(function (login) {
            var lines = [login.user, login.pass];
            if (Object.keys(changes).length > 0)
                lines.push(JSON.stringify({ method: "set_device_info", params: changes }));
            lines.push(JSON.stringify({ method: "get_device_info" }));
            root._runner.run(["bash", root._script, login.host], lines.join("\n") + "\n", function (code, out) {
                root._handle(out.trim().split("\n"));
                root.busy = false;
                root._flush();
            });
        });
    }

    function _handle(replies) {
        for (var i = 0; i < replies.length; i++) {
            var msg;
            try {
                msg = JSON.parse(replies[i]);
            } catch (e) {
                continue;
            }
            if (msg.error || (msg.error_code && msg.error_code !== 0)) {
                var code = msg.error || "command";
                root.errorCode = code;
                root.errorMessage = msg.error ? root._login?.host ?? "" : String(msg.error_code);
                root._pending = ({}); // the bulb didn't take it; show what it really has
                if (code === "auth")
                    root._login = null;
                return;
            }
            if (msg.result && msg.result.device_on !== undefined) {
                root.props = msg.result;
                if (msg.result.nickname !== root._nicknameRaw) { // decode once (Qt.atob warns on each call)
                    root._nicknameRaw = msg.result.nickname ?? "";
                    root.nickname = root._nicknameRaw ? Qt.atob(root._nicknameRaw) : "";
                }
                root.hasState = true;
                root._pending = ({});
                if (root.props.device_on)
                    root._staged = ({}); // turned on elsewhere: staged edits no longer apply
                root.errorCode = "";
                root.errorMessage = "";
            }
        }
    }

    function _fail(code, message) {
        root.errorCode = code;
        root.errorMessage = message || "";
        root._queued = null;
        root.busy = false;
    }

    function _withLogin(cb) {
        if (root._login)
            return cb(root._login);
        root._creds.load(function (err, c) {
            if (err)
                return root._fail(err.code, err.message);
            var host = (c.vars.TAPO_HOSTS || "").split(",")[0].trim();
            if (!host)
                return root._fail("no_host", root._creds.envPath);
            root._login = { user: c.user, pass: c.pass, host: host };
            cb(root._login);
        });
    }

    readonly property string _script: Qt.resolvedUrl("tapo-klap.sh").toString().slice(7)
    property ProcessRunner _runner: ProcessRunner {}
    property CredentialSource _creds: CredentialSource {
        keyringService: "tapo"
        envPathVar: "ZESIS_TAPO_ENV"
        envFileName: "tapo.env"
        userVar: "TAPO_USER"
        passVar: "TAPO_PASS"
    }

    // One read at startup so the bar icon shows the real state.
    Component.onCompleted: root.refresh()

    Timer {
        interval: root.pollMs
        repeat: true
        running: root.consumers > 0 && !root._blocked
        onTriggered: root.refresh()
    }
}
