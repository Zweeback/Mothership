#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bootstrap="${repo_root}/bootstrap.sh"
verify="${repo_root}/verify.sh"
tunnel="${repo_root}/temporary-free-rtmp-tunnel.sh"

bash -n "${bootstrap}" "${verify}" "${tunnel}"

if grep -nF '\${' "${bootstrap}" "${verify}"; then
  echo "Escaped shell-variable syntax would turn runtime values into literals."
  exit 1
fi

grep -q 'umask 077' "${bootstrap}"
grep -q 'install -m 0755 "${SCRIPT_DIR}/verify.sh" "${STACK_DIR}/verify.sh"' "${bootstrap}"
grep -q 'chmod 600 "${SECRETS_FILE}"' "${bootstrap}"
grep -q 'chmod 600 "${SOURCE_FILE}"' "${bootstrap}"
grep -q 'X-API-Key: ${MUXSHED_API_KEY}' "${bootstrap}"
grep -q 'api_ready' "${bootstrap}"

if grep -Eq 'ufw allow (8080|8443)/tcp' "${bootstrap}"; then
  echo "Control-plane ports must not be opened by the bootstrap."
  exit 1
fi

echo "PASS bootstrap syntax, secret handling, authenticated readiness and control-plane firewall contract"
