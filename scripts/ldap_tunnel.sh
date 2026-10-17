#!/usr/bin/env bash
# Opens the super-admin LDAP outpost at ldap://127.0.0.1:3389 without exposing it:
# SSH to the master and `kubectl port-forward` to the outpost Service. Lets the
# super-admin app run on a laptop (npm run dev, LDAP_URL=ldap://127.0.0.1:3389).
#
# Logs in with ~/.ssh/id_rsa_autofik (make setup-ssh) or, without that key, with the
# master's inventory password through sshpass, so it never stops at a prompt.
# Reconnects by itself (outpost pod restarted, network blip) until Ctrl+C.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MASTER_INVENTORY_HOST="${MASTER_INVENTORY_HOST:-autofik-master-svr-ram-12gb}"
MASTER_HOST="${MASTER_HOST:-169.58.118.85}"
MASTER_USER="${MASTER_USER:-root}"
LOCAL_PORT="${LOCAL_PORT:-3389}"
OUTPOST_SERVICE="${OUTPOST_SERVICE:-ak-outpost-super-admin-ldap}"
KEY_PATH="${HOME}/.ssh/id_rsa_autofik"
KUBECTL="/var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml"

if (exec 3<>"/dev/tcp/127.0.0.1/${LOCAL_PORT}") 2>/dev/null; then
  echo "Port ${LOCAL_PORT} is already in use (another tunnel?). Close it or set LOCAL_PORT." >&2
  exit 1
fi

SSH=(ssh -o StrictHostKeyChecking=no -o ExitOnForwardFailure=yes
  -o ServerAliveInterval=15 -o ServerAliveCountMax=3
  -L "127.0.0.1:${LOCAL_PORT}:127.0.0.1:3389")
if [ -f "$KEY_PATH" ]; then
  SSH+=(-i "$KEY_PATH")
elif command -v sshpass >/dev/null && command -v ansible-inventory >/dev/null; then
  SSHPASS="$(ansible-inventory -i "${REPO_DIR}/inventory/hosts.yaml" --host "$MASTER_INVENTORY_HOST" 2>/dev/null |
    python3 -c 'import json, sys; print(json.load(sys.stdin).get("ansible_password", ""))')" || SSHPASS=""
  if [ -n "$SSHPASS" ]; then
    export SSHPASS
    SSH=(sshpass -e "${SSH[@]}")
  fi
fi

# On the master: ends when the port-forward ends (the loop below then reconnects),
# and stops the port-forward when this SSH connection closes (stdin reaches EOF).
REMOTE="exec 3<&0; ${KUBECTL} -n authentik port-forward svc/${OUTPOST_SERVICE} 3389:389 & pf=\$!;"
REMOTE+=" (cat <&3 >/dev/null; kill \$pf) >/dev/null 2>&1 & exec 3<&-; wait \$pf"

echo "=================================================="
echo "    super-admin LDAP tunnel -> ldap://127.0.0.1:${LOCAL_PORT}"
echo "=================================================="
echo "App: npm run dev in the super-admin repo (server/.env: LDAP_URL=ldap://127.0.0.1:${LOCAL_PORT})"
echo "Press Ctrl+C to close the tunnel."
echo ""

# SSH reads from a pipe that stays open for as long as this script runs, not from the
# terminal: the remote side sees EOF only when the connection really closes, and the
# tunnel also works in the background (make ldap-tunnel &).
exec 4< <(exec sleep infinity)
stdin_keeper=$!
trap 'kill "$stdin_keeper" 2>/dev/null' EXIT
trap 'echo; echo "LDAP tunnel closed."; exit 0' INT TERM

quick_failures=0
while true; do
  started=$SECONDS
  "${SSH[@]}" "${MASTER_USER}@${MASTER_HOST}" "$REMOTE" <&4 || true
  # Sessions that end right away mean SSH itself fails (password, network): give up.
  if (( SECONDS - started < 10 )); then quick_failures=$((quick_failures + 1)); else quick_failures=0; fi
  if (( quick_failures >= 5 )); then
    echo "The tunnel keeps failing right away; check SSH access to ${MASTER_USER}@${MASTER_HOST}." >&2
    exit 1
  fi
  echo "LDAP tunnel dropped; reconnecting in 3 s (Ctrl+C to stop)..."
  sleep 3
done
