.PHONY: help check setup-ssh ping prep master workers deploy verify reset nodes pods \
	storage vault vault-unseal vault-status vault-ui vault-reset \
	cloudflare cloudflare-connector cloudflare-status cloudflare-reset

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
	@echo "make storage     : Install local-path-provisioner StorageClasses"
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
