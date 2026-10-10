#!/usr/bin/env bash
set -e

KEY_PATH="${HOME}/.ssh/id_rsa_autofik"

echo "=================================================="
echo "    RKE2 Cluster SSH Key Setup Helper"
echo "=================================================="

if [ ! -f "$KEY_PATH" ]; then
    echo "[*] Generating dedicated SSH key: $KEY_PATH ..."
    ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -N "" -C "autofik-rke2-cluster"
else
    echo "[*] SSH key already exists at: $KEY_PATH"
fi

PUB_KEY=$(cat "${KEY_PATH}.pub")

echo ""
echo "[*] Pushing SSH key to Server 1 (169.58.118.85 - Master)..."
sshpass -p 'Fx74pLx3' ssh-copy-id -i "${KEY_PATH}.pub" -o StrictHostKeyChecking=no root@169.58.118.85 || echo "[!] Failed to push to Server 1"

echo ""
echo "[*] Pushing SSH key to Server 2 (169.58.118.125 - Worker 2)..."
sshpass -p 'Fx74pLx3' ssh-copy-id -i "${KEY_PATH}.pub" -o StrictHostKeyChecking=no root@169.58.118.125 || echo "[!] Failed to push to Server 2"

echo ""
echo "[*] Pushing SSH key to Server 3 (46.250.224.184 - Worker 1)..."
sshpass -p 'Happy@168' ssh-copy-id -i "${KEY_PATH}.pub" -o StrictHostKeyChecking=no nprdroot@46.250.224.184 || echo "[!] Failed to push to Server 3"

echo ""
echo "[✓] SSH key setup routine completed."
