#!/usr/bin/env bash
set -euo pipefail

LOCAL_RTMP_PORT="\${1:-1935}"

if ! command -v ssh >/dev/null 2>&1; then
  echo "OpenSSH client is required."
  exit 1
fi

echo "Opening a temporary free raw-TCP tunnel to local RTMP port \${LOCAL_RTMP_PORT}."
echo "Pinggy free tunnels expire after 60 minutes and the public host/port changes on reconnect."
echo
echo "When Pinggy prints:"
echo "  tcp://HOST:PORT"
echo "use this GoPro base:"
echo "  rtmp://HOST:PORT/live/<MUXSHED_STREAM_KEY>"
echo

exec ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ServerAliveInterval=20 \
  -o ServerAliveCountMax=3 \
  -o ExitOnForwardFailure=yes \
  -p 443 \
  -R0:127.0.0.1:\${LOCAL_RTMP_PORT} \
  tcp@free.pinggy.io
