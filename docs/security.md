# Security Best Practices

This document outlines security standards and requirements for all infrastructure managed by this repository.

---

## Table of Contents

- [Secrets Management](#secrets-management)
- [IAM Best Practices](#iam-best-practices)
- [Kubernetes RBAC](#kubernetes-rbac)
- [Network Security](#network-security)
- [Container Security](#container-security)
- [Infrastructure Hardening](#infrastructure-hardening)
- [Incident Response](#incident-response)

---

## Secrets Management

### Rules

1. **Never commit plaintext secrets** to the repository
2. Use **SOPS + age** for encrypting secrets stored in Git
3. Rotate all production secrets **every 90 days**
4. Use **AWS Secrets Manager** or **HashiCorp Vault** for runtime secret injection
5. Never pass secrets as environment variables in Docker — use Docker secrets or mounted files

### SOPS Usage

```bash
# Generate an age key (do this once)
age-keygen -o ~/.config/sops/age/keys.txt

# Add your public key to .sops.yaml

# Encrypt a new secrets file
sops -e environments/prod/secrets.yml > environments/prod/secrets.enc.yml

# Edit an encrypted file (decrypts, opens editor, re-encrypts on save)
sops environments/prod/secrets.enc.yml

# Decrypt for inspection
sops -d environments/prod/secrets.enc.yml
```

### Secret Rotation Schedule

| Secret Type | Rotation Period | Method |
|-------------|----------------|--------|
| Database passwords | 90 days | AWS Secrets Manager rotation |
| API keys | 90 days | Manual + update SOPS file |
| TLS certificates | 365 days | cert-manager / Let's Encrypt |
| Grafana admin password | 90 days | SOPS-encrypted ConfigMap |
| Docker registry credentials | 90 days | GitHub Actions OIDC |

---

## IAM Best Practices

### Terraform Service Account

The IAM role used by Terraform in CI/CD should follow **least privilege**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "s3:*",
        "rds:*",
        "vpc:*",
        "iam:PassRole",
        "dynamodb:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": ["us-east-1"]
        }
      }
    }
  ]
}
```

### Rules

1. **No root account usage** — Create dedicated IAM users/roles
2. **Enable MFA** on all human accounts
3. **Use OIDC** for GitHub Actions instead of long-lived access keys
4. **Scope permissions** to specific resources where possible
5. **Audit IAM changes** via CloudTrail
6. **Review unused permissions** quarterly with IAM Access Analyzer

### GitHub Actions OIDC (Recommended)

Replace static AWS credentials with OIDC:

```yaml
# .github/workflows/deploy.yml
permissions:
  id-token: write   # Required for OIDC
  contents: read

steps:
  - name: Configure AWS Credentials
    uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789012:role/terraform-ci-role
      aws-region: us-east-1
```

---

## Kubernetes RBAC

### Principles

1. **No default ServiceAccount usage** — Create dedicated ServiceAccounts per workload
2. **Least privilege Roles** — Avoid `cluster-admin` except for platform admins
3. **Namespace-scoped Roles** — Prefer `Role` over `ClusterRole`
4. **ServiceAccount token automounting** — Disable unless needed

### Example: Minimal ServiceAccount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: application
automountServiceAccountToken: false
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-role
  namespace: application
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-binding
  namespace: application
subjects:
  - kind: ServiceAccount
    name: app-sa
roleRef:
  kind: Role
  name: app-role
  apiGroup: rbac.authorization.k8s.io
```

### Pod Security Standards

Enforce the **restricted** profile on all namespaces:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: application
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

---

## Network Security

### VPC Design

- Public subnets only for load balancers and NAT gateways
- Application servers in **private subnets**
- Database servers in **isolated subnets** (no internet access)
- VPC Flow Logs enabled on all VPCs

### Kubernetes NetworkPolicies

Default-deny all traffic, then explicitly allow:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: application
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app-ingress
  namespace: application
spec:
  podSelector:
    matchLabels:
      app: web-app
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-nginx
      ports:
        - protocol: TCP
          port: 3000
```

### Security Groups

- Follow **least privilege** — open only required ports
- Reference security groups by ID, not CIDR ranges when possible
- Use VPC endpoints instead of NAT for AWS service access

---

## Container Security

### Dockerfile Best Practices

```dockerfile
# Use specific base image version (never :latest)
FROM node:20.11-alpine3.19

# Run as non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Don't run as privileged
# hadolint ignore=DL3002
```

### Container Hardening

1. **Use distroless or Alpine** base images
2. **Pin image digests** in Kubernetes manifests
3. **Scan images** with Trivy in CI (already configured)
4. **Set resource limits** on all containers
5. **Set security contexts** — no privileged, no root, read-only rootfs
6. **Use image pull policies** — `Always` or `IfNotPresent`, never default

### Kubernetes Security Context

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault
  capabilities:
    drop:
      - ALL
```

---

## Infrastructure Hardening

### Terraform

| Check | Rule |
|-------|------|
| S3 buckets | Block public access, enable versioning, enable encryption |
| EBS volumes | Enable encryption |
| RDS instances | Enable encryption, multi-AZ, automated backups |
| EC2 instances | Enable monitoring, use IMDSv2 only |
| Security groups | No 0.0.0.0/0 ingress except on load balancers |
| IAM policies | No `*` on actions and resources |

### Ansible

- Use `ansible-vault` or SOPS for sensitive variables
- Run with `--check` mode before production applies
- Use `become: yes` only when necessary
- Keep roles idempotent — safe to run multiple times

---

## Incident Response

### Detecting a Breach

1. Check CloudTrail for unusual API calls
2. Review VPC Flow Logs for unexpected traffic
3. Check Kubernetes audit logs for unauthorized access
4. Review Grafana dashboards for resource anomalies

### Immediate Actions

1. **Isolate** — Revoke compromised credentials, update security groups
2. **Assess** — Determine scope of access and data exposure
3. **Rotate** — Rotate all potentially compromised secrets
4. **Audit** — Review CloudTrail and audit logs for lateral movement
5. **Document** — Create an incident report with timeline and remediation

### Contact

| Role | Responsibility | Contact |
|------|---------------|---------|
| Platform Lead | Infrastructure decisions | #platform-team |
| Security Lead | Incident response | #security-team |
| On-call Engineer | Immediate response | PagerDuty rotation |

---

## Compliance Scanning in CI

All PRs are automatically scanned with:

| Tool | Scans | Blocks Merge On |
|------|-------|----------------|
| tfsec | Terraform misconfigurations | HIGH severity+ |
| Trivy | Filesystem & image CVEs | CRITICAL severity |
| kube-score | Kubernetes best practices | Grade < C |
| checkov | Multi-IaC policy violations | FAIL |
| gitleaks | Secrets/keys in code | Any match |

To fix a finding locally:

```bash
# Run the same scanner locally
tfsec terraform/
trivy fs .
kube-score score kubernetes/base/*.yaml
checkov --directory .
gitleaks detect --source .
```
