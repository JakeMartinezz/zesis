// Run: node widgets/shared/envfile_test.js
const assert = require("assert");
const env = require("./envfile.js");

assert.deepStrictEqual(env.parseEnv('# c\nexport CL_USER="me@x.com"\nCL_PASS=\'p=ss word\'\nOTHER=1\n'),
    { CL_USER: "me@x.com", CL_PASS: "p=ss word", OTHER: "1" });
assert.deepStrictEqual(env.parseEnv("CL_USER=a"), { CL_USER: "a" });
assert.deepStrictEqual(env.parseEnv(""), {});

assert.strictEqual(env.envTooOpen("600"), false);
assert.strictEqual(env.envTooOpen("644"), true);
assert.strictEqual(env.envTooOpen("660"), true);

console.log("ok envfile");
