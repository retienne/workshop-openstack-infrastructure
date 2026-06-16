.PHONY: help destroy setup-ssh connect update-hosts autodestroy-timer autodestroy-on-shutdown autodestroy-status autodestroy-attach autodestroy-reschedule autodestroy-cancel

.DEFAULT_GOAL := help

help: ## Show this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

# Configuration
ANSIBLE_DIR = ansible
PRIVATE_KEY ?= .ssh/id_rsa_workshop
TF_DIR = .
TTL ?= 4h
AVAILABLE_WORKSHOPS ?= modern-database-workshop bigdata-spark-workshop stream-processing-workshop
WORKSHOP ?= modern-database-workshop

##@ Main Workflow

up: check-env ## Provision VM infrastructure, install dependencies, and start a workshop (Zero-to-Hero)
	@WORKSHOP_VAL=$$(./scripts/select_workshop.sh "$(WORKSHOP)" "$(AVAILABLE_WORKSHOPS)" "$(origin WORKSHOP)" "$(origin workshop)" "$(workshop)"); \
	if [ -z "$$WORKSHOP_VAL" ]; then exit 1; fi; \
	$(MAKE) _do_up WORKSHOP="$$WORKSHOP_VAL" env="$(env)"

_do_up: setup start

setup: setup-ssh terraform-apply ansible-setup ## Provision VM infrastructure and install dependencies ONLY (no workshop containers)

##@ Application Stack (Docker)

start: check-env ## Start/Switch a workshop environment on an ALREADY PROVISIONED VM
	@WORKSHOP_VAL=$$(./scripts/select_workshop.sh "$(WORKSHOP)" "$(AVAILABLE_WORKSHOPS)" "$(origin WORKSHOP)" "$(origin workshop)" "$(workshop)"); \
	if [ -z "$$WORKSHOP_VAL" ]; then exit 1; fi; \
	IP=$$(terraform output -raw instance_ip 2>/dev/null || true); \
	if [ -z "$$IP" ]; then echo "Failed to get instance IP. Is the infrastructure provisioned?"; exit 1; fi; \
	ENV_VAL="$(env)"; \
	if [ -z "$$ENV_VAL" ]; then \
		ENV_VAL=$$(./scripts/select_environment.sh "$$IP" "$(PRIVATE_KEY)" "$$WORKSHOP_VAL"); \
	fi; \
	if [ -z "$$ENV_VAL" ]; then exit 1; fi; \
	if ! ./scripts/manage_containers.sh check_and_stop "$$IP" "$(PRIVATE_KEY)"; then exit 1; fi; \
	echo "Starting environment $$ENV_VAL..."; \
	ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "$$IP," $(ANSIBLE_DIR)/site.yml --tags env --private-key $(PRIVATE_KEY) -u ubuntu -e workshop_env="$$ENV_VAL" -e github_project="$$WORKSHOP_VAL"

stop: check-env ## Stop the running workshop environment containers
	@WORKSHOP_VAL=$$(./scripts/select_workshop.sh "$(WORKSHOP)" "$(AVAILABLE_WORKSHOPS)" "$(origin WORKSHOP)" "$(origin workshop)" "$(workshop)"); \
	if [ -z "$$WORKSHOP_VAL" ]; then exit 1; fi; \
	IP=$$(terraform output -raw instance_ip 2>/dev/null || true); \
	if [ -z "$$IP" ]; then echo "Failed to get instance IP. Is the infrastructure provisioned?"; exit 1; fi; \
	ENV_VAL="$(env)"; \
	if [ -z "$$ENV_VAL" ]; then \
		ENV_VAL=$$(./scripts/select_environment.sh "$$IP" "$(PRIVATE_KEY)" "$$WORKSHOP_VAL" "all" "Stop all environments"); \
	fi; \
	if [ -z "$$ENV_VAL" ]; then exit 1; fi; \
	if [ "$$ENV_VAL" = "all" ]; then \
		./scripts/manage_containers.sh stop_all "$$IP" "$(PRIVATE_KEY)"; \
	else \
		ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "$$IP," $(ANSIBLE_DIR)/site.yml --tags stop --private-key $(PRIVATE_KEY) -u ubuntu -e workshop_env="$$ENV_VAL" -e github_project="$$WORKSHOP_VAL"; \
	fi

##@ Virtual Machine (Infra)

pause: check-env check-openstack-cli ## Pause the OpenStack VM to save compute costs (retains disk state)
	@ID=$$(terraform output -raw instance_id 2>/dev/null || true); \
	if [ -z "$$ID" ]; then echo "Failed to get instance ID."; exit 1; fi; \
	echo "Pausing VM (dataplatform-workshop)..."; \
	openstack server stop "$$ID"

unpause: check-env check-openstack-cli ## Unpause the OpenStack VM
	@ID=$$(terraform output -raw instance_id 2>/dev/null || true); \
	if [ -z "$$ID" ]; then echo "Failed to get instance ID."; exit 1; fi; \
	echo "Unpausing VM (dataplatform-workshop)..."; \
	openstack server start "$$ID"; \
	echo "💡 Note: It may take a minute or two for the VM to fully boot and services to become available."

destroy: check-env ## Destroy the infrastructure and remove SSH known hosts
	@IP=$$(terraform output -raw instance_ip 2>/dev/null || true); \
	if [ -n "$$IP" ]; then \
		echo "Removing $$IP from known_hosts..."; \
		ssh-keygen -R "$$IP" >/dev/null 2>&1 || true; \
	fi
	@echo "Destroying infrastructure..."
	terraform destroy -auto-approve

##@ Access & Monitoring

status: check-env ## Quick overview of the OpenStack VM and Docker status
	@ID=$$(terraform output -raw instance_id 2>/dev/null || true); \
	./scripts/utils.sh status "$$(terraform output -raw instance_ip 2>/dev/null || true)" "$(PRIVATE_KEY)" "$$ID"

open: ## Open the workshop landing page in your default browser
	@./scripts/utils.sh open_browser "$$(terraform output -raw instance_ip 2>/dev/null || true)"

connect: ## SSH into the provisioned machine
	@IP=$$(terraform output -raw instance_ip); \
	if [ -z "$$IP" ]; then \
		echo "Failed to get instance IP from Terraform output"; \
		exit 1; \
	fi; \
	echo "Connecting to ubuntu@$$IP..."; \
	if [ -n "$$KONSOLE_DBUS_SESSION" ] && command -v qdbus >/dev/null 2>&1; then \
		qdbus org.kde.konsole $$KONSOLE_DBUS_SESSION renameSession "ubuntu@dataplatform-workshop" >/dev/null 2>&1 || true; \
	else \
		printf "\033]0;ubuntu@dataplatform-workshop\007"; \
		printf "\033]30;ubuntu@dataplatform-workshop\007"; \
	fi; \
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $(PRIVATE_KEY) ubuntu@$$IP; \
	if [ -n "$$KONSOLE_DBUS_SESSION" ] && command -v qdbus >/dev/null 2>&1; then \
		qdbus org.kde.konsole $$KONSOLE_DBUS_SESSION renameSession "$$(basename $$PWD)" >/dev/null 2>&1 || true; \
	else \
		printf "\033]0;%s\007" "$$(basename $$PWD)"; \
		printf "\033]30;%s\007" "$$(basename $$PWD)"; \
	fi

##@ Auto-Destruction (Linux with systemd only)

autodestroy-timer: ## Schedule infrastructure destruction after a timer (e.g., make autodestroy-timer TTL=4h)
	@./scripts/autodestroy.sh timer "$(TTL)" "$(PWD)"

autodestroy-on-shutdown: ## Schedule infrastructure destruction only on system shutdown or logout
	@./scripts/autodestroy.sh shutdown "" "$(PWD)"

autodestroy-status: ## Check time left on the background auto-destruction
	@./scripts/autodestroy.sh status

autodestroy-attach: ## Attach to the running auto-destruction to see a live countdown
	@./scripts/autodestroy.sh attach

autodestroy-reschedule: ## Reschedule the background auto-destruction (e.g., make autodestroy-reschedule TTL=2h)
	@./scripts/autodestroy.sh reschedule "$(TTL)"

autodestroy-cancel: ## Immediately trigger destruction of the background auto-destruction
	@./scripts/autodestroy.sh cancel

##@ Internal Utilities

update-hosts: ## Update local /etc/hosts with the new IP address
	@./scripts/utils.sh update_hosts "$$(terraform output -raw instance_ip)"

setup-ssh: ## Generate SSH key pair if it doesn't exist
	@./scripts/utils.sh setup_ssh "$(PRIVATE_KEY)"

terraform-init: check-env ## Initialize Terraform configuration
	@echo "Initializing Terraform..."
	terraform init

terraform-apply: terraform-init ## Apply Terraform configuration
	@echo "Applying Terraform configuration..."
	terraform apply -auto-approve

ansible-setup: ## Run the Ansible configuration playbook for base OS (skipping env deployment)
	@echo "Running Ansible playbook..."
	@IP=$$(terraform output -raw instance_ip); \
	if [ -z "$$IP" ]; then \
		echo "Failed to get instance IP from Terraform output"; \
		exit 1; \
	fi; \
	echo "Waiting for SSH to be ready on $$IP..."; \
	sleep 10; \
	ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "$$IP," $(ANSIBLE_DIR)/site.yml --skip-tags env,stop --private-key $(PRIVATE_KEY) -u ubuntu -e github_project="$(WORKSHOP)"

check-env:
	@if [ ! -f "openrc.sh" ]; then \
		echo "❌ Error: openrc.sh file is missing in the root directory."; \
		echo "👉 Please refer to the README.md 'Prerequisites' section to learn how to retrieve it."; \
		exit 1; \
	fi
	@if [ -z "$$OS_AUTH_URL" ]; then \
		echo "❌ Error: OpenStack environment variables are missing."; \
		echo "👉 Please run 'source openrc.sh' before running make commands."; \
		exit 1; \
	fi

check-openstack-cli:
	@if ! command -v openstack >/dev/null 2>&1; then \
		echo "❌ Error: 'openstack' CLI is not installed."; \
		echo "👉 Please install it (e.g., 'pip install python-openstackclient' or 'sudo apt install python3-openstackclient') to use this command."; \
		exit 1; \
	fi
