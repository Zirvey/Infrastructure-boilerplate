# =============================================================
# Infrastructure Boilerplate — Makefile
# =============================================================
# Usage:
#   make init          Initialize Terraform (dev)
#   make plan          Terraform plan (dev)
#   make apply         Terraform apply (dev)
#   make destroy       Terraform destroy (dev)
#   make ansible       Run Ansible playbooks
#   make docker-up     Start Docker Compose stack
#   make docker-down   Stop Docker Compose stack
#   make k8s-deploy    Apply Kubernetes manifests
#   make k8s-delete    Delete Kubernetes resources
#   make lint          Run all linters
#   make fmt           Format all IaC code
#   make test          Run all tests
#   make security      Run security scanners
#   make clean         Tear down local resources
# =============================================================

SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

# ---- Configuration ----
ENV           ?= dev
TF_DIR        := terraform/environments/$(ENV)
ANSIBLE_DIR   := ansible
DOCKER_FILE   := docker/docker-compose.yml
K8S_BASE      := kubernetes/base
K8S_OVERLAY   := kubernetes/overlays/$(ENV)
VERSION       := $(shell cat VERSION 2>/dev/null || echo "0.0.0")

# ---- Colors ----
BLUE   := \033[36m
GREEN  := \033[32m
YELLOW := \033[33m
RESET  := \033[0m

# ---- Help ----
.PHONY: help
help: ## Show this help
	@echo "$(BLUE)Infrastructure Boilerplate v$(VERSION)$(RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-18s$(RESET) %s\n", $$1, $$2}'

# =============================================================
# Terraform
# =============================================================
.PHONY: tf-init tf-plan tf-apply tf-destroy tf-fmt tf-validate tf-output

tf-init: ## Initialize Terraform
	@echo "$(BLUE)[Terraform]$(RESET) Initializing $(ENV) environment..."
	cd $(TF_DIR) && terraform init

tf-plan: ## Terraform plan
	@echo "$(BLUE)[Terraform]$(RESET) Planning $(ENV) environment..."
	cd $(TF_DIR) && terraform plan -var-file=variables.tfvars 2>/dev/null || terraform plan -var="environment=$(ENV)"

tf-apply: ## Terraform apply
	@echo "$(GREEN)[Terraform]$(RESET) Applying $(ENV) environment..."
	cd $(TF_DIR) && terraform apply -var="environment=$(ENV)" -auto-approve

tf-destroy: ## Terraform destroy (⚠️  irreversible)
	@echo "$(YELLOW)[Terraform]$(RESET) Destroying $(ENV) environment..."
	cd $(TF_DIR) && terraform destroy -var="environment=$(ENV)" -auto-approve

tf-output: ## Show Terraform outputs
	cd $(TF_DIR) && terraform output

tf-fmt: ## Format Terraform code
	terraform fmt -recursive terraform/

tf-validate: ## Validate Terraform configurations
	cd $(TF_DIR) && terraform validate

# Aliases for convenience
init: tf-init
plan: tf-plan
apply: tf-apply
destroy: tf-destroy

# =============================================================
# Ansible
# =============================================================
.PHONY: ansible ansible-check ansible-inventory

ansible: ## Run Ansible playbooks
	@echo "$(BLUE)[Ansible]$(RESET) Running playbooks against $(ENV)..."
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit $(ENV)

ansible-check: ## Dry-run Ansible playbooks
	@echo "$(BLUE)[Ansible]$(RESET) Check mode on $(ENV)..."
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit $(ENV) --check --diff

ansible-inventory: ## Show Ansible inventory graph
	cd $(ANSIBLE_DIR) && ansible-inventory -i inventory/hosts.ini --graph

# =============================================================
# Docker
# =============================================================
.PHONY: docker-up docker-down docker-logs docker-build docker-clean

docker-up: ## Start Docker Compose stack
	@echo "$(BLUE)[Docker]$(RESET) Starting services..."
	docker compose -f $(DOCKER_FILE) up -d

docker-down: ## Stop Docker Compose stack
	docker compose -f $(DOCKER_FILE) down

docker-logs: ## Follow Docker Compose logs
	docker compose -f $(DOCKER_FILE) logs -f

docker-build: ## Build Docker images
	docker compose -f $(DOCKER_FILE) build

docker-clean: ## Remove all Docker containers, images, volumes
	docker compose -f $(DOCKER_FILE) down -v --remove-orphans
	docker system prune -f

# =============================================================
# Kubernetes
# =============================================================
.PHONY: k8s-deploy k8s-delete k8s-status k8s-portforward

k8s-deploy: ## Apply Kubernetes manifests
	@echo "$(BLUE)[Kubernetes]$(RESET) Deploying to $(ENV)..."
	@if [ -d "$(K8S_OVERLAY)" ]; then \
		echo "Using Kustomize overlay for $(ENV)..."; \
		kubectl apply -k $(K8S_OVERLAY); \
	else \
		echo "No overlay found for $(ENV), using base manifests..."; \
		kubectl apply -f $(K8S_BASE)/; \
	fi

k8s-delete: ## Delete Kubernetes resources
	kubectl delete -f $(K8S_BASE)/ --ignore-not-found=true

k8s-status: ## Check Kubernetes resource status
	kubectl get all -n application

k8s-portforward: ## Port-forward app service to localhost:3000
	kubectl port-forward -n application svc/app-service 3000:3000

# =============================================================
# Linting & Formatting
# =============================================================
.PHONY: lint fmt

lint: lint-tf lint-ansible lint-yaml lint-docker ## Run all linters

lint-tf: ## Lint Terraform
	@echo "$(BLUE)[Lint]$(RESET) Terraform..."
	@command -v tflint >/dev/null 2>&1 || (echo "$(YELLOW)tflint not installed, skipping$(RESET)" && exit 0)
	tflint --recursive terraform/

lint-ansible: ## Lint Ansible
	@echo "$(BLUE)[Lint]$(RESET) Ansible..."
	@command -v ansible-lint >/dev/null 2>&1 || (echo "$(YELLOW)ansible-lint not installed, skipping$(RESET)" && exit 0)
	ansible-lint $(ANSIBLE_DIR)/playbooks/ || true

lint-yaml: ## Lint YAML files
	@echo "$(BLUE)[Lint]$(RESET) YAML..."
	@command -v yamllint >/dev/null 2>&1 || (echo "$(YELLOW)yamllint not installed, skipping$(RESET)" && exit 0)
	yamllint -d relaxed docker/ kubernetes/ monitoring/ || true

lint-docker: ## Lint Dockerfiles
	@echo "$(BLUE)[Lint]$(RESET) Dockerfiles..."
	@command -v hadolint >/dev/null 2>&1 || (echo "$(YELLOW)hadolint not installed, skipping$(RESET)" && exit 0)
	find . -name "Dockerfile*" -exec hadolint {} \; || true

fmt: tf-fmt ## Format all IaC code
	@echo "$(BLUE)[Format]$(RESET) Running all formatters..."

# =============================================================
# Testing
# =============================================================
.PHONY: test test-terraform test-ansible test-kubernetes

test: test-terraform test-ansible test-kubernetes ## Run all tests

test-terraform: ## Run Terraform tests
	@echo "$(BLUE)[Test]$(RESET) Terraform..."
	@if [ -d "tests/terraform" ]; then \
		cd tests/terraform && go test -v ./...; \
	else \
		echo "No Terraform tests found in tests/terraform/"; \
	fi

test-ansible: ## Run Ansible Molecule tests
	@echo "$(BLUE)[Test]$(RESET) Ansible..."
	@if [ -d "tests/ansible" ]; then \
		cd tests/ansible && molecule test; \
	else \
		echo "No Molecule tests found in tests/ansible/"; \
	fi

test-kubernetes: ## Validate Kubernetes manifests
	@echo "$(BLUE)[Test]$(RESET) Kubernetes..."
	@command -v kubeconform >/dev/null 2>&1 || (echo "$(YELLOW)kubeconform not installed, skipping$(RESET)" && exit 0)
	kubeconform -strict -summary -kubernetes-version=1.27.0 kubernetes/ || true

# =============================================================
# Security
# =============================================================
.PHONY: security security-tfsec security-trivy security-checkov security-gitleaks

security: security-tfsec security-trivy security-checkov security-gitleaks ## Run all security scanners

security-tfsec: ## Scan Terraform with tfsec
	@echo "$(BLUE)[Security]$(RESET) Running tfsec..."
	@command -v tfsec >/dev/null 2>&1 || (echo "$(YELLOW)tfsec not installed, skipping$(RESET)" && exit 0)
	tfsec terraform/ --format=colored || true

security-trivy: ## Scan filesystem with Trivy
	@echo "$(BLUE)[Security]$(RESET) Running Trivy..."
	@command -v trivy >/dev/null 2>&1 || (echo "$(YELLOW)trivy not installed, skipping$(RESET)" && exit 0)
	trivy fs --security-checks=config . || true

security-checkov: ## Scan with Checkov
	@echo "$(BLUE)[Security]$(RESET) Running Checkov..."
	@command -v checkov >/dev/null 2>&1 || (echo "$(YELLOW)checkov not installed, skipping$(RESET)" && exit 0)
	checkov --directory . --quiet || true

security-gitleaks: ## Scan for secrets with Gitleaks
	@echo "$(BLUE)[Security]$(RESET) Running Gitleaks..."
	@command -v gitleaks >/dev/null 2>&1 || (echo "$(YELLOW)gitleaks not installed, skipping$(RESET)" && exit 0)
	gitleaks detect --source . --report-format sarif --report-path gitleaks-report.sarif || true

# =============================================================
# Maintenance
# =============================================================
.PHONY: clean pre-commit-install

clean: docker-clean k8s-delete ## Tear down all local resources
	@echo "$(YELLOW)[Clean]$(RESET) Removing generated files..."
	rm -f gitleaks-report.sarif
	find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)[Clean]$(RESET) Done."

pre-commit-install: ## Install pre-commit hooks
	@echo "$(BLUE)[Setup]$(RESET) Installing pre-commit hooks..."
	@command -v pre-commit >/dev/null 2>&1 || (echo "$(YELLOW)pre-commit not installed. Run: pip install pre-commit$(RESET)" && exit 1)
	pre-commit install
	@echo "$(GREEN)[Setup]$(RESET) Pre-commit hooks installed."
