// Run: node widgets/aircon/connectlife_test.js (no network, no QML)
const assert = require("assert");
const cl = require("./connectlife.js");

// Signing string must match the Python library byte for byte: sorted keys, `sign`
// excluded, nested objects as compact JSON in insertion order, suffix appended.
// Expected value produced by connectlife's _sign_gateway_request input for this payload.
const data = Object.assign(cl.gatewayBase("tok", 1700000000000, "ab".repeat(16)), {
    puid: "p1",
    properties: { t_power: "1", t_temp: "23" },
    sign: "ignored"
});
assert.strictEqual(cl.signingString(data),
    "accessToken=tok&appId=47110565134383&appSecret=yOzhz6junYno-nmULM3Wr7PU_dpSZN22ZdluvVWZ4uW5ZwwG8fIGCHTbrhcnU-iv" +
    "&languageId=12&properties={\"t_power\":\"1\",\"t_temp\":\"23\"}&puid=p1&randStr=" + "ab".repeat(16) +
    "&timeStamp=1700000000000&timezone=1.0&version=5.0D9519A4B756946F081B7BB5B5E8D1197");

assert.deepStrictEqual(cl.convertStatus({ a: "1", b: "-2", c: "1.5", d: "x", e: "" }), { a: 1, b: -2, c: 1.5, d: "x", e: "" });

assert.strictEqual(cl.pickAppliance([{ deviceTypeCode: "026", deviceId: "f" }, { deviceTypeCode: "009", deviceId: "a" }]).deviceId, "a");
assert.strictEqual(cl.pickAppliance([{ deviceTypeCode: "026", deviceId: "f" }]), null);

assert.strictEqual(cl.parseExpiry(1700000000000), 1700000000000);
assert.strictEqual(cl.parseExpiry("1700000000000"), 1700000000000);
assert.strictEqual(cl.parseExpiry("2026-01-01T00:00:00Z"), Date.parse("2026-01-01T00:00:00Z"));
assert.strictEqual(cl.parseExpiry(undefined), 0);

assert.strictEqual(cl.formEncode({ a: "x y", b: "&" }), "a=x%20y&b=%26");
assert.match(cl.randHex(16), /^[0-9a-f]{32}$/);

console.log("ok connectlife");
