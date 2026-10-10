.PHONY: help check setup-ssh ping prep master workers deploy verify reset nodes pods

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
