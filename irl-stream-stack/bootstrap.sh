#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl git openssl ufw docker.io docker-compose-plugin
systemctl enable --now docker

install -d -m 0755 /opt/irl-stack
cd /opt/irl-stack

if [ ! -d muxshed/.git ]; then
  git clone --depth 1 https://github.com/muxshed/shed.git muxshed
else
  git -C muxshed pull --ff-only
fi

if [ ! -d ratonet/.git ]; then
  git clone --depth 1 https://github.com/Captando/RatoNet.git ratonet
else
  git -C ratonet pull --ff-only
fi

MUXSHED_API_KEY="mxs_$(openssl rand -hex 24)"
RATONET_ADMIN_TOKEN="$(openssl rand -hex 32)"
RATONET_SRT_PASSPHRASE="$(openssl rand -base64 24 | tr -d '\n' | tr '/+' 'AZ' | cut -c1-32)"

cat > /opt/irl-stack/runtime-secrets.env <<EOF
MUXSHED_API_KEY=\${MUXSHED_API_KEY}
RATONET_ADMIN_TOKEN=\${RATONET_ADMIN_TOKEN}
RATONET_SRT_PASSPHRASE=\${RATONET_SRT_PASSPHRASE}
EOF
chmod 600 /opt/irl-stack/runtime-secrets.env

cat > /opt/irl-stack/muxshed/docker/docker-compose.override.yml <<'EOF'
services:
  muxshed:
    environment:
      - MUXSHED_API_KEY=\${MUXSHED_API_KEY}
EOF

cat > /opt/irl-stack/muxshed/docker/.env <<EOF
MUXSHED_API_KEY=\${MUXSHED_API_KEY}
EOF
chmod 600 /opt/irl-stack/muxshed/docker/.env

cp /opt/irl-stack/ratonet/.env.example /opt/irl-stack/ratonet/.env
sed -i "s|^ADMIN_TOKEN=.*|ADMIN_TOKEN=\${RATONET_ADMIN_TOKEN}|" /opt/irl-stack/ratonet/.env
sed -i "s|^SRT_PASSPHRASE=.*|SRT_PASSPHRASE=\${RATONET_SRT_PASSPHRASE}|" /opt/irl-stack/ratonet/.env
sed -i "s|^CORS_ORIGINS=.*|CORS_ORIGINS=*|" /opt/irl-stack/ratonet/.env
chmod 600 /opt/irl-stack/ratonet/.env

ufw allow OpenSSH || true
ufw allow 1935/tcp
ufw allow 8080/tcp
ufw allow 8000/tcp
ufw allow 8443/tcp
ufw allow 9000/udp
ufw allow 5001/udp
ufw --force enable || true

cd /opt/irl-stack/muxshed/docker
docker compose up -d --build

cd /opt/irl-stack/ratonet
docker compose up -d --build

cat <<'EOF'

IRL stack started.

Muxshed UI/API:  http://<SERVER_IP>:8080
GoPro RTMP port: tcp/1935
RatoNet UI/API:  http://<SERVER_IP>:8000

Secrets saved locally:
  /opt/irl-stack/runtime-secrets.env

Next:
1. Open Muxshed UI and authenticate with the generated API key.
2. Create an RTMP source. Muxshed generates the stream key.
3. Add Twitch / YouTube / Kick destinations.
4. Use the generated RTMP publish URL in GoPro Quik.
5. Add RatoNet's GPS/map overlay as a browser source in Muxshed.
EOF
