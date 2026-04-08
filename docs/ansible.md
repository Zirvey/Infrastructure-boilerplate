# Ansible Guide

Complete reference for Ansible usage in this project.

---

## Table of Contents

- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [Inventory](#inventory)
- [Roles](#roles)
- [Playbooks](#playbooks)
- [Variables](#variables)
- [Common Operations](#common-operations)
- [Testing](#testing)
- [Best Practices](#best-practices)

---

## Overview

Ansible handles post-provisioning server configuration after Terraform creates the infrastructure. It is agentless, idempotent, and uses SSH for communication.

---

## Directory Structure

```
ansible/
├── ansible.cfg           # Ansible configuration
├── inventory/
│   └── hosts.ini         # Static inventory with host definitions
├── group_vars/           # Variables scoped to host groups
│   ├── all.yml           # Applied to all hosts
│   ├── dev.yml           # Applied to dev group
│   └── prod.yml          # Applied to prod group
├── host_vars/            # Variables for specific hosts
│   └── dev-server-1.yml  # Host-specific overrides
├── roles/
│   ├── common/           # Base server setup (packages, users, SSH)
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   ├── handlers/
│   │   │   └── main.yml
│   │   ├── templates/
│   │   ├── files/
│   │   └── defaults/
│   │       └── main.yml
│   ├── web/              # Web server setup (NGINX, SSL)
│   └── db/               # Database setup (PostgreSQL)
└── playbooks/
    └── site.yml          # Main entry-point playbook
```

---

## Inventory

### Static Inventory (`hosts.ini`)

```ini
[dev]
dev-server-1 ansible_host=10.0.1.10 ansible_user=ubuntu
dev-server-2 ansible_host=10.0.1.11 ansible_user=ubuntu

[staging]
staging-server-1 ansible_host=10.0.2.10 ansible_user=ubuntu
staging-server-2 ansible_host=10.0.2.11 ansible_user=ubuntu

[prod]
prod-server-1 ansible_host=10.0.3.10 ansible_user=ubuntu
prod-server-2 ansible_host=10.0.3.11 ansible_user=ubuntu
prod-server-3 ansible_host=10.0.3.12 ansible_user=ubuntu

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

### Dynamic Inventory

For larger infrastructures, use dynamic inventory:

```bash
# AWS EC2 dynamic inventory
ansible-inventory -i aws_ec2.yml --graph

# Or use terraform output to generate inventory
terraform output -json | python3 scripts/generate_inventory.py > ansible/inventory/hosts.yml
```

---

## Roles

### Role Structure

Each role follows Ansible's standard directory layout:

```
roles/<role_name>/
├── tasks/
│   └── main.yml      # Main task list
├── handlers/
│   └── main.yml      # Event-driven tasks (restart services)
├── templates/        # Jinja2 templates
│   └── nginx.conf.j2
├── files/            # Static files to copy
│   └── ssl-cert.pem
├── defaults/
│   └── main.yml      # Default variable values
├── vars/
│   └── main.yml      # Role-specific variables (high priority)
└── meta/
    └── main.yml      # Role dependencies
```

### Common Role

Base server configuration applied to all hosts:

- System package updates
- Essential packages (curl, wget, vim, htop)
- User management
- SSH hardening
- NTP configuration
- Firewall rules (ufw/iptables)

### Web Role

Web server setup:

- NGINX installation and configuration
- SSL certificate deployment
- Virtual host configuration
- Log rotation

### DB Role

Database server setup:

- PostgreSQL installation
- Database and user creation
- Configuration tuning (shared_buffers, max_connections)
- Backup configuration (pg_dump cron)

---

## Playbooks

### Site Playbook (`playbooks/site.yml`)

The main entry point that orchestrates all roles:

```yaml
---
- name: Configure all servers
  hosts: all
  become: yes
  roles:
    - common

- name: Configure web servers
  hosts: webservers
  become: yes
  roles:
    - web

- name: Configure database servers
  hosts: dbservers
  become: yes
  roles:
    - db
```

### Running Playbooks

```bash
# Run full site configuration
ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# Target specific group
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit dev

# Dry run (check mode)
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check --diff

# Run with specific tags
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --tags "nginx,ssl"

# Run with extra variables
ansible-playbook -i inventory/hosts.ini playbooks/site.yml -e "nginx_port=8080"
```

---

## Variables

### Variable Precedence (lowest to highest)

1. Role defaults (`defaults/main.yml`)
2. Group variables (`group_vars/`)
3. Host variables (`host_vars/`)
4. Inventory variables
5. Play vars
6. Extra vars (`-e`)

### Encrypted Variables (SOPS)

For sensitive values, use SOPS-encrypted files:

```bash
# Encrypt a group_vars file
sops -e group_vars/prod.yml > group_vars/prod.enc.yml

# Ansible can read encrypted values if you configure
# ansible-vault or use a SOPS lookup plugin
```

---

## Common Operations

### Using the Makefile

```bash
make ansible         # Run playbooks
make ansible-check   # Dry run
make ansible-inventory  # Show inventory graph
```

### Manual Commands

```bash
cd ansible/

# Ping all hosts
ansible -i inventory/hosts.ini all -m ping

# Run full site configuration
ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# Check mode
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check

# Verbose output
ansible-playbook -i inventory/hosts.ini playbooks/site.yml -vvv
```

---

## Testing

### Molecule Tests

Each role can be tested with Molecule in isolated Docker containers:

```bash
# Install molecule
pip install molecule molecule-plugins[docker]

# Run tests
cd tests/ansible
molecule test

# Or test a specific role
cd ansible/roles/common
molecule test
```

### Linting

```bash
# Lint playbooks
ansible-lint playbooks/

# Lint roles
ansible-lint roles/

# Syntax check
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --syntax-check
```

---

## Best Practices

1. **Idempotency** — All roles must be safe to run multiple times
2. **Use `become: yes` sparingly** — only when root access is needed
3. **Handlers for service restarts** — don't restart unless config changed
4. **Templates over copy** — use Jinja2 templates for configurable files
5. **Tags for selective execution** — tag tasks for partial runs
6. **No secrets in plain text** — use SOPS, ansible-vault, or external secret stores
7. **Test with Molecule** — before running against real servers
8. **Keep roles focused** — each role manages one logical component
9. **Use `check_mode: yes`** — on tasks that shouldn't run in dry-run
10. **Document role inputs** — maintain a README in each role directory
