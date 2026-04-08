# Onboarding Guide

Welcome to the Infrastructure Boilerplate! This guide will get you up and running in under 30 minutes.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [1. Clone & Setup](#1-clone--setup)
- [2. Run Locally (Docker)](#2-run-locally-docker)
- [3. Provision Dev Environment](#3-provision-dev-environment)
- [4. Deploy to Kubernetes](#4-deploy-to-kubernetes)
- [5. Access Monitoring](#5-access-monitoring)
- [6. Make Your First Change](#6-make-your-first-change)
- [7. Next Steps](#7-next-steps)

---

## Prerequisites

Install the following tools before proceeding:

| Tool | Version | Install |
|------|---------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.5.0 | `brew install terraform` |
| [Ansible](https://docs.ansible.com/) | >= 2.14 | `pip install ansible` |
| [Docker](https://www.docker.com/products/docker-desktop/) | >= 20.10 | Download from docker.com |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | >= 1.27 | `brew install kubectl` |
| [AWS CLI](https://aws.amazon.com/cli/) | >= 2.0 | `brew install awscli` |
| [make](https://www.gnu.org/software/make/) | any | Pre-installed on most systems |

**Optional but recommended:**

| Tool | Purpose | Install |
|------|---------|---------|
| pre-commit | Git hooks | `brew install pre-commit` |
| sops + age | Secrets encryption | `brew install sops age` |
| tflint | Terraform linting | `brew install tflint` |
| kubeconform | K8s validation | `brew install kubeconform` |

---

## 1. Clone & Setup

```bash
# Clone the repository
git clone https://github.com/your-org/infrastructure-boilerplate.git
cd infrastructure-boilerplate

# Install pre-commit hooks (optional but recommended)
make pre-commit-install

# Configure AWS credentials
aws configure
# Or use SSO: aws sso login
```

Verify your setup:

```bash
make help
```

You should see all available commands.

---

## 2. Run Locally (Docker)

The fastest way to see the stack in action:

```bash
# Start the full stack
make docker-up

# Check running services
docker compose -f docker/docker-compose.yml ps

# View application logs
make docker-logs

# Access the app
open http://localhost:3000
```

**Stop everything:**

```bash
make docker-down
```

---

## 3. Provision Dev Environment

Provision cloud infrastructure on AWS:

```bash
# Navigate to dev environment
cd terraform/environments/dev

# Initialize Terraform (downloads providers)
make tf-init

# Preview changes
make tf-plan

# Apply infrastructure
make tf-apply
```

**What gets created:**

- VPC with public and private subnets (multi-AZ)
- Internet Gateway + NAT Gateway
- EC2 instances (as defined in modules.tf)
- Security groups
- IAM roles and policies
- S3 bucket for Terraform state

**View outputs:**

```bash
make tf-output
```

**Configure servers with Ansible:**

```bash
# Update inventory with provisioned IPs
# Edit ansible/inventory/hosts.ini

# Run playbooks
make ansible
```

---

## 4. Deploy to Kubernetes

If you have a Kubernetes cluster (EKS, minikube, kind):

```bash
# Connect kubectl to your cluster
aws eks update-kubeconfig --name your-cluster --region us-east-1

# Deploy using Kustomize (auto-selects overlay for your ENV)
make k8s-deploy ENV=dev

# Check deployment status
make k8s-status

# Port-forward to access locally
make k8s-portforward
```

**Using ArgoCD (GitOps):**

If ArgoCD is installed:

```bash
# ArgoCD will auto-sync from Git
# Check sync status
argocd app list

# Manually sync if needed
argocd app sync web-app
```

---

## 5. Access Monitoring

```bash
# Deploy monitoring stack
kubectl apply -f monitoring/

# Access Grafana
kubectl port-forward -n monitoring svc/grafana 3001:3000

# Open in browser
open http://localhost:3001
# Default credentials: admin / admin (change in production!)
```

---

## 6. Make Your First Change

Follow the standard PR workflow:

```bash
# Create a feature branch
git checkout -b feat/increase-replicas

# Make your change (e.g., update replicas in kubernetes/overlays/prod/kustomization.yaml)

# Validate locally
make lint
make test

# Commit using Conventional Commits
git commit -m "feat: increase production replicas to 5"

# Push and create PR
git push origin feat/increase-replicas
```

**What happens next:**

1. GitHub Actions runs lint, security scan, and Terraform plan
2. Team reviews the PR
3. On merge, CI/CD pipeline applies changes automatically
4. You get a Slack notification on completion

---

## 7. Next Steps

| Topic | Resource |
|-------|----------|
| Terraform module reference | [docs/terraform.md](terraform.md) |
| Ansible roles guide | [docs/ansible.md](ansible.md) |
| Kubernetes deployment | [docs/kubernetes.md](kubernetes.md) |
| Monitoring setup | [docs/monitoring.md](monitoring.md) |
| Security best practices | [docs/security.md](security.md) |
| Troubleshooting | [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) |
| Architecture overview | [docs/architecture.md](architecture.md) |

### Join the Team

- **Slack:** `#platform-engineering`
- **On-call:** PagerDuty rotation schedule
- **Architecture reviews:** Bi-weekly Thursday meetings
- **Incident runbooks:** `docs/runbooks/`

---

## Quick Reference Card

```bash
# Most-used commands
make help            # Show all commands
make docker-up       # Start local stack
make tf-plan         # Preview infra changes
make tf-apply        # Apply infra changes
make ansible         # Configure servers
make k8s-deploy      # Deploy to Kubernetes
make lint            # Run all linters
make security        # Run security scanners
make test            # Run all tests
```
