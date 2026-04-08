# Troubleshooting Guide

Common issues and their solutions, organized by component.

---

## Table of Contents

- [Terraform](#terraform)
- [Ansible](#ansible)
- [Docker](#docker)
- [Kubernetes](#kubernetes)
- [CI/CD](#cicd)
- [Monitoring](#monitoring)
- [General](#general)

---

## Terraform

### Terraform state lock is stuck

**Symptom:** `Error: Error locking state: ConditionalCheckFailedException`

**Cause:** A previous Terraform run crashed or was interrupted, leaving a stale DynamoDB lock.

**Solution:**

```bash
# 1. Check who holds the lock
aws dynamodb get-item \
  --table-name terraform-lock-table \
  --key '{"LockID": {"S": "env/dev/terraform.tfstate-md5"}}'

# 2. If the lock is stale (Info shows an old run ID), force-unlock
terraform force-unlock <LOCK_ID>

# 3. As a last resort, delete the lock entry
aws dynamodb delete-item \
  --table-name terraform-lock-table \
  --key '{"LockID": {"S": "env/dev/terraform.tfstate-md5"}}'
```

> ⚠️ Only force-unlock if you're certain no one else is running Terraform.

---

### Terraform plan shows unwanted resource replacement

**Symptom:** `must be replaced` for resources that shouldn't change.

**Cause:** A configuration change forces recreation (e.g., changing AMI, subnet CIDR, or DB engine version).

**Solution:**

```bash
# Review what's changing
terraform plan -var="environment=dev" | grep -A 3 "forces replacement"

# If the change is unintentional, revert the config
# If intentional, plan the downtime and communicate with the team
```

---

### Provider installation fails

**Symptom:** `Failed to install provider` during `terraform init`.

**Cause:** Network issues, registry downtime, or version constraint conflicts.

**Solution:**

```bash
# Clear plugin cache
rm -rf .terraform/
rm -f .terraform.lock.hcl

# Re-initialize
terraform init

# If behind a proxy, set:
export TF_CLI_ARGS_init="-plugin-dir=/path/to/local/plugins"
```

---

### S3 backend bucket doesn't exist

**Symptom:** `Error configuring the backend "s3": NoSuchBucket`

**Solution:**

```bash
# Create the state bucket
aws s3api create-bucket \
  --bucket your-terraform-state-bucket \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Create the DynamoDB lock table
aws dynamodb create-table \
  --table-name terraform-lock-table \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

---

## Ansible

### Ansible SSH connection refused

**Symptom:** `UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh"}`

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| Wrong SSH key | Add `-e ansible_ssh_private_key_file=~/.ssh/id_rsa` |
| Wrong user | Set `ansible_user=ec2-user` in inventory |
| Security group blocks SSH | Add port 22 ingress to the instance's SG |
| Host not reachable | Verify the IP in `inventory/hosts.ini` |

```bash
# Test SSH connectivity
ansible -i inventory/hosts.ini dev -m ping

# Run with verbose SSH output
ansible-playbook -i inventory/hosts.ini playbooks/site.yml -vvvv
```

---

### Ansible role is not idempotent

**Symptom:** Running the playbook twice produces different results or errors.

**Solution:** Ensure all tasks use state-based modules:

```yaml
# Bad — runs every time
- name: Install nginx
  command: apt-get install -y nginx

# Good — idempotent
- name: Install nginx
  apt:
    name: nginx
    state: present
```

Run with `--check --diff` to verify idempotency:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check --diff
```

---

## Docker

### Docker Compose port already in use

**Symptom:** `Bind for 0.0.0.0:3000 failed: port is already allocated`

**Solution:**

```bash
# Find what's using the port
lsof -i :3000

# Kill the process or change the port in docker-compose.yml
# services:
#   app:
#     ports:
#       - "3001:3000"
```

---

### Container keeps restarting

**Symptom:** `docker compose ps` shows a container in `Restarting` state.

**Solution:**

```bash
# View logs for the failing container
docker compose logs app

# Common causes:
# 1. Missing environment variables → check .env file
# 2. Database not ready → add depends_on + healthcheck
# 3. Wrong command/entrypoint → check Dockerfile

# Run interactively to debug
docker compose run --entrypoint /bin/sh app
```

---

## Kubernetes

### Pod stuck in Pending state

**Symptom:** `kubectl get pods` shows `Pending`

**Solution:**

```bash
# Describe the pod for events
kubectl describe pod <pod-name> -n application

# Common causes:
# 1. Insufficient resources → check node capacity
kubectl top nodes

# 2. PVC can't be bound → check storage class
kubectl get storageclass
kubectl get pvc -n application

# 3. Image pull error → check credentials
kubectl describe pod <pod-name> -n application | grep -A 5 "Events"
```

---

### Pod stuck in CrashLoopBackOff

**Symptom:** Pod restarts repeatedly with increasing backoff.

**Solution:**

```bash
# View logs from the crashing container
kubectl logs <pod-name> -n application --previous

# Check liveness/readiness probes
kubectl describe pod <pod-name> -n application | grep -A 10 "Liveness\|Readiness"

# Common causes:
# 1. Application startup failure → check app logs
# 2. Missing ConfigMap/Secret → verify referenced resources
kubectl get configmap -n application
kubectl get secret -n application

# 3. Probe endpoints don't exist → update deployment.yaml
```

---

### kubectl connection timeout

**Symptom:** `Unable to connect to the server: dial tcp: i/o timeout`

**Solution:**

```bash
# Check current context
kubectl config current-context

# Update kubeconfig for EKS
aws eks update-kubeconfig --name your-cluster --region us-east-1

# Verify cluster connectivity
kubectl cluster-info

# Check if the API server endpoint is accessible
curl -k https://<api-server-endpoint>/healthz
```

---

## CI/CD

### GitHub Actions workflow fails on Terraform init

**Symptom:** `Error: error configuring Terraform AWS Provider`

**Cause:** Missing AWS credentials in the CI runner.

**Solution:**

Use OIDC or repository secrets:

```yaml
# Option 1: OIDC (recommended)
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::123456789012:role/terraform-ci
    aws-region: us-east-1

# Option 2: Static credentials (less secure)
# Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in repo secrets
```

---

### PR blocked by security scan

**Symptom:** Security check fails with tfsec/Trivy findings.

**Solution:**

```bash
# Run the scanner locally to see exact findings
tfsec terraform/
trivy fs .

# Fix the reported issues:
# - tfsec: Add missing encryption, restrict security groups, etc.
# - Trivy: Update base images, patch vulnerabilities

# Re-run lint locally before pushing
make lint
make security
```

---

## Monitoring

### Prometheus not scraping metrics

**Symptom:** Targets show as DOWN in Prometheus UI.

**Solution:**

```bash
# Check Prometheus config
kubectl exec -n monitoring deploy/prometheus -- cat /etc/prometheus/prometheus.yml

# Verify target endpoints
kubectl get endpoints -n application

# Check Prometheus logs
kubectl logs -n monitoring deploy/prometheus | grep -i error
```

---

### Grafana dashboard is blank

**Symptom:** No data showing in panels.

**Solution:**

1. Verify Prometheus is a configured data source
2. Check the time range selector (top right)
3. Verify metrics are actually being collected:
   ```bash
   kubectl exec -n monitoring deploy/prometheus -- \
     curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[].health'
   ```

---

## General

### "Make: *** No rule to make target"

**Solution:**

```bash
# List all available targets
make help

# Ensure you're in the project root directory
pwd  # Should end with "infrastructure-boilerplate"
```

---

### Pre-commit hook fails

**Solution:**

```bash
# Run against all files manually
pre-commit run --all-files

# Update hook versions
pre-commit autoupdate

# Skip a hook temporarily (not recommended)
SKIP=terraform_tfsec git commit -m "WIP commit"
```

---

### Can't find a file or directory

**Solution:**

```bash
# Check the repository structure
tree -L 2 -I '.terraform|node_modules|.git'

# Or use find
find . -name "*.tf" -maxdepth 4 | head -20
```

---

## Getting Help

If your issue isn't covered here:

1. **Search existing issues:** [GitHub Issues](https://github.com/your-org/infrastructure-boilerplate/issues)
2. **Open a new issue:** Use the bug report template
3. **Team Slack:** `#platform-engineering` channel
4. **Runbooks:** Check `docs/runbooks/` for operational procedures
