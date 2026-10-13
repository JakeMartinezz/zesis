// Pure helpers for the ConnectLife (Hisense) cloud protocol, shared by AirconBackend.qml.
// Ported from the `connectlife` Python library (oyvindwe/connectlife, api.py). No QML
// types here so it also runs under node for tests: `node widgets/aircon/connectlife_test.js`.

var GIGYA_API_KEY = "4_yhTWQmHFpZkQZDSV1uV-_A";
var LOGIN_URL = "https://accounts.eu1.gigya.com/accounts.login";
var JWT_URL = "https://accounts.eu1.gigya.com/accounts.getJWT";
var AUTHORIZE_URL = "https://oauth.hijuconn.com/oauth/authorize";
var TOKEN_URL = "https://oauth.hijuconn.com/oauth/token";
var CLIENT_ID = "5065059336212";
var CLIENT_SECRET = "07swfKgvJhC3ydOUS9YV_SwVz0i4LKqlOLGNUukYHVMsJRF1b-iWeUGcNlXyYCeK";
var REDIRECT_URI = "https://api.connectlife.io/swagger/oauth2-redirect.html";

var GATEWAY = "https://clife-eu-gateway.hijuconn.com";
var DEVICE_LIST_URL = GATEWAY + "/clife-svc/pu/get_device_status_list";
var UPDATE_URL = GATEWAY + "/device/pu/property/set";
var APP_ID = "47110565134383";
var APP_SECRET = "yOzhz6junYno-nmULM3Wr7PU_dpSZN22ZdluvVWZ4uW5ZwwG8fIGCHTbrhcnU-iv";
var SIGN_SUFFIX = "D9519A4B756946F081B7BB5B5E8D1197";
var INVALID_ACCESS_TOKEN = 100026;
var RANDSTR_CHECK_FAILED = 101005;
var GIGYA_PENDING_REGISTRATION = 206001;
var AC_TYPE = "009";

// Gateway request fields before signing (the caller adds the payload on top).
function gatewayBase(accessToken, nowMs, randStr) {
    return {
        accessToken: accessToken,
        appId: APP_ID,
        appSecret: APP_SECRET,
        languageId: "12",
        randStr: randStr,
        timeStamp: String(nowMs),
        timezone: "1.0",
        version: "5.0"
    };
}

// The string whose SHA-256 gets RSA-encrypted into `sign`: sorted key=value pairs,
// nested objects as compact JSON, then the fixed suffix.
function signingString(data) {
    var keys = Object.keys(data).filter(function (k) {
        return k !== "sign";
    }).sort();
    var parts = keys.map(function (k) {
        var v = data[k];
        if (v !== null && typeof v === "object")
            v = JSON.stringify(v);
        return k + "=" + v;
    });
    return parts.join("&") + SIGN_SUFFIX;
}

function randHex(bytes) {
    var s = "";
    for (var i = 0; i < bytes * 2; i++)
        s += Math.floor(Math.random() * 16).toString(16);
    return s;
}

function formEncode(obj) {
    return Object.keys(obj).map(function (k) {
        return encodeURIComponent(k) + "=" + encodeURIComponent(obj[k]);
    }).join("&");
}

// Same conversion the library applies to statusList: int, then float, else the string.
function convertStatus(statusList) {
    var out = {};
    for (var k in statusList) {
        var v = statusList[k];
        if (typeof v === "string" && /^-?\d+$/.test(v.trim()))
            v = parseInt(v, 10);
        else if (typeof v === "string" && v.trim() !== "" && !isNaN(Number(v)))
            v = Number(v);
        out[k] = v;
    }
    return out;
}

function pickAppliance(deviceList) {
    for (var i = 0; i < deviceList.length; i++)
        if (deviceList[i].deviceTypeCode === AC_TYPE && deviceList[i].deviceId)
            return deviceList[i];
    return null;
}

// refreshTokenExpiredTime comes as epoch ms (number or digits) or an ISO string.
function parseExpiry(value) {
    if (value === undefined || value === null)
        return 0;
    if (typeof value === "number")
        return value;
    if (/^\d+$/.test(value))
        return parseInt(value, 10);
    var t = Date.parse(value);
    return isNaN(t) ? 0 : t;
}

if (typeof module !== "undefined")
    module.exports = { gatewayBase: gatewayBase, signingString: signingString, formEncode: formEncode, convertStatus: convertStatus, pickAppliance: pickAppliance, parseExpiry: parseExpiry, randHex: randHex };
