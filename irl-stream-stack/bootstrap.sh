#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl git jq openssl ufw docker.io docker-compose-plugin
systemctl enable --now docker

install -d -m 0755 /opt/irl-stack
cd /opt/irl-stack

if [ ! -d muxshed/.git ]; then
  git clone --depth 1 https://github.com/muxshed/shed.git muxshed
else
  git -C muxshed pull --ff-only
fi

MUXSHED_API_KEY="mxs_$(openssl rand -hex 24)"
cat > /opt/irl-stack/runtime-secrets.env <<EOF
MUXSHED_API_KEY=\${MUXSHED_API_KEY}
EOF
chmod 600 /opt/irl-stack/runtime-secrets.env

cat > /opt/irl-stack/muxshed/docker/docker-compose.override.yml <<EOF
services:
  muxshed:
    environment:
      - MUXSHED_API_KEY=\${MUXSHED_API_KEY}
EOF

ufw allow OpenSSH || true
ufw allow 1935/tcp
ufw allow 8080/tcp
ufw allow 8443/tcp
ufw allow 9000/udp
ufw --force enable || true

cd /opt/irl-stack/muxshed/docker
docker compose up -d --build

echo "Waiting for Muxshed API..."
for i in $(seq 1 90); do
  if curl -fsS -H "X-API-Key: \${MUXSHED_API_KEY}" http://127.0.0.1:8080/api/v1/status >/dev/null; then
    break
  fi
  sleep 2
done

SOURCE_JSON='{"name":"GoPro HERO13","kind":{"type":"rtmp","stream_key":""}}'
SOURCE_RESPONSE="$(curl -fsS -X POST \
  -H "X-API-Key: \${MUXSHED_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "\${SOURCE_JSON}" \
  http://127.0.0.1:8080/api/v1/sources)"
STREAM_KEY="$(printf '%s' "\${SOURCE_RESPONSE}" | jq -r '.kind.stream_key')"

if [ -z "\${STREAM_KEY}" ] || [ "\${STREAM_KEY}" = "null" ]; then
  echo "Muxshed started, but automatic RTMP source creation failed."
  echo "Response: \${SOURCE_RESPONSE}"
  exit 1
fi

cat > /opt/irl-stack/gopro-source.env <<EOF
MUXSHED_API_KEY=\${MUXSHED_API_KEY}
GOPRO_STREAM_KEY=\${STREAM_KEY}
GOPRO_RTMP_PATH=/live/\${STREAM_KEY}
EOF
chmod 600 /opt/irl-stack/gopro-source.env

cat <<EOF

MUXSHED IS UP.

Web UI:
  http://<SERVER_IP>:8080

GoPro custom RTMP target:
  rtmp://<SERVER_IP>:1935/live/\${STREAM_KEY}

API key and source key are stored only on this host:
  /opt/irl-stack/runtime-secrets.env
  /opt/irl-stack/gopro-source.env

Verify:
  docker compose ps
  curl -H "X-API-Key: \${MUXSHED_API_KEY}" http://127.0.0.1:8080/api/v1/status

Next:
  Open the web UI, add Twitch / YouTube / Kick destinations, then Go Live.

EOF
