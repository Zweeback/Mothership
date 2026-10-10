#!/usr/bin/env bash
set -euo pipefail

readonly STACK_DIR="${IRL_STACK_DIR:-/opt/irl-stack}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SECRETS_FILE="${STACK_DIR}/runtime-secrets.env"
readonly SOURCE_FILE="${STACK_DIR}/gopro-source.env"
readonly MUXSHED_DIR="${STACK_DIR}/muxshed"
readonly MUXSHED_API_URL="http://127.0.0.1:8080/api/v1"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl git jq openssl ufw docker.io docker-compose-plugin
systemctl enable --now docker

install -d -m 0755 "${STACK_DIR}"
install -m 0755 "${SCRIPT_DIR}/verify.sh" "${STACK_DIR}/verify.sh"
if [ ! -d "${MUXSHED_DIR}/.git" ]; then
  git clone --depth 1 https://github.com/muxshed/shed.git "${MUXSHED_DIR}"
else
  git -C "${MUXSHED_DIR}" pull --ff-only
fi

umask 077
if [ -f "${SECRETS_FILE}" ]; then
  # shellcheck disable=SC1090
  source "${SECRETS_FILE}"
else
  MUXSHED_API_KEY="mxs_$(openssl rand -hex 24)"
  printf 'MUXSHED_API_KEY=%s\n' "${MUXSHED_API_KEY}" > "${SECRETS_FILE}"
fi
chmod 600 "${SECRETS_FILE}"

if [[ ! "${MUXSHED_API_KEY:-}" =~ ^mxs_[0-9a-f]{48}$ ]]; then
  echo "Refusing to start: ${SECRETS_FILE} does not contain a valid generated API key."
  exit 1
fi
export MUXSHED_API_KEY

cat > "${MUXSHED_DIR}/docker/docker-compose.override.yml" <<EOF
services:
  muxshed:
    env_file:
      - ${SECRETS_FILE}
EOF

ufw allow OpenSSH || true
ufw allow 1935/tcp
ufw allow 9000/udp
ufw --force enable || true

cd "${MUXSHED_DIR}/docker"
docker compose up -d --build

echo "Waiting for authenticated Muxshed API..."
api_ready=0
for _attempt in $(seq 1 90); do
  if curl -fsS -H "X-API-Key: ${MUXSHED_API_KEY}" "${MUXSHED_API_URL}/status" >/dev/null; then
    api_ready=1
    break
  fi
  sleep 2
done
if [ "${api_ready}" -ne 1 ]; then
  echo "Muxshed API did not become ready within 180 seconds."
  docker compose ps || true
  docker compose logs --tail=80 muxshed || true
  exit 1
fi

STREAM_KEY=""
if [ -f "${SOURCE_FILE}" ]; then
  # shellcheck disable=SC1090
  source "${SOURCE_FILE}"
  STREAM_KEY="${GOPRO_STREAM_KEY:-}"
fi

if [[ ! "${STREAM_KEY}" =~ ^[A-Za-z0-9_-]{8,}$ ]]; then
  SOURCE_JSON='{"name":"GoPro HERO13","kind":{"type":"rtmp","stream_key":""}}'
  SOURCE_RESPONSE="$(curl -fsS -X POST \
    -H "X-API-Key: ${MUXSHED_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "${SOURCE_JSON}" \
    "${MUXSHED_API_URL}/sources")"
  STREAM_KEY="$(printf '%s' "${SOURCE_RESPONSE}" | jq -er '.kind.stream_key | select(type == "string" and length > 0)')"
  printf 'GOPRO_STREAM_KEY=%s\nGOPRO_RTMP_PATH=/live/%s\n' "${STREAM_KEY}" "${STREAM_KEY}" > "${SOURCE_FILE}"
fi
chmod 600 "${SOURCE_FILE}"

cat <<EOF

MUXSHED IS UP.

Open the control UI through an SSH tunnel (the API key remains on the host):
  ssh -L 8080:127.0.0.1:8080 root@<SERVER_IP>
  http://127.0.0.1:8080

GoPro custom RTMP target:
  rtmp://<SERVER_IP>:1935/live/${STREAM_KEY}

Runtime credentials (mode 600):
  ${SECRETS_FILE}
  ${SOURCE_FILE}

Verify:
  ${STACK_DIR}/verify.sh

EOF
