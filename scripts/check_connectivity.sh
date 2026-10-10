#!/usr/bin/env bash

echo "=================================================="
echo "    Checking Connectivity to RKE2 Nodes"
echo "=================================================="

hosts=("169.58.118.85:root:Fx74pLx3:Master" "169.58.118.125:root:Fx74pLx3:Worker2" "46.250.224.184:nprdroot:Happy@168:Worker1")

for item in "${hosts[@]}"; do
    IFS=":" read -r ip user pass name <<< "$item"
    echo -n "[$name] Testing ICMP Ping ($ip)... "
    if ping -c 1 -W 2 "$ip" >/dev/null 2>&1; then
        echo "OK"
    else
        echo "FAILED"
    fi

    echo -n "[$name] Testing SSH Auth ($user@$ip)... "
    if sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=4 "$user@$ip" "echo Connected" >/dev/null 2>&1; then
        echo "OK (Password Auth)"
    elif ssh -o StrictHostKeyChecking=no -o ConnectTimeout=4 -i "${HOME}/.ssh/id_rsa_autofik" "$user@$ip" "echo Connected" >/dev/null 2>&1; then
        echo "OK (Key Auth)"
    else
        echo "FAILED (Needs SSH key or password authentication enabled)"
    fi
    echo "--------------------------------------------------"
done
