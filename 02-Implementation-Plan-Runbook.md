# Implementation Plan & Runbook
## Automated Configuration Management Architecture

**Version:** 1.0  
**Date:** October 17, 2025  
**Status:** Draft  
**Author:** Adrian Johnson  
**Email:** adrian207@gmail.com

---

## 1. Document Purpose

This Implementation Plan provides a comprehensive, step-by-step guide for deploying the Automated Configuration Management Architecture. It includes detailed procedures, verification steps, estimated timelines, and troubleshooting guidance for each deployment phase.

**Target Audience:** Implementation team, DevOps engineers, system administrators

---

## 2. Implementation Overview

### 2.1 Implementation Strategy

**Phased Approach:**
1. Development Environment (Week 1-2)
2. Test Environment (Week 3-4)
3. Production Environment (Week 5-7)
4. Production Pilot (Week 8)
5. Full Production Rollout (Week 9-10)

### 2.2 Team Roles and Responsibilities

| Role | Responsibilities | Team Member |
|------|-----------------|-------------|
| **Implementation Lead** | Overall coordination, decision-making | Adrian Johnson |
| **Infrastructure Engineer** | Server provisioning, network configuration | TBD |
| **Automation Engineer** | Ansible/DSC configuration, scripts | TBD |
| **Database Administrator** | SQL Server setup and configuration | TBD |
| **Security Engineer** | Vault setup, certificates, RBAC | TBD |
| **Network Engineer** | Firewall rules, DNS, load balancer | TBD |
| **QA Engineer** | Testing and validation | TBD |

### 2.3 Prerequisites

**Before Starting Implementation:**
- [ ] All team members identified and available
- [ ] Hardware/cloud resources allocated
- [ ] Network subnets allocated and documented
- [ ] Active Directory service accounts created
- [ ] Change request approved (for production)
- [ ] Maintenance window scheduled (for production)
- [ ] All required software licenses obtained
- [ ] Backup/rollback plan documented

---

## 3. Phase 1: Development Environment Setup

**Timeline:** Week 1-2 (10 business days)  
**Architecture:** Ansible-Native Push Model (Small Tier)

### 3.1 Infrastructure Provisioning (Day 1-2)

#### Step 1.1: Initialize Terraform Workspace

**Duration:** 30 minutes

```bash
# Clone repository (or initialize new)
git clone https://github.com/your-org/config-mgmt-architecture.git
cd config-mgmt-architecture

# Navigate to Terraform directory
cd terraform/environments/development

# Initialize Terraform
terraform init
```

**Verification:**
```bash
# Should see: "Terraform has been successfully initialized!"
terraform version
```

**Expected Output:** Terraform v1.6.x or higher

---

#### Step 1.2: Configure Terraform Variables

**Duration:** 45 minutes

Create `terraform.tfvars`:

```hcl
# terraform/environments/development/terraform.tfvars

environment = "development"
location    = "East US"  # or your preferred region

# Network Configuration
vnet_address_space = "10.20.0.0/16"
subnet_management  = "10.20.10.0/24"
subnet_monitoring  = "10.20.20.0/24"
subnet_data        = "10.20.30.0/24"
subnet_nodes       = "10.20.100.0/24"

# VM Specifications
awx_vm_size = "Standard_D4s_v3"  # 4 vCPU, 16 GB RAM
vault_vm_size = "Standard_D2s_v3"  # 2 vCPU, 8 GB RAM
pgsql_vm_size = "Standard_D2s_v3"

# Tags
tags = {
  environment = "development"
  project     = "config-management"
  owner       = "adrian.johnson@contoso.com"
  cost_center = "IT-Operations"
}
```

**Verification:** Review with team, validate subnet allocations don't conflict

---

#### Step 1.3: Deploy Infrastructure

**Duration:** 30-45 minutes

```bash
# Plan deployment
terraform plan -out=tfplan

# Review output - verify resources to be created
# Expected: ~15-20 resources (VMs, networks, NSGs, disks)

# Apply deployment
terraform apply tfplan
```

**Expected Resources Created:**
- 1 Virtual Network with 4 subnets
- 4 Network Security Groups
- 3 Virtual Machines (AWX, Vault, PostgreSQL)
- 3 Network Interfaces
- 3 Managed Disks
- Public IP addresses (if required)
- DNS records (if managed by Terraform)

**Verification:**
```bash
# List all created resources
terraform state list

# Get output values
terraform output
```

**Expected Output:**
```
awx_private_ip = "10.20.10.10"
vault_private_ip = "10.20.10.20"
pgsql_private_ip = "10.20.30.10"
```

**Troubleshooting:**
- **Issue:** Quota exceeded
  - **Solution:** Request quota increase or use smaller VM sizes
- **Issue:** Subnet conflict
  - **Solution:** Adjust address spaces in terraform.tfvars
- **Issue:** Authentication failure
  - **Solution:** Run `az login` or configure service principal

---

### 3.2 Base System Configuration (Day 2-3)

#### Step 2.1: Configure SSH Access

**Duration:** 30 minutes

```bash
# Test SSH connectivity
ssh ubuntu@10.20.10.10  # AWX server
ssh ubuntu@10.20.10.20  # Vault server
ssh ubuntu@10.20.30.10  # PostgreSQL server

# Copy SSH keys to all servers (if not done via Terraform)
ssh-copy-id ubuntu@10.20.10.10
ssh-copy-id ubuntu@10.20.10.20
ssh-copy-id ubuntu@10.20.30.10
```

**Verification:** Passwordless SSH login works to all servers

---

#### Step 2.2: Apply Base Configuration with Ansible

**Duration:** 45 minutes

```bash
cd ansible/

# Update inventory
cat > inventory/dev/hosts <<EOF
[awx_servers]
awx-dev ansible_host=10.20.10.10

[vault_servers]
vault-dev ansible_host=10.20.10.20

[database_servers]
pgsql-dev ansible_host=10.20.30.10

[all:vars]
ansible_user=ubuntu
ansible_become=yes
ansible_python_interpreter=/usr/bin/python3
EOF

# Run base configuration playbook
ansible-playbook -i inventory/dev/hosts playbooks/base-config.yml
```

**Base configuration includes:**
- System updates and patches
- NTP configuration
- Firewall configuration (ufw/firewalld)
- Monitoring agent installation (node_exporter)
- Log rotation configuration
- Security hardening (CIS benchmarks)

**Verification:**
```bash
# Verify all hosts reachable
ansible all -i inventory/dev/hosts -m ping

# Verify system updates applied
ansible all -i inventory/dev/hosts -m shell -a "uptime"

# Verify node_exporter running
ansible all -i inventory/dev/hosts -m shell -a "systemctl status node_exporter"
```

**Expected Output:** All services active and running

---

### 3.3 HashiCorp Vault Installation (Day 3)

#### Step 3.1: Install Vault

**Duration:** 1 hour

```bash
# Run Vault installation playbook
ansible-playbook -i inventory/dev/hosts playbooks/install-vault.yml
```

**Playbook performs:**
- Download Vault binary
- Create vault user and group
- Configure systemd service
- Generate TLS certificates (self-signed for dev)
- Configure vault.hcl
- Start vault service

**Verification:**
```bash
# SSH to Vault server
ssh ubuntu@10.20.10.20

# Check Vault status
export VAULT_ADDR='https://127.0.0.1:8200'
vault status
```

**Expected Output:**
```
Key                Value
---                -----
Seal Type          shamir
Initialized        false
Sealed             true
```

---

#### Step 3.2: Initialize Vault

**Duration:** 30 minutes

```bash
# Initialize Vault (generates unseal keys and root token)
vault operator init -key-shares=5 -key-threshold=3

# CRITICAL: Save the output securely!
# Example output:
# Unseal Key 1: xxx
# Unseal Key 2: xxx
# Unseal Key 3: xxx
# Unseal Key 4: xxx
# Unseal Key 5: xxx
# Initial Root Token: xxx
```

**⚠️ SECURITY WARNING:**
- Save unseal keys in multiple secure locations (password manager, encrypted file, physical safe)
- Never commit unseal keys or root token to Git
- In production, consider using auto-unseal with cloud KMS

---

#### Step 3.3: Unseal Vault

**Duration:** 15 minutes

```bash
# Unseal Vault (requires 3 of 5 keys)
vault operator unseal <unseal-key-1>
vault operator unseal <unseal-key-2>
vault operator unseal <unseal-key-3>

# Verify unsealed
vault status
```

**Expected Output:**
```
Initialized        true
Sealed             false
```

---

#### Step 3.4: Configure Vault

**Duration:** 45 minutes

```bash
# Login with root token
vault login <root-token>

# Enable secrets engine
vault secrets enable -path=secret kv-v2

# Create initial secrets structure
vault kv put secret/development/awx/admin password="ChangeMe123!"
vault kv put secret/development/dsc/registration key="dev-registration-key-12345"

# Enable AppRole auth method
vault auth enable approle

# Create policy for Ansible
vault policy write ansible-policy - <<EOF
path "secret/data/development/*" {
  capabilities = ["read", "list"]
}
EOF

# Create AppRole for Ansible
vault write auth/approle/role/ansible-role \
    secret_id_ttl=24h \
    token_num_uses=0 \
    token_ttl=8h \
    token_max_ttl=24h \
    policies="ansible-policy"

# Get role-id (save this for AWX configuration)
vault read auth/approle/role/ansible-role/role-id

# Generate secret-id (save this for AWX configuration)
vault write -f auth/approle/role/ansible-role/secret-id
```

**Verification:**
```bash
# Test reading a secret
vault kv get secret/development/awx/admin

# Should see the password value
```

---

### 3.4 PostgreSQL Database Setup (Day 4)

#### Step 4.1: Install PostgreSQL

**Duration:** 45 minutes

```bash
# Run PostgreSQL installation playbook
ansible-playbook -i inventory/dev/hosts playbooks/install-postgresql.yml \
  -e "postgres_version=13" \
  -e "postgres_password=SecurePassword123!"
```

**Verification:**
```bash
ssh ubuntu@10.20.30.10

# Check PostgreSQL status
sudo systemctl status postgresql

# Test connection
sudo -u postgres psql -c "SELECT version();"
```

---

#### Step 4.2: Create AWX Database

**Duration:** 30 minutes

```bash
# Connect to PostgreSQL
ssh ubuntu@10.20.30.10
sudo -u postgres psql

-- Create database and user for AWX
CREATE DATABASE awx;
CREATE USER awx WITH PASSWORD 'SecureAWXPassword123!';
GRANT ALL PRIVILEGES ON DATABASE awx TO awx;

-- Configure for remote connections
\q

# Edit PostgreSQL configuration
sudo nano /etc/postgresql/13/main/postgresql.conf
# Change: listen_addresses = '*'

sudo nano /etc/postgresql/13/main/pg_hba.conf
# Add: host    awx    awx    10.20.10.0/24    md5

# Restart PostgreSQL
sudo systemctl restart postgresql
```

**Verification:**
```bash
# Test remote connection from AWX server
psql -h 10.20.30.10 -U awx -d awx -W
# Enter password when prompted
# Should connect successfully
```

---

### 3.5 Ansible AWX Installation (Day 4-5)

#### Step 5.1: Install AWX Prerequisites

**Duration:** 1 hour

```bash
# SSH to AWX server
ssh ubuntu@10.20.10.10

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Git and other dependencies
sudo apt update
sudo apt install -y git make nodejs npm

# Log out and back in for group changes to take effect
exit
ssh ubuntu@10.20.10.10
```

**Verification:**
```bash
docker --version
docker-compose --version
```

---

#### Step 5.2: Deploy AWX

**Duration:** 1-2 hours

```bash
# Clone AWX repository
git clone https://github.com/ansible/awx.git
cd awx
git checkout 23.3.0  # Use stable version

# Generate secret key
openssl rand -base64 30

# Create inventory file for AWX installation
cd installer
cp inventory inventory.bak

# Edit inventory
nano inventory
```

**Configure inventory:**
```ini
localhost ansible_connection=local ansible_python_interpreter="/usr/bin/env python3"

[all:vars]
awx_task_hostname=awx-dev
awx_web_hostname=awx-dev

postgres_data_dir="/var/lib/pgdocker"

# External PostgreSQL
pg_hostname=10.20.30.10
pg_username=awx
pg_password=SecureAWXPassword123!
pg_database=awx
pg_port=5432

admin_user=admin
admin_password=AdminPassword123!

secret_key=<generated-secret-key>

awx_official=true
project_data_dir=/var/lib/awx/projects
```

**Install AWX:**
```bash
# Run installation playbook
ansible-playbook -i inventory install.yml

# This will take 15-30 minutes
# AWX will download containers and start services
```

**Verification:**
```bash
# Check Docker containers
docker ps

# Should see 4 containers running:
# - awx_web
# - awx_task  
# - redis
# - awx_receptor

# Check AWX is responding
curl http://localhost:80

# Should see redirect to /api/login/
```

---

#### Step 5.3: Initial AWX Configuration

**Duration:** 1 hour

**Access AWX Web UI:**
1. Open browser: `http://10.20.10.10` (or via port forward if needed)
2. Login: admin / AdminPassword123!

**Configure via UI or CLI:**

```bash
# Install AWX CLI
pip3 install awxkit

# Configure AWX CLI
awx --conf.host http://10.20.10.10 \
    --conf.username admin \
    --conf.password AdminPassword123! \
    --conf.insecure login

# Create organization
awx organizations create --name "IT Operations"

# Create credentials (Vault AppRole)
awx credentials create \
  --name "HashiCorp Vault" \
  --credential_type "HashiCorp Vault Secret Lookup" \
  --organization "IT Operations" \
  --inputs '{
    "url": "https://10.20.10.20:8200",
    "role_id": "<vault-role-id>",
    "secret_id": "<vault-secret-id>"
  }'

# Create project (Git repository)
awx projects create \
  --name "Configuration Management" \
  --organization "IT Operations" \
  --scm_type git \
  --scm_url "https://github.com/your-org/config-mgmt-architecture.git" \
  --scm_branch "develop"

# Wait for project sync
awx projects list
```

**Verification:** Check that project sync completed successfully

---

### 3.6 Monitoring Stack Installation (Day 5-6)

#### Step 6.1: Install Prometheus and Grafana

**Duration:** 2 hours

```bash
# Run monitoring stack playbook
ansible-playbook -i inventory/dev/hosts playbooks/install-monitoring.yml
```

**Playbook installs:**
- Prometheus server
- Grafana
- Alertmanager
- Node exporters on all servers

**Verification:**
```bash
# Check Prometheus
curl http://10.20.20.10:9090/-/healthy

# Check Grafana
curl http://10.20.20.10:3000/api/health

# Both should return "OK" or success message
```

---

#### Step 6.2: Configure Grafana

**Duration:** 1 hour

**Access Grafana UI:**
1. Open browser: `http://10.20.20.10:3000`
2. Login: admin / admin (change password on first login)

**Add Prometheus Data Source:**
```bash
# Via Grafana API
curl -X POST http://admin:newpassword@10.20.20.10:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://localhost:9090",
    "access": "proxy",
    "isDefault": true
  }'
```

**Import Dashboards:**
- Node Exporter Full (Dashboard ID: 1860)
- Vault Metrics (Dashboard ID: 12904)
- PostgreSQL (Dashboard ID: 9628)

**Verification:** View dashboards and confirm metrics are displayed

---

### 3.7 Development Environment Testing (Day 7-8)

#### Step 7.1: Deploy Test Managed Nodes

**Duration:** 1 hour

```bash
# Provision 2 test VMs (1 Linux, 1 Windows)
cd terraform/test-nodes/development
terraform init
terraform apply
```

---

#### Step 7.2: Create Test Inventory in AWX

**Duration:** 30 minutes

```bash
# Create inventory
awx inventory create \
  --name "Development Test Nodes" \
  --organization "IT Operations"

# Add hosts manually or via dynamic inventory
awx hosts create \
  --name "linux-test-01" \
  --inventory "Development Test Nodes" \
  --variables '{"ansible_host": "10.20.100.10"}'
```

---

#### Step 7.3: Create and Execute Test Job Template

**Duration:** 1 hour

```bash
# Create credentials for managed nodes
awx credentials create \
  --name "SSH Key - Dev Nodes" \
  --credential_type "Machine" \
  --organization "IT Operations" \
  --inputs '{"username": "ubuntu", "ssh_key_data": "'"$(cat ~/.ssh/id_rsa)"'"}'

# Create job template
awx job_templates create \
  --name "Test - Ping All Nodes" \
  --job_type run \
  --inventory "Development Test Nodes" \
  --project "Configuration Management" \
  --playbook "playbooks/test-connectivity.yml" \
  --credentials "SSH Key - Dev Nodes"

# Launch job
awx job_templates launch "Test - Ping All Nodes"

# Watch job status
awx jobs list --status running -f human
```

**Expected Result:** Job completes successfully, all hosts respond to ping

---

### 3.8 Development Environment Sign-Off (Day 10)

**Checklist:**
- [ ] All infrastructure components deployed and running
- [ ] Vault unsealed and accessible
- [ ] AWX accessible via web UI
- [ ] Test playbook executed successfully against test nodes
- [ ] Monitoring dashboards showing metrics
- [ ] Test alert triggered and received
- [ ] Documentation updated with as-built information
- [ ] Known issues documented

**Sign-off:** Implementation Lead + Team

---

## 4. Phase 2: Test/Staging Environment Setup

**Timeline:** Week 3-4 (10 business days)  
**Architecture:** Ansible-Native Push Model (Small Tier)

### 4.1 Replicate Development Deployment

**Process:** Follow steps from Phase 1 with test environment variables

**Key Differences:**
- Use test subnet ranges (10.30.0.0/16)
- Separate Vault instance with separate secrets
- Test environment DNS names
- Same architecture as dev for consistency

**Duration:** 5-6 days (faster due to lessons learned)

---

### 4.2 Integration Testing

**Duration:** 3-4 days

**Test Scenarios:**
1. Full configuration deployment lifecycle
2. Drift detection and remediation
3. Secret rotation procedures
4. Backup and restore procedures
5. Failover testing (if HA components)
6. Performance/load testing
7. Security scanning

**Acceptance Criteria:** All test scenarios pass with <5% failure rate

---

## 5. Phase 3: Production Environment Setup

**Timeline:** Week 5-7 (15 business days)  
**Architecture:** Hybrid Pull Model (Medium Tier)

### 5.1 Production Infrastructure Provisioning (Day 1-3)

**Change Control:** Submit and obtain approval for change request

**Components to Deploy:**
- 2x DSC Pull Servers
- 1x SQL Server (with warm standby for Medium tier)
- 3x HashiCorp Vault cluster nodes
- 3x Prometheus servers
- 1x Grafana server
- 2x Alertmanager servers
- 2x DFS-R file servers

**Process:** Execute Terraform with production variables

**Duration:** 2-3 days (includes approval waiting time)

---

### 5.2 Production DSC Pull Server Configuration (Day 4-6)

**Duration:** 3 days

**Follow Microsoft documentation for DSC Pull Server setup:**

1. Install IIS and required features
2. Install DSC Service Windows feature
3. Configure SQL Server database connection
4. Generate registration keys
5. Configure DFS-R for module/config replication
6. Install SSL certificates
7. Configure load balancer health checks
8. Test node registration

**Detailed steps in separate DSC Pull Server runbook**

---

### 5.3 Production Vault Cluster (Day 7-9)

**Duration:** 3 days

**Raft Cluster Setup:**

1. Install Vault on all 3 nodes
2. Initialize first node as cluster leader
3. Join additional nodes to cluster
4. Configure auto-unseal (Azure Key Vault or AWS KMS)
5. Enable audit logging
6. Configure replication (if Enterprise)
7. Create production policies and roles
8. Load production secrets (via secure process)

---

### 5.4 Production Testing and Validation (Day 10-13)

**Duration:** 4 days

**Validation Steps:**
1. Infrastructure validation (all services running)
2. Security validation (RBAC, firewall rules, certificates)
3. Integration validation (vault → pull server → nodes)
4. Performance validation (load testing)
5. DR validation (backup restore test)
6. Monitoring validation (dashboards, alerts)

---

### 5.5 Production Go-Live Preparation (Day 14-15)

**Duration:** 2 days

- [ ] Operations team training completed
- [ ] Runbooks finalized and reviewed
- [ ] On-call schedule established
- [ ] Rollback plan tested
- [ ] Communication plan executed
- [ ] Go/No-Go meeting conducted

---

## 6. Phase 4: Production Pilot (Week 8)

### 6.1 Pilot Node Selection

**Criteria:**
- Non-critical workloads
- 10-20 nodes from different roles
- Good monitoring/logging
- Easy rollback if issues

### 6.2 Pilot Onboarding

**Process:**
1. Onboard pilot nodes using automated scripts
2. Apply baseline configurations
3. Monitor for 48 hours
4. Collect feedback from application owners
5. Make adjustments as needed

### 6.3 Pilot Evaluation

**Success Criteria:**
- All pilot nodes successfully onboarded
- Configurations applied without errors
- No service disruptions
- Drift detection working
- Operations team comfortable with tools

---

## 7. Phase 5: Full Production Rollout (Week 9-10)

### 7.1 Rollout Strategy

**Phased Approach:**
- Week 9: Roll out to 25% of production nodes
- Week 10: Roll out to remaining 75% of nodes

**By Application Tier:**
1. Non-production-facing infrastructure first
2. Internal tools and services
3. Customer-facing services (during maintenance window)

### 7.2 Rollout Execution

**Per-Wave Process:**
1. Identify nodes for this wave
2. Submit change request
3. Execute onboarding during maintenance window
4. Monitor for 24-48 hours
5. Validate configurations applied
6. Address any issues before next wave

---

## 8. Post-Implementation Tasks

### 8.1 Documentation Finalization

- [ ] Update all documentation with as-built information
- [ ] Create knowledge base articles
- [ ] Record video walkthroughs for common tasks
- [ ] Update network diagrams with actual IPs

### 8.2 Training

- [ ] Conduct operations team training sessions
- [ ] Conduct developer training (configuration authoring)
- [ ] Create training materials and labs
- [ ] Schedule quarterly refresher training

### 8.3 Continuous Improvement

- [ ] Establish regular review meetings
- [ ] Track metrics and KPIs
- [ ] Solicit feedback from users
- [ ] Plan for future enhancements

---

## 9. Rollback Procedures

### 9.1 Development/Test Environment Rollback

**If issues encountered:**
```bash
# Destroy infrastructure
cd terraform/environments/development
terraform destroy -auto-approve

# Clean up any orphaned resources
# Re-deploy from scratch if needed
```

### 9.2 Production Environment Rollback

**Partial Rollback (specific nodes):**
1. Remove nodes from DSC pull server
2. Stop DSC LCM: `Set-DscLocalConfigurationManager -Mode Disable`
3. Revert to previous configuration management method

**Full Rollback (entire system):**
1. Stop onboarding new nodes
2. Disable DSC enforcement on all nodes
3. Keep infrastructure running for forensics
4. Convene post-mortem meeting
5. Make decision on path forward

---

## 10. Troubleshooting Guide

### 10.1 Common Issues and Solutions

#### Issue: Terraform Apply Fails with Authentication Error

**Symptoms:** `Error: authentication failed`

**Solution:**
```bash
# For Azure
az login
az account set --subscription "<subscription-id>"

# For AWS
aws configure
```

---

#### Issue: Ansible Playbook Fails with SSH Connection Refused

**Symptoms:** `fatal: [host]: UNREACHABLE! => {"msg": "Failed to connect"}`

**Solution:**
1. Verify firewall allows SSH (port 22)
2. Verify SSH service running on target
3. Verify correct SSH key configured
4. Test manual SSH: `ssh user@host`

---

#### Issue: Vault Cannot Unseal

**Symptoms:** `vault status` shows "Sealed: true" after unseal attempts

**Solution:**
- Verify you're using correct unseal keys
- Ensure you've provided threshold number of keys (usually 3 of 5)
- Check Vault logs: `journalctl -u vault -f`
- Verify network connectivity to Vault API

---

#### Issue: AWX Installation Fails

**Symptoms:** Docker containers not starting or failing health checks

**Solution:**
1. Check Docker logs: `docker logs awx_web`
2. Verify PostgreSQL connectivity from AWX server
3. Verify sufficient disk space: `df -h`
4. Check memory: `free -h`
5. Review installation inventory for typos

---

#### Issue: Monitoring Not Showing Data

**Symptoms:** Grafana dashboards empty

**Solution:**
1. Verify Prometheus targets are UP: `http://<prometheus>:9090/targets`
2. Check node_exporter running on targets: `systemctl status node_exporter`
3. Verify firewall allows metrics ports (9100, 9182)
4. Check Prometheus logs: `journalctl -u prometheus -f`

---

## 11. Contacts and Escalation

| Issue Type | Contact | Response Time |
|------------|---------|---------------|
| Infrastructure/Network | Infrastructure Team | 2 hours |
| Application/AWX | DevOps Team | 4 hours |
| Security/Vault | Security Team | 1 hour |
| Database | DBA Team | 2 hours |
| Emergency | On-Call Engineer | 15 minutes |

**Escalation Path:**
1. Implementation Team Member
2. Implementation Lead (Adrian Johnson)
3. Infrastructure Manager
4. CTO

---

## 12. Appendix: Command Reference

### Terraform Commands

```bash
# Initialize
terraform init

# Plan
terraform plan -out=tfplan

# Apply
terraform apply tfplan

# Destroy
terraform destroy

# Show state
terraform state list
terraform state show <resource>

# Import existing resource
terraform import <resource_type>.<name> <resource_id>
```

### Ansible Commands

```bash
# Test connectivity
ansible all -i inventory -m ping

# Run playbook
ansible-playbook -i inventory playbook.yml

# Check mode (dry run)
ansible-playbook -i inventory playbook.yml --check

# Verbose output
ansible-playbook -i inventory playbook.yml -vvv

# Limit to specific hosts
ansible-playbook -i inventory playbook.yml --limit "webservers"

# List tasks
ansible-playbook playbook.yml --list-tasks

# Syntax check
ansible-playbook playbook.yml --syntax-check
```

### Vault Commands

```bash
# Status
vault status

# Unseal
vault operator unseal <key>

# Login
vault login <token>

# Read secret
vault kv get secret/path/to/secret

# Write secret
vault kv put secret/path/to/secret key=value

# List secrets
vault kv list secret/path

# Enable auth method
vault auth enable <method>

# Create policy
vault policy write <name> <file>
```

### AWX CLI Commands

```bash
# Login
awx login -f human

# List resources
awx organizations list
awx projects list
awx inventories list
awx job_templates list

# Launch job
awx job_templates launch <id>

# Monitor job
awx jobs get <job_id> -f human

# Export/backup configuration
awx export --all > awx-backup.json
```

---

## Document Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-17 | Adrian Johnson | Initial release |

---

**Document End**

