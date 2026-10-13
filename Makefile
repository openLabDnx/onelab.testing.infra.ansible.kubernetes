.PHONY: help check setup-ssh ping prep master workers deploy verify reset nodes pods \
	storage longhorn longhorn-status storage-migrate local-path-remove \
	vault vault-unseal vault-status vault-ui vault-reset \
	cloudflare cloudflare-connector cloudflare-status cloudflare-reset \
	apisix apisix-status apisix-admin apisix-reset \
	platform traefik authentik argocd portainer messaging rabbitmq kafka monitoring \
	loki jaeger alloy autoscaling

KUBECONFIG ?= kubeconfig/autofik-rke2.yaml

help:
	@echo "================================================================="
	@echo "       Autofik Kubernetes RKE2 HA Cluster Automation             "
	@echo "================================================================="
	@echo "make check       : Test basic network and SSH connectivity"
	@echo "make setup-ssh   : Generate SSH key and push to nodes"
	@echo "make ping        : Run Ansible ping against all cluster nodes"
	@echo "make prep        : Configure node prerequisites (swap, sysctl, etc.)"
	@echo "make master      : Install and configure RKE2 Server (Master)"
	@echo "make workers     : Install and configure RKE2 Agents (Workers)"
	@echo "make deploy      : Run full deployment (prep -> master -> workers)"
	@echo "make verify      : Check cluster health via Ansible"
	@echo "make nodes       : Run kubectl get nodes (using local kubeconfig)"
	@echo "make pods        : Run kubectl get pods -A (using local kubeconfig)"
	@echo "make reset       : Cleanly uninstall RKE2 from all nodes"
	@echo "-----------------------------------------------------------------"
	@echo "make storage     : Longhorn: node prerequisites, StorageClasses, smoke test, UI behind SSO"
	@echo "make longhorn    : Same as make storage"
	@echo "make longhorn-status : Longhorn nodes and volumes (copies, health, size)"
	@echo "make storage-migrate : Move the volumes still on local-path to Longhorn (app by app)"
	@echo "make local-path-remove : Remove local-path-provisioner once nothing uses it"
	@echo "make vault       : Deploy Vault HA (storage -> helm -> init -> unseal)"
	@echo "make vault-unseal: Unseal Vault pods after a restart"
	@echo "make vault-status: Show Vault pods, seal state and raft peers"
	@echo "make vault-ui    : SSH tunnel to the Vault UI at https://127.0.0.1:8200"
	@echo "make vault-reset : DESTROY Vault and all of its data"
	@echo "-----------------------------------------------------------------"
	@echo "make cloudflare        : Cloudflare Tunnel, DNS, Access + cloudflared"
	@echo "make cloudflare-connector : Only (re)deploy cloudflared (no API calls)"
	@echo "make cloudflare-status : Tunnel health, edge certs, live probes"
	@echo "make cloudflare-reset  : Delete tunnel, DNS records, Access app"
	@echo "-----------------------------------------------------------------"
	@echo "make apisix        : Deploy APISIX gateway HA (etcd x3, Admin UI, smoke test)"
	@echo "make apisix-status : Gateway/etcd pods, HPA, etcd health, route counts"
	@echo "make apisix-admin  : SSH tunnel to the Admin API/UI at http://127.0.0.1:9180"
	@echo "make apisix-reset  : DESTROY APISIX and all routes/consumers"
	@echo "-----------------------------------------------------------------"
	@echo "make platform   : Traefik + authentik (SSO) + Argo CD + Portainer, in order"
	@echo "make traefik    : Traefik settings (no hostPorts) + dashboard behind SSO"
	@echo "make authentik  : PostgreSQL (CloudNativePG x3) + authentik + SSO blueprint"
	@echo "make argocd     : Argo CD HA with authentik SSO"
	@echo "make portainer  : Portainer with authentik SSO"
	@echo "-----------------------------------------------------------------"
	@echo "make messaging  : cert-manager + RabbitMQ + Kafka (needs make platform)"
	@echo "make rabbitmq   : RabbitMQ 3-node cluster, app users, UI behind SSO"
	@echo "make kafka      : Kafka (Strimzi, KRaft x3), topics, users, Kafka UI behind SSO"
	@echo "make monitoring : Metrics + logs + traces: Prometheus, Grafana (SSO), Loki, Jaeger, Alloy"
	@echo "make loki       : Loki (logs, 30 days) only"
	@echo "make jaeger     : Jaeger (traces, UI behind SSO) only"
	@echo "make alloy      : Alloy (log/trace collection) + end-to-end logs/traces check"
	@echo "make autoscaling: Pod autoscaling (HPA) for authentik, Argo CD, Kafka UI, cloudflared"
	@echo "================================================================="

check:
	@./scripts/check_connectivity.sh

setup-ssh:
	@./scripts/setup_ssh_keys.sh

ping:
	ansible rke2_cluster -m ping

prep:
	ansible-playbook playbooks/01-prerequisites.yaml

master:
	ansible-playbook playbooks/02-rke2-server.yaml

workers:
	ansible-playbook playbooks/03-rke2-agent.yaml

deploy:
	ansible-playbook site.yaml

verify:
	ansible-playbook playbooks/04-verify.yaml

reset:
	ansible-playbook playbooks/reset.yaml

storage:
	ansible-playbook playbooks/05-storage.yaml

longhorn: storage

longhorn-status:
	ansible-playbook playbooks/longhorn-status.yaml

storage-migrate:
	ansible-playbook playbooks/storage-migrate.yaml

local-path-remove:
	ansible-playbook playbooks/local-path-remove.yaml

vault:
	ansible-playbook playbooks/05-storage.yaml playbooks/06-vault.yaml

vault-unseal:
	ansible-playbook playbooks/vault-unseal.yaml

vault-status:
	ansible-playbook playbooks/vault-status.yaml

vault-ui:
	@./scripts/vault_ui_tunnel.sh

vault-reset:
	ansible-playbook playbooks/vault-reset.yaml

cloudflare:
	ansible-playbook playbooks/07-cloudflare.yaml

cloudflare-connector:
	ansible-playbook playbooks/07-cloudflare.yaml --tags cloudflared

cloudflare-status:
	ansible-playbook playbooks/cloudflare-status.yaml

cloudflare-reset:
	ansible-playbook playbooks/cloudflare-reset.yaml

apisix:
	ansible-playbook playbooks/05-storage.yaml playbooks/08-apisix.yaml

apisix-status:
	ansible-playbook playbooks/apisix-status.yaml

apisix-admin:
	@./scripts/apisix_admin_tunnel.sh

apisix-reset:
	ansible-playbook playbooks/apisix-reset.yaml

platform:
	ansible-playbook playbooks/05-storage.yaml playbooks/09-platform.yaml

traefik:
	ansible-playbook playbooks/09-platform.yaml --tags traefik

authentik:
	ansible-playbook playbooks/05-storage.yaml playbooks/09-platform.yaml --tags authentik

argocd:
	ansible-playbook playbooks/09-platform.yaml --tags argocd

portainer:
	ansible-playbook playbooks/09-platform.yaml --tags portainer

messaging:
	ansible-playbook playbooks/10-messaging.yaml

rabbitmq:
	ansible-playbook playbooks/10-messaging.yaml --tags rabbitmq

kafka:
	ansible-playbook playbooks/10-messaging.yaml --tags kafka

monitoring:
	ansible-playbook playbooks/11-monitoring.yaml

loki:
	ansible-playbook playbooks/11-monitoring.yaml --tags loki

jaeger:
	ansible-playbook playbooks/11-monitoring.yaml --tags jaeger

alloy:
	ansible-playbook playbooks/11-monitoring.yaml --tags alloy

autoscaling:
	ansible-playbook playbooks/12-autoscaling.yaml

nodes:
	@if [ -f "$(KUBECONFIG)" ]; then \
		kubectl --kubeconfig=$(KUBECONFIG) get nodes -o wide; \
	else \
		echo "Kubeconfig not found at $(KUBECONFIG). Run 'make master' or 'make deploy' first."; \
	fi

pods:
	@if [ -f "$(KUBECONFIG)" ]; then \
		kubectl --kubeconfig=$(KUBECONFIG) get pods -A -o wide; \
	else \
		echo "Kubeconfig not found at $(KUBECONFIG). Run 'make master' or 'make deploy' first."; \
	fi
