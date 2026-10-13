pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../shared"
import "connectlife.js" as CL

// Talks to the ConnectLife cloud directly (XMLHttpRequest) and emits the same messages
// AirconService always consumed: {type:"state"|"ack"|"error", ...}. The only external
// program is `openssl`, run for a few ms per gateway request to RSA-sign it (QML's JS
// engine has no BigInt or crypto). Tokens stay in memory, so reopening the popup
// doesn't log in again.
QtObject {
    id: root

    signal message(var msg)
    signal exited

    property bool running: false
    property bool once: false

    readonly property int interval: 45000
    readonly property int setDelay: 2000 // the gateway needs a moment before a fetch reflects a set
    readonly property string _pem: Qt.resolvedUrl("connectlife_gateway.pem").toString().slice(7)

    property string _user: ""
    property string _pass: ""
    property string _access: ""
    property string _refresh: ""
    property real _expires: 0
    property real _refreshExpires: 0
    property string _puid: ""
    property int _gen: 0 // bumped by stop(); callbacks from an older run are dropped
    property bool _busy: false
    property var _queue: []

    function start(once) {
        if (root.running)
            return;
        root.once = once;
        root.running = true;
        root._busy = true; // commands sent meanwhile wait in the queue
        var gen = ++root._gen;
        root._credentials(gen, function () {
            root._withToken(gen, function () {
                root._fetch(gen, function (msg) {
                    root._busy = false;
                    root._emit(msg);
                    if (msg.type === "error" && msg.code === "auth" || root.once) {
                        root.stop();
                        return;
                    }
                    _poll.restart();
                    root._drain();
                });
            });
        });
    }

    function stop() {
        if (!root.running)
            return;
        root._gen++;
        root.running = false;
        root._busy = false;
        root._queue = [];
        _poll.stop();
        root.exited();
    }

    // cmd: {id, set:{...}} or {refresh:true}
    function send(cmd) {
        root._queue = root._queue.concat([cmd]);
        root._drain();
    }

    function _emit(msg) {
        if (msg.type === "error" && msg.code === "auth")
            root._forget();
        root.message(msg);
    }

    function _fail(gen, code, message) {
        if (gen !== root._gen)
            return;
        root._emit({ type: "error", code: code, message: message || "", id: null });
        root.stop();
    }

    // Wrong password or rejected tokens: next start reads credentials and logs in again.
    function _forget() {
        root._user = root._pass = root._access = root._refresh = "";
        root._expires = root._refreshExpires = 0;
    }

    // ---- command queue -------------------------------------------------------------

    // Everything queued while a request is in flight runs as one: sets merge in order
    // (last value wins), so rapid clicks cost one gateway round trip instead of one each.
    function _drain() {
        if (!root.running || root.once || root._busy || root._queue.length === 0 || root._access === "")
            return;
        var batch = root._queue;
        root._queue = [];
        var ids = [], props = {};
        batch.forEach(function (c) {
            if (c.set) {
                ids.push(c.id);
                for (var k in c.set)
                    props[k] = String(c.set[k]);
            }
        });
        root._busy = true;
        var gen = root._gen;
        var finish = function (msgs) {
            if (gen !== root._gen)
                return;
            root._busy = false;
            msgs.forEach(root._emit);
            if (msgs.some(m => m.type === "error" && m.code === "auth")) {
                root.stop();
                return;
            }
            _poll.restart();
            root._drain();
        };
        if (ids.length === 0) {
            root._fetch(gen, m => finish([m]));
            return;
        }
        if (root._puid === "") {
            finish(ids.map(i => ({ type: "error", code: "no_device", message: "", id: i })));
            return;
        }
        root._gateway(gen, "POST", CL.UPDATE_URL, { puid: root._puid, properties: props }, function (err) {
            if (err) {
                finish(ids.map(i => ({ type: "error", code: err.code === "auth" ? "auth" : "command", message: err.message, id: i })));
                return;
            }
            root._later(gen, root.setDelay, function () {
                root._fetch(gen, m => finish(ids.map(i => ({ type: "ack", id: i })).concat([m])));
            });
        });
    }

    property Timer _poll: Timer {
        interval: root.interval
        onTriggered: {
            if (!root._busy)
                root.send({ refresh: true });
        }
    }

    function _later(gen, ms, fn) {
        var t = _timerComp.createObject(root, { interval: ms });
        t.triggered.connect(function () {
            t.destroy();
            if (gen === root._gen)
                fn();
        });
        t.start();
    }

    property Component _timerComp: Component {
        Timer {}
    }

    // ---- appliance state -------------------------------------------------------------

    // Always calls back with one message (state or error); never fails silently.
    function _fetch(gen, cb) {
        root._gateway(gen, "GET", CL.DEVICE_LIST_URL, {}, function (err, resp) {
            if (err) {
                cb({ type: "error", code: err.code, message: err.message, id: null });
                return;
            }
            var list = resp.deviceList;
            if (!Array.isArray(list)) {
                cb({ type: "error", code: "network", message: "missing deviceList", id: null });
                return;
            }
            var ac = CL.pickAppliance(list);
            if (!ac) {
                cb({ type: "error", code: "no_device", message: "", id: null });
                return;
            }
            root._puid = ac.puid;
            cb({
                type: "state",
                online: ac.offlineState === 1,
                props: CL.convertStatus(ac.statusList || {}),
                ts: Math.floor(Date.now() / 1000)
            });
        });
    }

    // ---- gateway ---------------------------------------------------------------------

    // Signed request; retries once with a fresh login on a rejected token and once with a
    // fresh nonce on a randStr rejection, like the library.
    function _gateway(gen, method, url, payload, cb, retried) {
        retried = retried || {};
        root._withToken(gen, function () {
            var data = Object.assign(CL.gatewayBase(root._access, Date.now(), CL.randHex(16)), payload);
            root._sign(gen, CL.signingString(data), function (sign) {
                data.sign = sign;
                var opts = method === "GET" ? { query: data } : { json: data };
                root._xhr(gen, method, url, opts, function (err, body) {
                    if (err) {
                        cb(err);
                        return;
                    }
                    var resp = body.response;
                    if (!resp || typeof resp !== "object") {
                        cb({ code: "network", message: "missing response" });
                        return;
                    }
                    var rc = resp.resultCode;
                    if (rc === 0 || rc === "0" || rc === undefined || rc === null) {
                        cb(null, resp);
                        return;
                    }
                    var ec = Number(resp.errorCode);
                    if (ec === CL.INVALID_ACCESS_TOKEN && !retried.token) {
                        root._access = "";
                        root._expires = 0;
                        root._gateway(gen, method, url, payload, cb, { token: true, rand: retried.rand });
                    } else if (ec === CL.RANDSTR_CHECK_FAILED && !retried.rand) {
                        root._gateway(gen, method, url, payload, cb, { token: retried.token, rand: true });
                    } else {
                        cb({ code: ec === CL.INVALID_ACCESS_TOKEN ? "auth" : "network", message: "code=" + resp.errorCode + " " + (resp.errorDesc || "") });
                    }
                });
            });
        });
    }

    function _sign(gen, text, cb) {
        root._run(gen, ["sh", "-c", "openssl dgst -sha256 -binary | openssl pkeyutl -encrypt -pubin -inkey \"$1\" -pkeyopt rsa_padding_mode:pkcs1 | base64 -w0", "sh", root._pem], text, function (code, out, errText) {
            if (code !== 0 || out.trim() === "") {
                root._fail(gen, "no_openssl", errText.trim());
                return;
            }
            cb(out.trim());
        });
    }

    // ---- tokens ----------------------------------------------------------------------

    function _withToken(gen, cb) {
        var now = Date.now();
        if (root._access !== "" && now < root._expires) {
            cb();
            return;
        }
        if (root._refresh !== "" && (root._refreshExpires === 0 || now < root._refreshExpires)) {
            root._tokenRequest(gen, { grant_type: "refresh_token", refresh_token: root._refresh }, function (err) {
                if (err)
                    root._login(gen, cb); // refresh failed: full login, as the library does
                else
                    cb();
            });
            return;
        }
        root._login(gen, cb);
    }

    // Gigya login -> JWT -> OAuth code -> tokens.
    function _login(gen, cb) {
        root._access = root._refresh = "";
        root._xhr(gen, "POST", CL.LOGIN_URL, { form: { loginID: root._user, password: root._pass, APIKey: CL.GIGYA_API_KEY } }, function (err, body) {
            if (err)
                return root._fail(gen, err.code, err.message);
            if (body.errorCode || body.errorMessage || body.errorDetails) {
                var pending = body.errorCode === CL.GIGYA_PENDING_REGISTRATION ? " (accept the updated terms in the ConnectLife app)" : "";
                return root._fail(gen, "auth", (body.errorMessage || body.errorDetails || ("code " + body.errorCode)) + pending);
            }
            var uid = body.UID, cookie = body.sessionInfo && body.sessionInfo.cookieValue;
            if (!uid || !cookie)
                return root._fail(gen, "auth", "unexpected login response");
            root._xhr(gen, "POST", CL.JWT_URL, { form: { APIKey: CL.GIGYA_API_KEY, login_token: cookie } }, function (err2, jwt) {
                if (err2 || !jwt.id_token)
                    return root._fail(gen, err2 ? err2.code : "auth", err2 ? err2.message : "missing id_token");
                var auth = { client_id: CL.CLIENT_ID, redirect_uri: CL.REDIRECT_URI, idToken: jwt.id_token, response_type: "code", thirdType: "CDC", thirdClientId: uid };
                root._xhr(gen, "POST", CL.AUTHORIZE_URL, { json: auth }, function (err3, code) {
                    if (err3 || !code.code)
                        return root._fail(gen, err3 ? err3.code : "auth", err3 ? err3.message : "missing code");
                    root._tokenRequest(gen, { grant_type: "authorization_code", code: code.code }, function (err4) {
                        if (err4)
                            return root._fail(gen, err4.code, err4.message);
                        cb();
                    });
                });
            });
        });
    }

    function _tokenRequest(gen, grant, cb) {
        var form = Object.assign({ client_id: CL.CLIENT_ID, client_secret: CL.CLIENT_SECRET, redirect_uri: CL.REDIRECT_URI }, grant);
        root._xhr(gen, "POST", CL.TOKEN_URL, { form: form }, function (err, body) {
            if (err || !body.access_token || !body.expires_in) {
                cb(err || { code: "auth", message: "missing access_token" });
                return;
            }
            root._access = body.access_token;
            root._expires = Date.now() + (Number(body.expires_in) - 90) * 1000; // renew 90s early
            if (body.refresh_token)
                root._refresh = body.refresh_token;
            root._refreshExpires = CL.parseExpiry(body.refreshTokenExpiredTime);
            cb(null);
        });
    }

    // ---- credentials -----------------------------------------------------------------

    property CredentialSource _creds: CredentialSource {
        keyringService: "connectlife"
        envPathVar: "ZESIS_AIRCON_ENV"
        envFileName: "aircon.env"
        userVar: "CL_USER"
        passVar: "CL_PASS"
    }

    function _credentials(gen, cb) {
        if (root._user !== "" && root._pass !== "")
            return cb();
        root._creds.load(function (err, c) {
            if (gen !== root._gen)
                return;
            if (err)
                return root._fail(gen, err.code, err.message);
            root._user = c.user;
            root._pass = c.pass;
            cb();
        });
    }

    // ---- plumbing --------------------------------------------------------------------

    property ProcessRunner _runner: ProcessRunner {}

    // Callbacks from a run that stop() has since ended are dropped.
    function _run(gen, command, stdinText, cb) {
        root._runner.run(command, stdinText, function (code, out, err) {
            if (gen === root._gen)
                cb(code, out, err);
        });
    }

    // opts: {form}, {json} or {query}. Calls back (err, parsedJson); err = {code, message}.
    function _xhr(gen, method, url, opts, cb) {
        var xhr = new XMLHttpRequest();
        if (opts.query)
            url += "?" + CL.formEncode(opts.query);
        xhr.open(method, url);
        var body = null;
        if (opts.form) {
            xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
            body = CL.formEncode(opts.form);
        } else if (opts.json) {
            xhr.setRequestHeader("Content-Type", "application/json");
            body = JSON.stringify(opts.json);
        }
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE || gen !== root._gen)
                return;
            // 0 = no response at all; 5xx is transient. Anything else on these endpoints
            // means the credentials or tokens were refused.
            if (xhr.status === 0 || xhr.status >= 500)
                return cb({ code: "network", message: "HTTP " + xhr.status });
            if (xhr.status !== 200)
                return cb({ code: url.indexOf(CL.GATEWAY) === 0 ? "network" : "auth", message: "HTTP " + xhr.status });
            var parsed;
            try {
                parsed = JSON.parse(xhr.responseText);
            } catch (e) {
                return cb({ code: "network", message: "invalid JSON" });
            }
            cb(null, parsed);
        };
        xhr.send(body);
    }
}
