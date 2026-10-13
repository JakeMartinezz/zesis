// Helpers for zesis's secret env files (aircon.env, tapo.env). Plain JS with no QML
// types, so it also runs under node for tests: `node widgets/shared/envfile_test.js`.

// KEY=VALUE lines into an object; tolerates comments, `export` and quotes.
function parseEnv(text) {
    var values = {};
    (text || "").split("\n").forEach(function (line) {
        line = line.trim();
        if (!line || line[0] === "#" || line.indexOf("=") < 0)
            return;
        if (line.indexOf("export ") === 0)
            line = line.slice(7);
        var i = line.indexOf("=");
        var key = line.slice(0, i).trim();
        var value = line.slice(i + 1).trim();
        if (value.length >= 2 && value[0] === value[value.length - 1] && (value[0] === "'" || value[0] === '"'))
            value = value.slice(1, -1);
        values[key] = value;
    });
    return values;
}

// `mode` is the octal string from `stat -c %a`. Same rule ssh uses for private keys.
function envTooOpen(mode) {
    return (parseInt(mode, 8) & 63) !== 0; // 63 = 0o077
}

if (typeof module !== "undefined")
    module.exports = { parseEnv: parseEnv, envTooOpen: envTooOpen };
