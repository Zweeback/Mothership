#!/usr/bin/env bash
set -euo pipefail

readonly STACK_DIR="${IRL_STACK_DIR:-/opt/irl-stack}"
readonly SECRETS_FILE="${STACK_DIR}/runtime-secrets.env"
readonly SOURCE_FILE="${STACK_DIR}/gopro-source.env"

for secret_file in "${SECRETS_FILE}" "${SOURCE_FILE}"; do
  if [ ! -f "${secret_file}" ]; then
    echo "Missing runtime file: ${secret_file}"
    exit 1
  fi
  if [ "$(stat -c '%a' "${secret_file}")" != "600" ]; then
    echo "Unsafe permissions on ${secret_file}; expected 600."
    exit 1
  fi
done

# shellcheck disable=SC1090
source "${SECRETS_FILE}"
if [[ ! "${MUXSHED_API_KEY:-}" =~ ^mxs_[0-9a-f]{48}$ ]]; then
  echo "Invalid Muxshed API key file."
  exit 1
fi

echo "=== containers ==="
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo
echo "=== listeners ==="
ss -lntup | grep -E ':(1935|8080|8443|9000)' || true
echo
echo "=== authenticated Muxshed API ==="
curl -fsS -H "X-API-Key: ${MUXSHED_API_KEY}" http://127.0.0.1:8080/api/v1/status | jq .
