# Autofik Kubernetes (RKE2) HA Cluster Automation

Production-grade Ansible automation for bootstrapping and managing a High Availability (HA) ready Kubernetes cluster powered by **RKE2 (Rancher Kubernetes Engine 2)**.

---

## 📌 Cluster Topology

| Node Name | Role | IP Address | OS | RAM | SSH User | Auth Method |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`autofik-master-svr-ram-12gb`** | Master (Server) | `169.58.118.85` | Ubuntu 24.04 LTS | 12 GB | `root` | Password (`Fx74pLx3`) |
| **`autofik-worker2-24gb`** | Worker 2 (Agent) | `169.58.118.125` | Ubuntu 24.04 LTS | 24 GB | `root` | Password (`Fx74pLx3`) |
| **`autofik-worker1`** | Worker 1 (Agent) | `46.250.224.184` | Ubuntu 24.04 LTS | 24 GB | `nprdroot` | Password / Sudo (`Happy@168`) |

> **HA Control Plane Design**:  
> The first server node bootstraps the embedded etcd cluster with predefined TLS SANs and cluster tokens. The architecture is modular: any additional master node added to `[rke2_servers]` automatically joins the existing etcd quorum via `server: https://169.58.118.85:9345`.

---

## 📁 Repository Structure

```text
autofik.infra.testing/
├── ansible.cfg                  # Ansible configuration (pipelining, timeouts, yaml output)
├── inventory/
│   └── hosts.yaml               # Cluster node inventory with IPs, credentials & roles
├── group_vars/
│   ├── all.yaml                 # Global cluster settings (RKE2 version, token, CIDRs, SANs)
│   ├── rke2_servers.yaml        # Master control-plane variables & ports
│   └── rke2_agents.yaml         # Worker agent variables & ports
├── roles/
│   ├── common/                  # System prep: swap off, sysctl, kernel modules, /etc/hosts
│   │   ├── tasks/main.yaml
│   │   └── handlers/main.yaml
│   ├── rke2_server/             # Master install, config, systemd service, kubeconfig export
│   │   ├── tasks/main.yaml
│   │   ├── handlers/main.yaml
│   │   └── templates/config.yaml.j2
│   ├── rke2_agent/              # Worker install, supervisor join config, systemd service
│   │   ├── tasks/main.yaml
│   │   ├── handlers/main.yaml
│   │   └── templates/config.yaml.j2
│   ├── local_path_provisioner/  # StorageClasses local-path + local-path-retain
│   ├── vault/                   # Vault HA: helm, TLS, deploy, init, unseal, status, reset
│   │   ├── defaults/main.yaml   # Versions, replicas, storage, UI exposure, key shares
│   │   ├── tasks/
│   │   └── templates/values.yaml.j2
│   └── cloudflare_tunnel/       # Tunnel, routes, DNS, Access (Cloudflare API) + cloudflared
│       ├── defaults/main.yaml   # Zone, hostnames, routes, allowed emails, image
│       ├── tasks/
│       └── templates/cloudflared.yaml.j2
├── playbooks/
│   ├── 01-prerequisites.yaml    # Node system tuning & preparation
│   ├── 02-rke2-server.yaml      # Master control-plane deployment
│   ├── 03-rke2-agent.yaml       # Worker nodes deployment
│   ├── 04-verify.yaml           # Cluster health & pod status check
│   ├── 05-storage.yaml          # local-path-provisioner (PersistentVolumes)
│   ├── 06-vault.yaml            # Vault HA deploy + init + unseal + verify
│   ├── vault-unseal.yaml        # Unseal Vault pods after restarts
│   ├── vault-status.yaml        # Vault pods, seal state, raft peers
│   ├── vault-reset.yaml         # Destroy Vault and its data (asks to confirm)
│   ├── 07-cloudflare.yaml       # Cloudflare Tunnel + DNS + Access + cloudflared
│   ├── cloudflare-status.yaml   # Tunnel health, edge certificates, live probes
│   ├── cloudflare-reset.yaml    # Delete tunnel, its DNS records, Access app (asks to confirm)
│   └── reset.yaml               # Complete teardown / uninstallation
├── scripts/
│   ├── check_connectivity.sh   # Diagnostic script for ICMP & SSH auth
│   ├── setup_ssh_keys.sh       # Key generator & key distribution helper
│   └── vault_ui_tunnel.sh      # SSH + port-forward tunnel to the Vault UI
├── secrets/                     # (git-ignored) Vault keys + TLS, Cloudflare API token
├── site.yaml                    # Master orchestration entrypoint
├── Makefile                     # Shortcut CLI commands
└── README.md
```

---

## ⚡ Quick Start

### 1. Test Connectivity
Check network ping and SSH access:
```bash
make check
# or
ansible autofik-master-svr-ram-12gb,autofik-worker2-24gb -m ping
```

### 2. Setup SSH Keys (Optional but Recommended)
To set up passwordless SSH authentication:
```bash
make setup-ssh
```

### 3. Deploy the Entire Cluster
Run the end-to-end playbook:
```bash
make deploy
# Or to deploy only to online servers (e.g. Master + Worker2):
ansible-playbook site.yaml --limit autofik-master-svr-ram-12gb,autofik-worker2-24gb
```

### 4. Verify Cluster Health
```bash
make verify
```

### 5. Access Cluster locally via `kubectl`
The playbook automatically downloads the cluster kubeconfig to `./kubeconfig/autofik-rke2.yaml` with the external master IP configured.
```bash
make nodes
make pods

# Or use kubectl directly:
kubectl --kubeconfig=kubeconfig/autofik-rke2.yaml get nodes -o wide
```

---

## ✅ Node Connectivity & Diagnostics Status
- **Master (`169.58.118.85`)**: Connected successfully with `root` / `Fx74pLx3`.
- **Worker 2 (`169.58.118.125`)**: Connected successfully with `root` / `Fx74pLx3`.
- **Worker 1 (`46.250.224.184`)**: Connected successfully with `nprdroot` / `Happy@168` (sudo verified).

All nodes are 100% reachable and ready for full automated deployment with `make deploy`.

---

## 🛠️ Step-by-Step Playbook Execution

If you prefer executing phases independently:

```bash
# Phase 1: System prerequisites (disable swap, sysctl, kernel modules, hosts file)
ansible-playbook playbooks/01-prerequisites.yaml

# Phase 2: Deploy RKE2 Server (Master)
ansible-playbook playbooks/02-rke2-server.yaml

# Phase 3: Deploy RKE2 Agents (Workers)
ansible-playbook playbooks/03-rke2-agent.yaml

# Phase 4: Cluster verification
ansible-playbook playbooks/04-verify.yaml
```

---

## 🔄 Teardown / Reset

To cleanly uninstall RKE2, flush CNI iptables, and restore the nodes:
```bash
make reset
# or
ansible-playbook playbooks/reset.yaml
```

---

## 🔐 HashiCorp Vault (HA)

Vault runs inside the RKE2 cluster as a 3-member Raft cluster with **one pod per node**, so it keeps serving if any single node goes down (Raft quorum = 2 of 3).

| Item | Setting |
| :--- | :--- |
| Chart / Vault | `hashicorp/vault` `0.34.1` / Vault `2.0.4` |
| Storage | Raft integrated storage, 10Gi per pod on `local-path-retain` (node-local disk, `Retain`) |
| TLS | End-to-end HTTPS, self-signed CA generated by Ansible in `secrets/vault/tls/` |
| Unseal | Shamir: 5 key shares, threshold 3 |
| Services | `vault-active` (leader), `vault-standby`, `vault` (ClusterIP, not public) |
| Agent injector | 2 replicas |

### Deploy
```bash
make vault          # local-path-provisioner -> Vault -> init -> unseal -> verify (safe to re-run)
make vault-status   # pods, seal state, active node, raft peers
```

On the first run Vault is initialized, and the **unseal keys + root token** are written to `secrets/vault/vault-init.json` (git-ignored, mode `0600`).
Move that file into a password manager and remove it from your laptop: without 3 of the 5 keys, the data in Vault can't be recovered.
`make vault-unseal` reads the keys from that path, so put the file back temporarily when you need to unseal.
Once you've set up real auth methods (userpass/OIDC/Kubernetes), revoke the root token.

### After any restart: unseal
Vault pods come back **sealed** after a node reboot, eviction or upgrade. The cluster keeps serving while 2 of 3 pods are unsealed. To unseal the restarted pod:
```bash
make vault-unseal
```

### UI / CLI access
```bash
make vault-ui       # SSH tunnel via master, then open https://127.0.0.1:8200
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_CACERT=$PWD/secrets/vault/tls/ca.crt
```
To expose Vault publicly instead, set `vault_ui_service_type: NodePort` (port `32200`) in `roles/vault/defaults/main.yaml` and re-run `make vault`.
Apps in the cluster use `https://vault.vault.svc:8200` and must trust `ca.crt` (e.g. the injector annotation `vault.hashicorp.com/ca-cert`).

### Upgrades
The StatefulSet uses `OnDelete`. After you bump `vault_version` / `vault_chart_version` and run `make vault`, restart the pods yourself: delete the standby pods one at a time, then the active one, and run `make vault-unseal` after each delete.

### Destroy
```bash
make vault-reset    # asks for confirmation; deletes Vault, its volumes and ALL secrets
```

---

## ☁️ Cloudflare Tunnel

The cluster is published through the Cloudflare Tunnel `f453e37b-…` (created in the Zero Trust dashboard), so no inbound ports are needed. Ansible manages that tunnel's routes, the DNS records, the edge certificate and the Access app through the Cloudflare API (the same approach as the sso-gateway `cloudflare-tunnel-route.sh`). `cloudflared` runs in the cluster with 2 replicas on different nodes.

| Public hostname | Goes to | Protection |
| :--- | :--- | :--- |
| `vault.testing.autofik.com` | `vault-active` (HTTPS, verified with the Vault CA) | Cloudflare Access (`mai.reaksa@autofik.com`) + Vault login |
| `*.testing.autofik.com` | Traefik (`rke2-traefik`), so any Ingress with that host | the app itself |
| anything else | `404` | - |

### One-time: tokens
**Tunnel token:** put the connector token of the dashboard tunnel (the value after `cloudflared service install`) in `secrets/cloudflare/tunnel_token`. If that file doesn't exist, Ansible creates its own tunnel named `autofik-rke2-testing` instead.

**API token:** create a **Custom Token** under dash.cloudflare.com → My Profile → API Tokens with:

| Permission | Resource |
| :--- | :--- |
| Account › Cloudflare Tunnel › Edit | your account |
| Account › Access: Apps and Policies › Edit | your account |
| Zone › DNS › Edit | `autofik.com` |
| Zone › SSL and Certificates › Edit | `autofik.com` |

Save the token to `secrets/cloudflare/api_token` (git-ignored), or `export CLOUDFLARE_API_TOKEN=...`.
Zero Trust must be enabled on the account, with the **One-time PIN** login method (Zero Trust → Settings → Authentication).

### Deploy
```bash
make cloudflare             # routes, DNS, edge cert, Access, cloudflared, end-to-end probes (safe to re-run)
make cloudflare-status      # tunnel health + connections, edge certificates, live probes
make cloudflare-connector   # only (re)deploy cloudflared from the tunnel token, with no API calls
```
Ansible owns this tunnel's routes, so any route you add in the dashboard is replaced on the next run. Add routes in `cloudflare_extra_routes` instead (`roles/cloudflare_tunnel/defaults/main.yaml`).

On the first run, the old DNS-only record `*.testing.autofik.com → 46.250.224.184` is replaced by the tunnel CNAME. Only records that point at one of this cluster's nodes are ever replaced; any other existing record stops the run. The nodes still accept direct traffic on ports 80/443, so firewall them if you want tunnel-only access.

### Edge certificate for `*.testing.autofik.com`
Universal SSL covers only `autofik.com` and `*.autofik.com`. Names two levels deep (`vault.testing.autofik.com`) need an Advanced Certificate Manager pack. The zone already has one for `*.master.autofik.com`. `make cloudflare` orders a Let's Encrypt pack for `autofik.com, *.testing.autofik.com` when nothing covers those names (`cloudflare_order_edge_certificate`). It never orders a second one while the first is still validating. Validation takes a few minutes; until then, browsers fail the TLS handshake on those names.

### Publishing an app
Create an Ingress with a host under `testing.autofik.com`. No Cloudflare change is needed:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
spec:
  ingressClassName: traefik
  rules:
    - host: myapp.testing.autofik.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service: { name: myapp, port: { number: 80 } }
```
Cloudflare terminates TLS. `cloudflared` sends plain HTTP to Traefik inside the cluster.

### Vault from outside the cluster
The UI is at https://vault.testing.autofik.com: log in through Access, then with Vault.
For CLI or automation, keep using `make vault-ui`, or create an Access **service token** and add an allow rule for it.

### Remove
```bash
make cloudflare-reset    # asks for confirmation; deletes the DNS records, Access app/policy and cloudflared
                         # (a tunnel supplied through tunnel_token is kept; a tunnel Ansible created is deleted)
```

---

## 🛡️ Security & Ports Configuration

The following network ports are configured and utilized by RKE2:

| Port / Protocol | Component | Source / Target |
| :--- | :--- | :--- |
| `6443/tcp` | Kubernetes API Server | All Nodes, Workstations |
| `9345/tcp` | RKE2 Supervisor API | All Agents -> Master |
| `2379-2380/tcp` | etcd Client & Peer | Master nodes only (HA) |
| `10250/tcp` | Kubelet Metrics & Exec | Master <-> Workers |
| `8472/udp` | Canal / Flannel VXLAN | All Nodes |
| `30000-32767/tcp` | NodePort Services | External Load Balancer |

Master Server (autofik-master-svr-ram-12gb):
IP Address: 169.58.118.85
User: root
Password: Fx74pLx3
Private Network: Yes
RAM: 12GB 

Contabo
Worker Server (autofik-worker2-24gb):
IP Address: 169.58.118.125
User: root
Password: Fx74pLx3
Private Network: Yes
RAM: 24GB 

Contabo