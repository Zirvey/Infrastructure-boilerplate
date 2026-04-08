# Hetzner Cloud Example

This example demonstrates deploying the infrastructure boilerplate to Hetzner Cloud.

## Prerequisites

- Hetzner Cloud account
- `HCLOUD_TOKEN` environment variable set
- Terraform >= 1.5.0

## Why Hetzner?

- **Cost-effective** — significantly cheaper than AWS for comparable specs
- **Simple pricing** — no complex pricing tiers
- **EU data centers** — Nuremberg, Falkenstein, Helsinki (GDPR compliant)
- **Good for** — development, staging, cost-sensitive production

## Architecture

- Hetzner Cloud Network (private networking)
- Firewalls for security
- Cloud servers (CX series)
- Load Balancer
- Managed Database (optional, or self-hosted)

## Deploy

```bash
# Set Hetzner token
export HCLOUD_TOKEN="your-hcloud-token"

# Initialize with Hetzner provider
terraform init

# Create variables file
cat > variables.tfvars <<EOF
hcloud_token  = var.hcloud_token
environment   = "dev"
project_name  = "my-hcloud-project"
server_type   = "cx22"  # 1 vCPU, 2GB RAM
server_count  = 2
location      = "fsn1"  # Falkenstein
EOF

# Deploy
terraform plan -var-file=variables.tfvars
terraform apply -var-file=variables.tfvars
```

## Provider Configuration

```hcl
# main.tf
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.44"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}
```

## Cost Estimate

| Resource | Monthly Cost (dev) |
|----------|-------------------|
| 2x CX22 servers | ~$8 |
| 1x Load Balancer | ~$5 |
| Network (private) | Free |
| Firewall | Free |
| **Total** | **~$13/mo** |

> 💡 Hetzner is ~10x cheaper than AWS for comparable workloads.
