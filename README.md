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
│   ├── cloudflare_tunnel/       # Tunnel, routes, DNS, Access (Cloudflare API) + cloudflared
│   ├── apisix/                  # APISIX gateway + etcd x3, Admin UI, PDB/HPA/NetworkPolicy, smoke test
│   │   ├── defaults/main.yaml   # Chart/image pins, replicas, HPA, etcd, real-IP settings
│   │   ├── tasks/
│   │   └── templates/           # values.yaml.j2, k8s-extras.yaml.j2, smoke-test/status scripts
│   ├── helm/                    # Pinned Helm binary on the primary server (used by vault, apisix, platform)
│   ├── platform_vars/           # Shared hostnames, namespaces, node sites, OIDC client secrets
│   ├── traefik/                 # RKE2 Traefik HelmChartConfig (no hostPorts) + dashboard behind SSO
│   ├── cnpg/                    # CloudNativePG operator
│   ├── authentik/               # PostgreSQL cluster, authentik, SSO blueprint, forward-auth, backups
│   ├── argocd/                  # Argo CD HA + authentik OIDC
│   ├── portainer/               # Portainer CE + authentik OAuth
│   ├── cert_manager/            # cert-manager (needed by the RabbitMQ operator)
│   ├── rabbitmq/                # RabbitMQ Cluster Operator, 3-node cluster, users, policy, UI route
│   ├── kafka/                   # Strimzi, Kafka KRaft x3, topics, users/ACLs, kafbat UI, metrics
│   ├── monitoring/              # kube-prometheus-stack, Grafana SSO + datasources, node-exporter behind kube-rbac-proxy, dashboards
│   ├── loki/                    # Loki (logs, 30 days), NetworkPolicy, alerts
│   ├── jaeger/                  # Jaeger v2 (traces, 7 days, span metrics), UI behind authentik, NetworkPolicy, alerts
│   └── alloy/                   # Grafana Alloy on every node: logs + events -> Loki, OTLP -> Jaeger/Loki/Prometheus
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
│   ├── 08-apisix.yaml           # APISIX API gateway (HA) + smoke test
│   ├── apisix-status.yaml       # Gateway/etcd pods, HPA, etcd health, route counts
│   ├── apisix-reset.yaml        # Destroy APISIX and its etcd data (asks to confirm)
│   ├── 09-platform.yaml         # Traefik, CloudNativePG, authentik, Argo CD, Portainer (tags per part)
│   ├── 10-messaging.yaml        # cert-manager, RabbitMQ, Kafka (tags per part)
│   ├── 11-monitoring.yaml       # Metrics, logs, traces: Prometheus, Grafana, Loki, Jaeger, Alloy (tags per part)
│   └── reset.yaml               # Complete teardown / uninstallation
├── scripts/
│   ├── check_connectivity.sh   # Diagnostic script for ICMP & SSH auth
│   ├── setup_ssh_keys.sh       # Key generator & key distribution helper
│   ├── vault_ui_tunnel.sh      # SSH + port-forward tunnel to the Vault UI
│   └── apisix_admin_tunnel.sh  # SSH + port-forward tunnel to the APISIX Admin API/UI
├── secrets/                     # (git-ignored) Vault keys + TLS, Cloudflare tokens, APISIX admin keys
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
| `apisix.testing.autofik.com/ui/` | APISIX Admin UI + Admin API (`apisix-admin:9180`) | Cloudflare Access (`mai.reaksa@autofik.com`) + APISIX admin key |
| `api.testing.autofik.com` | APISIX (`apisix-gateway`) | APISIX plugins per route |
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
**Vault and the APISIX dashboard are published only behind Cloudflare Access.** If Access isn't usable (not enabled on the account, or the token lacks the permission), `make cloudflare` stops before changing anything. Until Access is enabled, publish everything except those two with:
```bash
ansible-playbook playbooks/07-cloudflare.yaml -e '{"cloudflare_vault_enabled": false, "cloudflare_apisix_admin_enabled": false}'
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

## 🚪 APISIX API Gateway

Apache APISIX is the public API edge, set up the same way as the master cluster's `roles/apisix`: the **traditional** role with **etcd** as config store. Routes are written through the Admin API (e.g. the billing `seed-routes.sh`) or the built-in Admin UI, and survive pod restarts.

```text
client ──HTTPS──▶ Cloudflare edge ──tunnel──▶ cloudflared ──HTTP──▶ apisix-gateway ──▶ your services
                  (TLS ends here)                                    (2-3 pods, HPA)
                                                                           │ watches
                                                                     apisix-etcd x3 (one per node)
```

| Item | Setting |
| :--- | :--- |
| Chart / APISIX | `apisix/apisix` `2.17.0` / APISIX `3.18.0`, the same pins as the master cluster |
| Gateway | 2-3 pods (HPA on CPU 70%, scales by 1 at a time), spread across nodes, PDB `minAvailable: 1`, zero-downtime rolling updates |
| Config store | etcd 3 members, one per node (hard anti-affinity), 8Gi each on `local-path-retain`, keeps working with 1 node down |
| Public URLs | API: `https://api.testing.autofik.com` → `apisix-gateway:80`<br>Dashboard: `https://apisix.testing.autofik.com/ui/` → `apisix-admin:9180`, behind Cloudflare Access |
| Client IP | `remote_addr` = `CF-Connecting-IP`, trusted only from the pod network, so `limit-count` / `ip-restriction` see the real user |
| Admin API / UI | port 9180, ClusterIP; NetworkPolicy lets only the `cloudflared` pods in (plus `make apisix-admin` port-forward). Behind Cloudflare, `remote_addr` is the visitor's IP, so the nginx IP allow-list is open and protection is NetworkPolicy + Cloudflare Access + admin key (`apisix_admin_via_cloudflared: false` restores localhost-only) |
| Keys | generated admin/viewer keys in `secrets/apisix/` (git-ignored), served from a Secret; the chart's public default key returns 401 |
| Isolation | etcd accepts clients only from gateway pods; other pods can reach only the proxy (9080) and metrics (9091) |
| Metrics | Prometheus on `apisix-prometheus-metrics.apisix.svc:9091/apisix/prometheus/metrics` |

### Deploy
```bash
make apisix          # storage + APISIX + etcd + PDB/HPA/NetworkPolicy + smoke test (safe to re-run)
make apisix-status   # pods, HPA, etcd health, number of routes/upstreams/consumers
```
`make apisix` ends with a smoke test. It creates a temporary route through the Admin API, checks that every gateway pod serves it and that the client IP is read from `CF-Connecting-IP`, then deletes the route.

### Add routes
Open the dashboard at **https://apisix.testing.autofik.com/ui/**: sign in with Cloudflare Access, then enter the admin key from `secrets/apisix/admin_key`. Or use the private tunnel:
```bash
make apisix-admin    # keep it open; Admin UI at http://127.0.0.1:9180/ui/ (log in with the admin key)

export APISIX_ADMIN_URL=http://127.0.0.1:9180
export APISIX_ADMIN_KEY=$(cat secrets/apisix/admin_key)
curl -sS -X PUT "$APISIX_ADMIN_URL/apisix/admin/routes/hello" -H "X-API-KEY: $APISIX_ADMIN_KEY" -d '{
  "uri": "/api/v1/hello/*",
  "upstream": { "type": "roundrobin", "nodes": { "my-service.my-namespace.svc.cluster.local:8080": 1 } },
  "plugins": { "limit-count": { "count": 120, "time_window": 60, "key_type": "var", "key": "remote_addr", "rejected_code": 429 } }
}'
```
The existing scripts work through the same tunnel, e.g. `deployment/autofik.api.dev.getway.internal.billing/apisix/seed-routes.sh` (set `UPSTREAM_NODE` to the service in this cluster).

### Operations
- **Rotate the admin key:** delete `secrets/apisix/admin_key` and run `make apisix`. A new key is generated and the gateway restarts with it.
- **Upgrade:** bump `apisix_chart_version` / `apisix_image_tag` in `roles/apisix/defaults/main.yaml`, then `make apisix` (rolling, no downtime).
- **Grow etcd:** only one member per run (2→3, then 3→4); see the master repo's `roles/apisix` for why.
- **Backup:** routes live only in etcd. Take a snapshot before risky changes:
  `kubectl -n apisix exec apisix-etcd-0 -- etcdctl snapshot save /tmp/apisix.db` then `kubectl cp` it out.

### Destroy
```bash
make apisix-reset    # asks for confirmation; deletes APISIX, etcd and every route/consumer (keys in secrets/apisix are kept)
```

---

## 🧭 Platform: Traefik, authentik (SSO), Argo CD, Portainer

Every UI is published under `*.testing.autofik.com`. The Cloudflare tunnel already sends that wildcard to Traefik, so no Cloudflare change is needed. **authentik is the single login** for everything else.

| URL | What | Login |
| :--- | :--- | :--- |
| https://auth.testing.autofik.com | authentik (SSO, users, groups, MFA) | `akadmin` / `secrets/platform/authentik_akadmin_password` |
| https://argocd.testing.autofik.com | Argo CD (GitOps) | **Log in via authentik**; break-glass `admin` / `secrets/platform/argocd_admin_password` |
| https://portainer.testing.autofik.com | Portainer CE | **Login with OAuth** (authentik); break-glass `admin` / `secrets/platform/portainer_admin_password` |
| https://traefik.testing.autofik.com/dashboard/ | Traefik dashboard | authentik forward-auth (no login of its own) |
| https://rabbitmq.testing.autofik.com | RabbitMQ management | authentik forward-auth, then RabbitMQ `admin` |
| https://kafka.testing.autofik.com | Kafka UI (kafbat, read-only) | authentik forward-auth |
| https://grafana.testing.autofik.com | Grafana (metrics, logs, traces, dashboards) | **authentik, automatically** (also from the Grafana tile in authentik); break-glass `admin` / `secrets/platform/grafana_admin_password` at `/login?disableAutoLogin` |
| https://jaeger.testing.autofik.com | Jaeger (traces) | authentik forward-auth (no login of its own) |

Only members of the authentik group **`platform-admins`** can open these apps (`akadmin` is in it); anyone else gets authentik's "Permission denied". Argo CD maps that group to `role:admin`. In Portainer, SSO users land in team `sso-users` **with no environment access**; usernames listed in `portainer_admin_users` (`roles/portainer/defaults/main.yaml`, default `akadmin`) are made Portainer administrators after their first SSO login and a re-run of `make portainer`.

```bash
make platform    # everything below, in order (safe to re-run)
make traefik     # Traefik settings + dashboard
make authentik   # PostgreSQL + authentik + SSO blueprint + backups
make argocd      # Argo CD HA + SSO
make portainer   # Portainer + SSO
```

### What "production" means here
- **Traefik:** RKE2's bundled Traefik, tuned through a `HelmChartConfig`. **No hostPorts**: the nodes' public IPs no longer answer on 80/443, so traffic can't get around Cloudflare. Client IP and `X-Forwarded-*` headers are trusted only from the pod network (cloudflared). JSON access logs. The dashboard is behind authentik.
- **authentik:** 2 server + 2 worker pods with PDBs. All settings and credentials come from a Secret (no inline env passwords, no superuser API token). SSO apps, groups and forward-auth providers are declared in a **blueprint** (`roles/authentik/templates/platform-blueprint.yaml.j2`); change them there, not by hand.
- **PostgreSQL for authentik:** CloudNativePG (operator ×2), 2 instances (primary + synchronous standby) with automatic failover. **Daily `pg_dump`** at 02:30 UTC to the PVC `authentik-db-backups`, kept 14 days.
- **Argo CD:** HA (2 server, 2 repo-server, 2 ApplicationSet, Redis HA with Sentinel). OIDC with authentik plus RBAC (`policy.default` = nothing). The admin password hash is kept, so re-runs don't log anyone out.
- **Portainer:** CE 2.45.1, data on `local-path-retain`, **database encrypted at rest**, SSO through authentik, trusted origin set for the proxy.

### Node sites
master and worker2 share a data centre (~1 ms). **worker1 is ~160 ms away.** Nodes are labelled `autofik.com/site=eu|ap`. authentik, its PostgreSQL, Argo CD and Portainer run only on `eu`: a database client 160 ms from its database spends seconds per request.

### After the first deploy
1. Log in to https://auth.testing.autofik.com as `akadmin`, create your own user, add it to `platform-admins`, and **enable MFA** (Settings → MFA devices). For Portainer admin rights, add your username to `portainer_admin_users`, log in to Portainer once via OAuth, then run `make portainer`.
2. Check SSO into Argo CD, then set `argocd_admin_enabled: false` in `roles/argocd/defaults/main.yaml` and run `make argocd`.
3. Copy the latest authentik backup off the cluster from time to time:
   `kubectl -n authentik exec <pod with the PVC> -- ls /backups` (or restore with `pg_restore`).

---

## 📨 Messaging: RabbitMQ & Kafka

Both run as **3-member clusters, one member per server**, so losing any one server loses no acknowledged message. They're internal (ClusterIP); only their admin UIs are published, behind authentik.

| | RabbitMQ | Kafka |
| :--- | :--- | :--- |
| Software | RabbitMQ 4.3.5 via the RabbitMQ Cluster Operator v2.23.0 | Apache Kafka 4.2.1 (KRaft) via Strimzi 1.2.0 |
| HA | 3 nodes, **quorum queues by default**, `pause_minority` | 3 broker+controller nodes, RF 3, `min.insync.replicas` 2 |
| In-cluster address | `rabbitmq.rabbitmq.svc.cluster.local:5672`, vhost `/` | `kafka-kafka-bootstrap.kafka.svc:9092` (SASL_PLAINTEXT) or `:9093` (SASL_SSL) |
| App login | own user per app: `booking`, `garages-cms`, `billing`, `subscription` (no management access) | own SCRAM-SHA-512 user per app with ACLs: `signal-of-service` (sos.*, mechanic.*), `sos-gateway` (read only) |
| Credentials | Secret `rabbitmq-user-<app>` in `rabbitmq` (`uri`, `username`, `password`) | Secret `<user>` in `kafka` (`password`, `sasl.jaas.config`) |
| Limits | 1 GiB per queue (`reject-publish`), publishers blocked below 2 GB free disk | 7 days and 512 MiB per partition, auto-create off |
| Admin UI | https://rabbitmq.testing.autofik.com (authentik, then `admin` / `secrets/platform/rabbitmq_admin_password`) | https://kafka.testing.autofik.com (authentik; kafbat, **read-only**) |

```bash
make messaging   # cert-manager + RabbitMQ + Kafka, each ends with a smoke test (safe to re-run)
make rabbitmq    # RabbitMQ only
make kafka       # Kafka only
```

### Connecting the apps
- **RabbitMQ:** replace the shared `admin` URI with the app's own: `RABBITMQ_URI` = `uri` from Secret `rabbitmq-user-<app>`. Declare queues durable, publish persistent messages, and use publisher confirms. New queues are quorum queues unless the app asks for `x-queue-type=classic`.
- **Kafka (Spring, signal-of-service):** `KAFKA_BOOTSTRAP_SERVERS=kafka-kafka-bootstrap.kafka.svc:9092`, `KAFKA_TOPIC_REPLICATION_FACTOR=3`, and
  `spring.kafka.properties.security.protocol=SASL_PLAINTEXT`, `sasl.mechanism=SCRAM-SHA-512`, `sasl.jaas.config=<from Secret signal-of-service>`. Use `acks=all` (the Spring default) with idempotence on.
- **Kafka (Go, sos-gateway):** `KAFKA_BROKERS=kafka-kafka-bootstrap.kafka.svc:9092`, `KAFKA_GROUP_PREFIX=sos-gateway`, SCRAM-SHA-512 with the `sos-gateway` user.
- For encryption between nodes, use port **9093** (SASL_SSL) and trust the CA in Secret `kafka-cluster-ca-cert`.
- Users, topics and ACLs live in `roles/rabbitmq/defaults/main.yaml` and `roles/kafka/defaults/main.yaml`. Add an app there and re-run.

### Things to know
- **worker1 is ~160 ms from the other servers.** Writes that must be confirmed by its replica take ~160 ms longer: Kafka `acks=all`, and RabbitMQ queues whose leader is on worker1. A third server in Europe would remove that delay; move the third member there.
- **Passwords are reconciled to `secrets/platform/`** on every run. If a password file is missing while its Secret exists, the run stops instead of rotating the password. Restore the file first.
- **Backups:** Kafka and RabbitMQ keep 3 copies but no off-cluster backup. Export RabbitMQ definitions (`rabbitmqctl export_definitions`) before big changes.

---

## 📈 Observability: metrics, logs, traces (Grafana, Prometheus, Loki, Jaeger)

Everything is free software, viewed in one Grafana, and runs in namespace `observability`. Kafka is monitored this way instead of Confluent Control Center: that is an enterprise-licensed component, which on a 3-broker cluster only runs as a 30-day trial, and its dashboards need Confluent Server brokers; this cluster runs Apache Kafka (Strimzi). See `production.md` MSG-01, option B, in the master repo.

```text
 app pods ──OTLP──▶ Alloy (one per node) ──traces──▶ Jaeger ──span metrics──┐
 pod logs, journal,        │                 └─UI: jaeger.testing (authentik)  │
 kubelet log ─────────────▶├──logs──────────▶ Loki                             ▼
 Kubernetes events ───────▶┘  (once, clustered)                           Prometheus ◀── node-exporter, kube-state-metrics,
                                                                                         kubelet, Kafka, RabbitMQ, Loki, Alloy
 Grafana (grafana.testing, authentik) ◀── Prometheus + Loki + Jaeger, linked: trace ⇄ its logs, graph ⇄ example trace
```

| What | Where |
| :--- | :--- |
| Grafana | https://grafana.testing.autofik.com, or the **Grafana** tile in authentik: signs you in through authentik automatically (`platform-admins` = Admin, others Viewer). Break-glass: https://grafana.testing.autofik.com/login?disableAutoLogin as `admin` / `secrets/platform/grafana_admin_password` |
| Metrics | Prometheus, 15 days / 18 GB: every node (node-exporter), every pod and container (kubelet, cAdvisor, kube-state-metrics), Kafka, RabbitMQ, and the observability stack itself |
| Logs | **Loki, 30 days**: every pod's stdout/stderr, each node's journal (rke2, sshd, kernel...), the RKE2 kubelet log, Kubernetes events. Grafana → **Drilldown → Logs**, **Explore → Loki**, or dashboard *Logs / Kubernetes / Pod Logs* |
| Traces | **Jaeger, 7 days**: https://jaeger.testing.autofik.com (authentik, `platform-admins`; tile in authentik), or Grafana → **Explore → Jaeger**. The **Monitor** tab shows request rate, errors and latency per service and operation |
| Dashboards | *Kubernetes* (cluster, namespaces, nodes, pods, workloads: the chart's set plus the dotdc views), *Nodes* (Node Exporter Full), *Logs*, *Kafka* (Strimzi, incl. **consumer lag**), *RabbitMQ* |
| Alerts | Kubernetes and node defaults (incl. disks filling up), Strimzi's Kafka rules, and Loki / Alloy / Jaeger health, in Grafana → Alerting |
| Topics, consumer groups, messages | Kafka UI (kafbat): https://kafka.testing.autofik.com |

```bash
make monitoring   # all of it, in order, ending with an end-to-end check (safe to re-run)
make loki         # Loki only
make jaeger       # Jaeger + its authentik app and route
make alloy        # Alloy, then the end-to-end check: a test trace and log line through Alloy,
                  # read back from Jaeger and Loki via Grafana; logs from every node; events
```

The playbook's last step proves the whole path: a test trace and log line go into Alloy like an app would send them, and must come back out of Jaeger and Loki through Grafana's datasources. It also checks that every node ships pod logs and journal, and that Kubernetes events arrive. Steps that go through the internet (Cloudflare) are tagged `public`; `--skip-tags public` leaves them out.

### Sending traces (and metrics) from the apps
Point the OpenTelemetry SDK or agent at Alloy. Each pod reaches the Alloy on its own node:
```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy.observability.svc:4318   # or :4317 with OTEL_EXPORTER_OTLP_PROTOCOL=grpc
OTEL_SERVICE_NAME=booking                                         # the name you'll search for in Jaeger
OTEL_TRACES_SAMPLER=parentbased_traceidratio
OTEL_TRACES_SAMPLER_ARG=1.0      # keep all traces; lower it (e.g. 0.2) for busy services
OTEL_LOGS_EXPORTER=none          # stdout is collected already; OTLP logs would arrive twice
OTEL_METRICS_EXPORTER=otlp       # lands in Prometheus (or keep exposing /metrics + a ServiceMonitor)
```
- **Java (Spring):** start with `-javaagent:/otel/opentelemetry-javaagent.jar`; the agent instruments HTTP, JDBC, Kafka and RabbitMQ clients by itself.
- **Go:** use the OTel SDK with the `otlptracehttp` exporter (it reads the same variables).
- **Logs ↔ traces:** write the trace id in your log lines (for example a JSON field `trace_id`, or Logback's `%X{trace_id}` with the Java agent). Alloy turns it into Loki metadata. In Grafana, a log line then gets an **Open trace in Jaeger** button, and a span's **Logs for this span** shows its log lines.
- Alloy adds `k8s.namespace.name`, `k8s.pod.name`, `k8s.deployment.name` and similar attributes to every span, based on the sender's pod IP.
- Don't send to Jaeger directly: a NetworkPolicy only lets Alloy in.

### How it is built for this cluster
| | Runs on | Requests / limit | Storage |
| :--- | :--- | :--- | :--- |
| Loki 3.7.8 (chart 18.13.7, monolithic) | 1 pod, `eu` site, preferably not the 12 GB master | 250m, 1 GiB / 2 GiB | 50 Gi `local-path-retain`, 30 days retention by the compactor |
| Jaeger 2.20.0 (Badger storage; 2.21+ drops the API Grafana uses) | 1 pod, `eu` site, preferably not the master | 100m, 256 MiB / 1 GiB | 20 Gi `local-path-retain`, spans kept 7 days |
| Alloy v1.20.0 (chart 1.13.0) | every node (DaemonSet) | 50m, 128 MiB / 512 MiB | read positions in `/var/lib/alloy` on the node |
| Prometheus, Grafana | `eu` site | unchanged | unchanged |

- **One Loki and one Jaeger:** with only node-local disks (no S3/object storage), each can run only one copy. If its node goes down, logs and traces stop being stored until it is back. Alloy keeps retrying for about an hour, and file and journal logs are read on from where Alloy stopped, so they arrive late but aren't lost. Spans are queued for 10 minutes only. Real HA needs object storage (S3/MinIO) for Loki and an OpenSearch/ClickHouse backend for Jaeger.
- **Disk:** `local-path` doesn't enforce volume sizes, and the node disks are shared. Volume is limited by retention and Loki's ingestion limits (`roles/loki/defaults/main.yaml`). The node-exporter alerts *NodeFilesystemSpaceFillingUp* / *AlmostOutOfSpace* warn before a disk fills. Today's raw logs are about 0.5 GB/day, which takes a few GB compressed over 30 days.
- **worker1 is 160 ms away:** its Alloy batches and compresses before sending, and apps there talk to the Alloy on their own node.
- **Security:**
  - node-exporter needs the host network, and the node IPs are public. It now listens on `127.0.0.1` only, behind kube-rbac-proxy on `:9100` (TLS + Prometheus' token), so anonymous requests get `401`.
  - Loki and Jaeger have no login: NetworkPolicies let in only Alloy, Grafana, Prometheus and Traefik.
  - The Jaeger UI is behind authentik.
  - Alloy runs as root (the log files are root-only) but with every capability dropped and a read-only root filesystem.
  - RKE2's `containerd.log` isn't collected: it sits inside containerd's root directory, and mounting that would let Alloy read every container's files. Image-pull errors still show up as Kubernetes events.
- **Not changed here:** RKE2 itself still answers on the public IPs with Calico's metrics (`:9091`) and flannel's health (`:8081`); kube-rbac-proxy's health check is on `:8888` (TLS, `/healthz` only). A host firewall allowing those ports only between the nodes would close them.
- **No Alertmanager yet** (same as the master cluster): rules are evaluated and shown in Grafana, but nothing is sent. Add a receiver (Slack, email) and set `alertmanager.enabled: true` in `roles/monitoring/templates/values.yaml.j2`. `PrometheusNotConnectedToAlertmanagers` is switched off until then.
- **Control-plane scraping is off:** RKE2 binds etcd, the scheduler, the controller-manager and kube-proxy to localhost, so those targets are disabled instead of showing as permanently down.
- **Upgrades:** bump the version in the role's `defaults/main.yaml` and re-run its `make` target. Jaeger's volume size can't be changed in place (StatefulSet): delete the StatefulSet with `--cascade=orphan`, then re-run `make jaeger`.

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