# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] — 2025-04-08

### Added

- Multi-stage CI/CD pipeline with approval gates (`deploy.yml`)
- Linting workflow for Terraform, Ansible, YAML, Dockerfile, secrets (`lint.yml`)
- Automated security scanning: tfsec, Trivy, kube-score, Checkov (`security.yml`)
- Kustomize overlays for dev/staging/prod environments
- ArgoCD GitOps application and project manifests
- PodDisruptionBudget for production workloads
- Loki + Promtail logging stack manifests
- Velero backup automation with daily/weekly schedules
- k6 load testing configuration
- Terratest integration tests for Terraform
- Molecule test structure for Ansible roles
- OPA/Conftest policies for Kubernetes manifests
- Multi-provider examples (AWS, Hetzner, Proxmox)
- SOPS + age secrets encryption configuration
- Comprehensive documentation: architecture, onboarding, troubleshooting, component guides

### Fixed

- Kubernetes deployment: pin image tag to `:1.0.0` (was `:latest`)
- Add container security contexts (runAsNonRoot, drop ALL capabilities, readOnlyRootFilesystem)
- Add ephemeral-storage resource requests and limits
- Separate liveness (`/health`) and readiness (`/ready`) probe endpoints
- Fix Trivy action version in security workflow
- Fix tfsec installation in security workflow (install script broken)
- Fix Checkov SARIF file generation handling
- Skip Docker lint when no Dockerfile exists
- Skip ArgoCD and Slack jobs when secrets are not configured
- Use `terraform init -backend=false` for validation without remote backend

### Changed

- Bump CodeQL action from v3 to v4
- kube-score: ignore false positive user/group ID warnings (UID 1000 is standard)
- GitHub Actions: use OIDC authentication instead of static credentials (documented)

### Security

- Enforce `imagePullPolicy: Always` on all containers
- Add `automountServiceAccountToken: false` on pods
- Pod-level and container-level security contexts enforced

[Unreleased]: https://github.com/your-org/infrastructure-boilerplate/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/your-org/infrastructure-boilerplate/releases/tag/v0.2.0
[0.1.0]: https://github.com/your-org/infrastructure-boilerplate/releases/tag/v0.1.0
