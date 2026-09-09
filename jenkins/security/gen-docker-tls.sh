#!/usr/bin/env bash
# Set up TLS for a Docker host's remote API so the Jenkins controller connects
# over TCP 2376 securely (server + client certs). Run on the Docker host.
#   usage: ./gen-docker-tls.sh <docker-host-fqdn-or-ip>
# Expects openssl. Writes certs under /etc/docker/tls (server) and
# ./docker-client-tls (for import into Jenkins as the docker-host credentials).
set -euo pipefail

HOST="${1:?usage: gen-docker-tls.sh <docker-host-fqdn-or-ip>}"
SERVER_DIR="${SERVER_DIR:-/etc/docker/tls}"
CLIENT_DIR="${CLIENT_DIR:-./docker-client-tls}"
CERT_DAYS="${CERT_DAYS:-365}"
BITS=4096

umask 077
mkdir -p "$SERVER_DIR" "$CLIENT_DIR"

# --- local CA ---
openssl genrsa -out "$SERVER_DIR/ca-key.pem" "$BITS"
openssl req -x509 -new -nodes -key "$SERVER_DIR/ca-key.pem" \
  -sha256 -days "$CERT_DAYS" -subj "/CN=docker-ca" \
  -out "$SERVER_DIR/ca.pem"

# --- server key + CSR (SAN covers IP and hostname) ---
openssl genrsa -out "$SERVER_DIR/server-key.pem" "$BITS"
openssl req -new -key "$SERVER_DIR/server-key.pem" -subj "/CN=$HOST" \
  -out "$SERVER_DIR/server.csr"
cat > "$SERVER_DIR/extfile.cnf" <<EOF
subjectAltName = DNS:$HOST,IP:$HOST
extendedKeyUsage = serverAuth
EOF
openssl x509 -req -in "$SERVER_DIR/server.csr" \
  -CA "$SERVER_DIR/ca.pem" -CAkey "$SERVER_DIR/ca-key.pem" -CAcreateserial \
  -out "$SERVER_DIR/server-cert.pem" -days "$CERT_DAYS" -sha256 \
  -extfile "$SERVER_DIR/extfile.cnf"

# --- client key + cert (for the Jenkins controller / docker CLI) ---
openssl genrsa -out "$SERVER_DIR/client-key.pem" "$BITS"
openssl req -new -key "$SERVER_DIR/client-key.pem" -subj "/CN=client" \
  -out "$SERVER_DIR/client.csr"
cat > "$SERVER_DIR/client-extfile.cnf" <<EOF
extendedKeyUsage = clientAuth
EOF
openssl x509 -req -in "$SERVER_DIR/client.csr" \
  -CA "$SERVER_DIR/ca.pem" -CAkey "$SERVER_DIR/ca-key.pem" -CAcreateserial \
  -out "$SERVER_DIR/client-cert.pem" -days "$CERT_DAYS" -sha256 \
  -extfile "$SERVER_DIR/client-extfile.cnf"

# --- package the client bundle ---
cp "$SERVER_DIR/ca.pem" "$CLIENT_DIR/ca.pem"
cp "$SERVER_DIR/client-cert.pem" "$CLIENT_DIR/cert.pem"
cp "$SERVER_DIR/client-key.pem" "$CLIENT_DIR/key.pem"

rm -f "$SERVER_DIR"/*.csr "$SERVER_DIR"/*extfile*.cnf
chmod 444 "$SERVER_DIR/ca.pem" "$SERVER_DIR/server-cert.pem"
chmod 400 "$SERVER_DIR/server-key.pem" "$CLIENT_DIR/key.pem"

echo "==> server certs: $SERVER_DIR  (daemon needs TLS on tcp://0.0.0.0:2376)"
echo "==> client bundle: $CLIENT_DIR (upload ca.pem/cert.pem/key.pem to Jenkins)"
echo "    Set daemon.json: tlsverify + tlscacert/tlscert/tlskey, then restart docker."
