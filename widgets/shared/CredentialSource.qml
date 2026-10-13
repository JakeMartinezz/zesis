import QtQuick
import Quickshell
import "envfile.js" as Env

// Where a cloud/LAN widget gets its login: the Secret Service keyring first
// (secret-tool, service=keyringService, keys "user"/"pass"), then an env file
// ($envPathVar, else ~/.config/zesis/<envFileName>) that only its owner can read.
// The env file's other keys come back in `vars` (e.g. TAPO_HOSTS) even when the login
// itself came from the keyring.
//
// load(cb): cb(null, {user, pass, vars}) or cb({code, message}) with code one of
// no_credentials, no_keyring, locked, env_perms.
QtObject {
    id: root

    property string keyringService: ""
    property string envPathVar: ""
    property string envFileName: ""
    property string userVar: ""
    property string passVar: ""

    readonly property string envPath: Quickshell.env(envPathVar) || ((Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/zesis/" + envFileName)

    property ProcessRunner _runner: ProcessRunner {}

    function load(cb) {
        var lookup = key => ["timeout", "30", "secret-tool", "lookup", "service", root.keyringService, "key", key];
        root._runner.run(lookup("user"), null, function (c1, user, e1) {
            root._runner.run(lookup("pass"), null, function (c2, pass) {
                var keyringCode = "no_credentials";
                if (c1 === 124 || c2 === 124)
                    keyringCode = "locked";
                else if (c1 === 127 || c2 === 127 || (c1 !== 0 && e1.trim() !== ""))
                    keyringCode = "no_keyring"; // missing secret-tool, or no Secret Service
                var fromKeyring = user.trim() !== "" && pass.trim() !== "" ? { user: user.trim(), pass: pass.trim() } : null;
                root._readEnvFile(function (err, vars) {
                    if (fromKeyring)
                        return cb(null, { user: fromKeyring.user, pass: fromKeyring.pass, vars: vars || {} });
                    if (err && err.code === "env_perms")
                        return cb(err);
                    if (!vars || !vars[root.userVar] || !vars[root.passVar])
                        return cb({ code: keyringCode, message: "" });
                    cb(null, { user: vars[root.userVar], pass: vars[root.passVar], vars: vars });
                });
            });
        });
    }

    // cb(null, vars) | cb(null, null) when there is no file | cb({code: "env_perms"})
    function _readEnvFile(cb) {
        var path = root.envPath;
        root._runner.run(["stat", "-c", "%a", "--", path], null, function (code, mode) {
            if (code !== 0)
                return cb(null, null);
            if (Env.envTooOpen(mode.trim()))
                return cb({ code: "env_perms", message: path });
            root._runner.run(["cat", "--", path], null, function (c2, text) {
                if (c2 !== 0)
                    return cb({ code: "env_perms", message: path }); // e.g. still owned by root
                cb(null, Env.parseEnv(text));
            });
        });
    }
}
