#!/usr/bin/env bash
# Talk to a Tapo device on the LAN over KLAP v2 (needs "Third-Party Compatibility" on in
# the Tapo app; with it off, recent firmware only speaks TPAP).
#
# usage: tapo-klap.sh HOST
#   stdin: line 1 = TP-Link account email, line 2 = password, then one JSON request per
#          line, e.g. {"method":"get_device_info"}
#   stdout: one JSON line per request (the device's reply), or {"error":"<code>"} lines.
#   error codes: auth (wrong credentials), network (unreachable/timeout), protocol.
# Credentials and requests go through stdin, never argv. Needs bash, curl, openssl, od.
#
# Protocol (python-kasa KlapTransportV2 / KlapEncryptionSession):
#   auth  = sha256(sha1(user) + sha1(pass))
#   h1    POST /app/handshake1 <- local(16)   -> remote(16) + sha256(local+remote+auth)
#   h2    POST /app/handshake2 <- sha256(remote+local+auth)        (TP_SESSIONID cookie)
#   key = sha256("lsk"+local+remote+auth)[:16]   sig = sha256("ldk"+...)[:28]
#   iv  = sha256("iv"+...): first 12 bytes + seq (last 4 bytes, signed BE, +1 per request)
#   req POST /app/request?seq=N <- sha256(sig+seq+ct) + AES-128-CBC(key, iv, json)
set -uo pipefail
host=$1
command -v openssl >/dev/null || { printf '{"error":"no_openssl"}\n'; exit 1; }
command -v curl >/dev/null || { printf '{"error":"no_curl"}\n'; exit 1; }
dir=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/tapo.XXXXXX") || exit 1
chmod 700 "$dir"
trap 'rm -rf "$dir"' EXIT
cd "$dir" || exit 1

fail() { printf '{"error":"%s"}\n' "$1"; exit 1; }
hex() { od -An -v -tx1 "$1" | tr -d ' \n'; }
unhex() { printf '%b' "$(sed 's/../\\x&/g' <<<"$1")"; }
sha256() { openssl dgst -sha256 -binary; }
post() { # url infile outfile -> http status
    curl -s -m 4 -b cookie -c cookie -H 'Content-Type: application/octet-stream' \
        --data-binary @"$2" -o "$3" -w '%{http_code}' "http://$host$1"
}

IFS= read -r user || fail auth
IFS= read -r pass || fail auth
{ printf %s "$user" | openssl dgst -sha1 -binary; printf %s "$pass" | openssl dgst -sha1 -binary; } | sha256 >auth

head -c16 /dev/urandom >local
code=$(post /app/handshake1 local h1) || fail network
[ "$code" = 200 ] || fail protocol
[ "$(stat -c %s h1)" = 48 ] || fail protocol
head -c16 h1 >remote
tail -c32 h1 >server_hash
cat local remote auth | sha256 >expect
cmp -s expect server_hash || fail auth

cat remote local auth | sha256 >h2body
code=$(post /app/handshake2 h2body h2) || fail network
[ "$code" = 200 ] || fail auth

key=$({ printf lsk; cat local remote auth; } | sha256 | head -c16 | od -An -v -tx1 | tr -d ' \n')
{ printf ldk; cat local remote auth; } | sha256 | head -c28 >sig
ivfull=$({ printf iv; cat local remote auth; } | sha256 | od -An -v -tx1 | tr -d ' \n')
iv12=${ivfull:0:24}
seq=$((16#${ivfull:56:8}))
((seq >= 2147483648)) && seq=$((seq - 4294967296))

while IFS= read -r request; do
    [ -n "$request" ] || continue
    seq=$((seq + 1))
    seqhex=$(printf '%08x' $((seq & 0xffffffff)))
    printf %s "$request" | openssl enc -aes-128-cbc -K "$key" -iv "$iv12$seqhex" >ct
    { cat sig; unhex "$seqhex"; cat ct; } | sha256 >sigout
    cat sigout ct >body
    code=$(post "/app/request?seq=$seq" body reply) || { printf '{"error":"network"}\n'; continue; }
    if [ "$code" != 200 ]; then
        printf '{"error":"%s"}\n' "$([ "$code" = 403 ] && echo auth || echo protocol)"
        continue
    fi
    tail -c +33 reply | openssl enc -d -aes-128-cbc -K "$key" -iv "$iv12$seqhex" || printf '{"error":"protocol"}'
    printf '\n'
done
