#!/usr/bin/env bash
# Opens the Vault UI/API at https://127.0.0.1:8200 without exposing Vault publicly:
# SSH to the master and run `kubectl port-forward` to the active Vault pod there.
set -euo pipefail

MASTER_HOST="${MASTER_HOST:-169.58.118.85}"
MASTER_USER="${MASTER_USER:-root}"
LOCAL_PORT="${LOCAL_PORT:-8200}"
KEY_PATH="${HOME}/.ssh/id_rsa_autofik"
CA_CERT="$(cd "$(dirname "$0")/.." && pwd)/secrets/vault/tls/ca.crt"

SSH_OPTS=(-o StrictHostKeyChecking=no -o ExitOnForwardFailure=yes -L "${LOCAL_PORT}:127.0.0.1:8200")
[ -f "$KEY_PATH" ] && SSH_OPTS+=(-i "$KEY_PATH")

echo "=================================================="
echo "    Vault UI tunnel -> https://127.0.0.1:${LOCAL_PORT}"
echo "=================================================="
echo "CLI: export VAULT_ADDR=https://127.0.0.1:${LOCAL_PORT} VAULT_CACERT=${CA_CERT}"
echo "Browser: import ${CA_CERT} or accept the self-signed certificate warning."
echo "Press Ctrl+C to close the tunnel. Re-run if the active Vault pod changes."
echo ""

exec ssh "${SSH_OPTS[@]}" "${MASTER_USER}@${MASTER_HOST}" \
  "/var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml -n vault port-forward svc/vault-active 8200:8200"
