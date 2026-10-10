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
│   └── rke2_agent/              # Worker install, supervisor join config, systemd service
│       ├── tasks/main.yaml
│       ├── handlers/main.yaml
│       └── templates/config.yaml.j2
├── playbooks/
│   ├── 01-prerequisites.yaml    # Node system tuning & preparation
│   ├── 02-rke2-server.yaml      # Master control-plane deployment
│   ├── 03-rke2-agent.yaml       # Worker nodes deployment
│   ├── 04-verify.yaml           # Cluster health & pod status check
│   └── reset.yaml               # Complete teardown / uninstallation
├── scripts/
│   ├── check_connectivity.sh   # Diagnostic script for ICMP & SSH auth
│   └── setup_ssh_keys.sh       # Key generator & key distribution helper
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
