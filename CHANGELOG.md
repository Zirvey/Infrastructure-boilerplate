# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2025-04-08

### Added

- Terraform modules (VPC) with multi-AZ support
- Terraform environment configurations (dev, staging, prod)
- S3 backend with DynamoDB state locking (configurable)
- Ansible playbooks for server configuration (common, web, db roles)
- Ansible inventory with multi-environment host definitions
- Docker Compose multi-service stack (NGINX, app, PostgreSQL)
- Kubernetes base manifests (namespace, deployment, service)
- GitHub Actions CI/CD pipeline for Terraform (plan + apply)
- Prometheus + Grafana monitoring stack structure
- Project Makefile with common operations
- Pre-commit hooks (tflint, ansible-lint, yamllint, hadolint, gitleaks)
- Linting configuration (.tflint.hcl, .yamllint, .ansible-lint)
- GitHub issue and PR templates
- Initial documentation (README, architecture, onboarding)
- Security scanning integration (tfsec, Trivy, checkov, kube-score)
- SOPS + age secrets encryption support
- ArgoCD GitOps structure with Kustomize overlays
- Terratest example tests for Terraform
- Molecule test structure for Ansible roles
- OPA/Conftest policy enforcement for Kubernetes
- Loki + Promtail logging stack
- Velero backup automation for Kubernetes
- k6 load testing configuration
- Multi-provider examples (AWS, Hetzner, Proxmox)

### Changed

### Deprecated

### Removed

### Fixed

### Security

[Unreleased]: https://github.com/your-org/infrastructure-boilerplate/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/your-org/infrastructure-boilerplate/releases/tag/v0.1.0
