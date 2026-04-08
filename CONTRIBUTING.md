# Contributing Guidelines

Thank you for contributing to Infrastructure Boilerplate! Please read this guide before submitting changes.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Commit Messages](#commit-messages)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Documentation](#documentation)
- [Release Process](#release-process)

---

## Code of Conduct

- Be respectful and constructive in all discussions
- Focus on what is best for the community and the project
- Accept constructive criticism gracefully
- Value diverse perspectives and experiences

---

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/infrastructure-boilerplate.git
   cd infrastructure-boilerplate
   ```
3. Add the upstream remote:
   ```bash
   git remote add upstream https://github.com/your-org/infrastructure-boilerplate.git
   ```
4. Install pre-commit hooks:
   ```bash
   make pre-commit-install
   ```
5. Create a branch for your work:
   ```bash
   git checkout -b feat/your-feature
   ```

---

## Development Workflow

```bash
# Sync with upstream
git fetch upstream
git rebase upstream/main

# Make your changes
# ...

# Lint and test locally
make lint
make security
make test

# Commit your changes
git commit -m "feat: add your feature description"

# Push to your fork
git push origin feat/your-feature

# Open a Pull Request on GitHub
```

---

## Commit Messages

This project follows [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation changes |
| `style` | Formatting, no code change |
| `refactor` | Code refactor, no feature change |
| `perf` | Performance improvement |
| `test` | Adding or updating tests |
| `ci` | CI/CD configuration changes |
| `chore` | Maintenance tasks |
| `revert` | Reverting a commit |

### Examples

```
feat(terraform): add EKS module for Kubernetes cluster
fix(ansible): resolve nginx idempotency issue in web role
docs(kubernetes): update Kustomize overlay documentation
ci(github): add multi-stage pipeline with approval gates
test(terraform): add Terratest for VPC module
chore: bump Terraform version to 1.5.0
```

### Scopes

Use the component name as scope: `terraform`, `ansible`, `docker`, `kubernetes`, `monitoring`, `ci`, `docs`, `scripts`.

---

## Pull Request Process

### Before Submitting

- [ ] Rebase on the latest `main` branch
- [ ] Run `make lint` and fix all issues
- [ ] Run `make security` and address findings
- [ ] Run `make test` and ensure all tests pass
- [ ] Update documentation if behavior changed
- [ ] Add tests for new functionality

### PR Guidelines

1. **Title** — Use Conventional Commits format
   - `feat(terraform): add VPC peering module`
   - `fix(ansible): fix PostgreSQL config template`

2. **Description** — Fill out the PR template completely
   - What changed and why
   - How it was tested
   - Screenshots/outputs if applicable

3. **Size** — Keep PRs under ~400 lines when possible
   - Large PRs are harder to review thoroughly
   - Split complex changes into multiple PRs

4. **Review** — Address all review comments before merge
   - Request re-review after making changes
   - Resolve conversations when addressed

### Approval Requirements

- Minimum 1 approval from a maintainer
- All CI checks must pass
- No unresolved review comments

---

## Coding Standards

### Terraform

- Run `terraform fmt` before committing (enforced in CI)
- Use `snake_case` for variable and output names
- Document all variables with descriptions
- Pin provider versions with `~>` operator
- Use `for_each` instead of `count` for resources with indices
- Add tags to all AWS resources

### Ansible

- Run `ansible-lint` before committing (enforced in CI)
- Use YAML, not JSON, for playbooks
- All roles must be idempotent
- Use handlers for service restarts
- Document role variables in `defaults/main.yml`
- Use `become: yes` only when necessary

### Kubernetes / Kustomize

- Run `kubeconform` before committing
- All containers must have resource requests and limits
- Include liveness and readiness probes
- Use specific image tags, never `:latest` in production
- Set security contexts (runAsNonRoot, drop capabilities)

### Docker

- Run `hadolint` on Dockerfiles
- Use specific base image versions
- Run as non-root user
- Minimize image layers
- Use `.dockerignore` to exclude unnecessary files

### Shell Scripts

- Use `set -euo pipefail` at the top
- Quote all variables
- Use lowercase function names
- Add comments for non-obvious logic

---

## Testing Requirements

### Terraform

- Add Terratest for new modules
- Tests should verify:
  - Module initializes without errors
  - Plan succeeds
  - Expected outputs are produced
  - Resource attributes match expectations

### Ansible

- Add Molecule tests for new roles
- Tests should verify:
  - Role converges without errors
  - Packages are installed
  - Services are running
  - Config files have correct content

### Kubernetes

- OPA policies should cover new manifest patterns
- kubeconform must pass on all manifests
- Manual testing on a real cluster for new features

---

## Documentation

- Update docs alongside code changes
- Use Markdown with consistent heading levels
- Include code examples where helpful
- Add diagrams for architectural changes (Mermaid preferred)
- Update the CHANGELOG for user-facing changes

### Documentation Structure

| File | Purpose |
|------|---------|
| `README.md` | Project overview, quick start |
| `docs/ONBOARDING.md` | New team member guide |
| `docs/terraform.md` | Terraform reference |
| `docs/ansible.md` | Ansible reference |
| `docs/kubernetes.md` | Kubernetes reference |
| `docs/monitoring.md` | Monitoring reference |
| `docs/security.md` | Security best practices |
| `docs/architecture.md` | Architecture diagrams |
| `docs/TROUBLESHOOTING.md` | Common issues and fixes |

---

## Release Process

Releases follow [Semantic Versioning](https://semver.org/):

| Version | When to Bump |
|---------|-------------|
| `MAJOR` | Breaking changes (e.g., Terraform backend change) |
| `MINOR` | New features (e.g., new module, new monitoring component) |
| `PATCH` | Bug fixes (e.g., typo fix, config correction) |

### Creating a Release

1. Update `CHANGELOG.md` — move items from `[Unreleased]` to new version
2. Update `VERSION` file
3. Commit: `chore: release v0.2.0`
4. Tag and push:
   ```bash
   git tag -a v0.2.0 -m "Release v0.2.0"
   git push origin v0.2.0
   ```
5. Create a GitHub Release with changelog notes

---

## Questions?

- Open a [Discussion](https://github.com/your-org/infrastructure-boilerplate/discussions)
- Open an [Issue](https://github.com/your-org/infrastructure-boilerplate/issues)
- Reach out on `#platform-engineering` Slack
