#!/usr/bin/env bash
set -euo pipefail
echo "=== containers ==="
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo
echo "=== listeners ==="
ss -lntup | grep -E ':(1935|8080|8000|8443|9000|5001)' || true
echo
echo "=== muxshed local HTTP ==="
curl -fsS -o /dev/null -w 'HTTP %{http_code}\n' http://127.0.0.1:8080/ || true
echo
echo "=== ratonet local HTTP ==="
curl -fsS -o /dev/null -w 'HTTP %{http_code}\n' http://127.0.0.1:8000/ || true
