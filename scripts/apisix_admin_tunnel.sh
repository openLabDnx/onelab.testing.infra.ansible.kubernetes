#!/usr/bin/env bash
# Opens the APISIX Admin API + built-in Admin UI at http://127.0.0.1:9180 without
# exposing them: SSH to the master and `kubectl port-forward` to the admin Service.
# The billing seed scripts (APISIX_ADMIN_URL=http://127.0.0.1:9180) work through it as-is.
set -euo pipefail

MASTER_HOST="${MASTER_HOST:-169.58.118.85}"
MASTER_USER="${MASTER_USER:-root}"
LOCAL_PORT="${LOCAL_PORT:-9180}"
KEY_PATH="${HOME}/.ssh/id_rsa_autofik"
ADMIN_KEY_FILE="$(cd "$(dirname "$0")/.." && pwd)/secrets/apisix/admin_key"

SSH_OPTS=(-o StrictHostKeyChecking=no -o ExitOnForwardFailure=yes -L "${LOCAL_PORT}:127.0.0.1:9180")
[ -f "$KEY_PATH" ] && SSH_OPTS+=(-i "$KEY_PATH")

echo "=================================================="
echo "    APISIX Admin tunnel -> http://127.0.0.1:${LOCAL_PORT}"
echo "=================================================="
echo "UI:  http://127.0.0.1:${LOCAL_PORT}/ui/   (log in with the admin key)"
echo "API: export APISIX_ADMIN_URL=http://127.0.0.1:${LOCAL_PORT} APISIX_ADMIN_KEY=\$(cat ${ADMIN_KEY_FILE})"
echo "Press Ctrl+C to close the tunnel."
echo ""

exec ssh "${SSH_OPTS[@]}" "${MASTER_USER}@${MASTER_HOST}" \
  "/var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml -n apisix port-forward svc/apisix-admin 9180:9180"
