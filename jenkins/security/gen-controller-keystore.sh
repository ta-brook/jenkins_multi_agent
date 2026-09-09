#!/usr/bin/env bash
# Generate a PKCS12 keystore for Jenkins HTTPS (--httpsPort=8443).
# Run on a machine with JDK keytool (or inside the controller image).
#   usage: JENKINS_URL=https://ci.example.com ./gen-controller-keystore.sh
# Writes $OUT/keystore.p12 (chmod 600). Point the controller at it with:
#   JENKINS_OPTS="--httpsPort=8443 --httpsKeyStore=$OUT/keystore.p12 \
#                 --httpsKeyStorePassword=$KEYSTORE_PASSWORD"
set -euo pipefail

URL="${JENKINS_URL:?set JENKINS_URL e.g. https://ci.example.com}"
OUT="${OUT:-/var/jenkins_home/https}"
KEYSTORE_PASSWORD="${KEYSTORE_PASSWORD:?set KEYSTORE_PASSWORD}"
KEY_ALIAS="${KEY_ALIAS:-jenkins}"

HOST="$(printf '%s' "$URL" | sed -E 's#^https?://##; s#[:/].*##')"
if [ -z "$HOST" ]; then
  echo "could not derive hostname from JENKINS_URL=$URL" >&2
  exit 1
fi

mkdir -p "$OUT"

keytool -genkeypair -v \
  -alias "$KEY_ALIAS" \
  -keyalg RSA -keysize 3072 \
  -storetype PKCS12 \
  -keystore "$OUT/keystore.p12" \
  -storepass "$KEYSTORE_PASSWORD" \
  -keypass "$KEYSTORE_PASSWORD" \
  -dname "CN=$HOST, OU=jenkins-multi-agent, O=jenkins-multi-agent, L=, S=, C=" \
  -validity 365

chmod 600 "$OUT/keystore.p12"

echo "==> keystore written to $OUT/keystore.p12"
echo "    Controller env: JENKINS_OPTS=\"--httpsPort=8443 \\"
echo "        --httpsKeyStore=$OUT/keystore.p12 \\"
echo "        --httpsKeyStorePassword=...\""
