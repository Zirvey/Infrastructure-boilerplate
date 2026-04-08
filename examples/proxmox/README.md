# Proxmox Example

This example demonstrates deploying the infrastructure boilerplate to Proxmox VE (on-premises/homelab).

## Prerequisites

- Proxmox VE cluster (>= 7.0)
- Proxmox API credentials
- Terraform >= 1.5.0
- Local network with DHCP or static IP planning

## Why Proxmox?

- **Self-hosted** — full control over hardware and data
- **No vendor lock-in** — open-source hypervisor
- **Cost-effective at scale** — pay for hardware once
- **Good for** — homelabs, on-prem, data sovereignty, edge computing

## Architecture

- Proxmox VMs (Ubuntu Cloud Images)
- Proxmox Cloud-Init for provisioning
- Internal virtual network
- Firewall rules at the hypervisor level
- Optional: Ceph for distributed storage

## Deploy

```bash
# Set Proxmox credentials
export PM_API_URL="https://proxmox.local:8006/api2/json"
export PM_USER="terraform@pve"
export PM_PASSWORD="your-password"
# Or use API token (recommended)
export PM_TOKEN="your-api-token"

# Initialize
terraform init

# Create variables file
cat > variables.tfvars <<EOF
proxmox_host   = "proxmox.local"
environment    = "dev"
project_name   = "my-proxmox-project"
vm_template    = "ubuntu-2204-cloud"
vm_count       = 2
vm_cores       = 2
vm_memory_mb   = 4096
vm_disk_gb     = 50
network_bridge = "vmbr0"
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
    proxmox = {
      source  = "Telmate/proxmox"
      version = "~> 2.9.14"
    }
  }
}

provider "proxmox" {
  pm_api_url = var.pm_api_url
  pm_user    = var.pm_user
  pm_password = var.pm_password
  # Or: pm_api_token_id / pm_api_token_secret
}
```

## Ansible Integration

After VMs are created, use Cloud-Init to set SSH keys:

```ini
# ansible/inventory/hosts.ini
[dev]
proxmox-vm-1 ansible_host=192.168.1.101 ansible_user=ubuntu
proxmox-vm-2 ansible_host=192.168.1.102 ansible_user=ubuntu
```

```bash
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
```

## Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 4 cores | 8+ cores |
| RAM | 16 GB | 32+ GB |
| Storage | 256 GB SSD | 1+ TB NVMe |
| Network | 1 Gbps | 10 Gbps |

## Cost

| Scenario | Cost |
|----------|------|
| Used hardware (eBay) | ~$300-500 |
| New Mini PC (Intel NUC) | ~$600-800 |
| Rack server (Dell R740) | ~$2,000-4,000 |
| Electricity (monthly) | ~$10-30 |

> 💡 Proxmox has zero software cost (open-source). You only pay for hardware and electricity.
