#!/bin/bash
# Creates a local, self-signed code-signing identity in its OWN keychain, so every rebuild keeps the
# same code identity. macOS then keeps the Accessibility permission across rebuilds.
# No Apple Developer account needed. The certificate is for local development only, never distributed.
set -euo pipefail

NAME="Pastu Local Dev"
KC="$HOME/Library/Keychains/pastu-dev.keychain-db"
PW="pastu-dev"   # throwaway: protects only a local dev certificate, not a secret

if [ -f "$KC" ] && security find-identity -p codesigning "$KC" 2>/dev/null | grep -q "$NAME"; then
    echo "Signing identity '$NAME' already exists."
    exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/openssl.cnf" <<CONF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CONF

/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$tmp/key.pem" -out "$tmp/cert.pem" -config "$tmp/openssl.cnf" 2>/dev/null
/usr/bin/openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" \
    -out "$tmp/id.p12" -passout "pass:$PW"

[ -f "$KC" ] || security create-keychain -p "$PW" "$KC"
security set-keychain-settings "$KC"            # never auto-lock
security unlock-keychain -p "$PW" "$KC"
security import "$tmp/id.p12" -k "$KC" -P "$PW" -T /usr/bin/codesign >/dev/null
# Lets codesign use the key without a GUI prompt.
security set-key-partition-list -S apple-tool:,apple: -s -k "$PW" "$KC" >/dev/null

echo "Created signing identity '$NAME' in $KC"
security find-identity -p codesigning "$KC"
