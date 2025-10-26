<div align="center">

# 💾 Disaster Recovery Plan
## Automated Configuration Management Architecture

![Version](https://img.shields.io/badge/version-2.0-blue.svg)
![Classification](https://img.shields.io/badge/classification-confidential-red.svg)
![RTO](https://img.shields.io/badge/RTO-1--4%20hours-green.svg)
![RPO](https://img.shields.io/badge/RPO-1--6%20hours-green.svg)

**Document Classification:** Confidential - Business Continuity  
**Author:** Adrian Johnson | **Email:** [adrian207@gmail.com](mailto:adrian207@gmail.com)

</div>

---

## 📊 Executive Summary

> **This Disaster Recovery Plan ensures business continuity of configuration management capabilities with recovery time objectives (RTO) of 1-4 hours and recovery point objectives (RPO) of 1-6 hours across all disaster scenarios.**

The plan provides comprehensive recovery procedures for all failure modes—from single component failures to complete regional disasters—with clear responsibilities, detailed procedures, and validated recovery capabilities through quarterly testing.

### ⏱️ Recovery Objectives Summary

**🎯 Critical Components** (RTO: 1-2 hours, RPO: 1-2 hours):

<table>
<tr>
<td width="33%">

**🏰 HashiCorp Vault**
- ⏱️ RTO: **1 hour**
- 📊 RPO: **1 hour**
- 🚨 Priority: **Critical**
- 💥 Impact: Cannot decrypt secrets

</td>
<td width="33%">

**📝 Git Repository**
- ⏱️ RTO: **2 hours**
- 📊 RPO: **1 hour**
- 🚨 Priority: **High**
- 💥 Impact: Cannot deploy changes

</td>
<td width="33%">

**🎛️ Control Plane**
- ⏱️ RTO: **4 hours**
- 📊 RPO: **4-6 hours**
- 🚨 Priority: **High**
- 💥 Impact: No config management

</td>
</tr>
</table>

**🔄 Recovery Capabilities**:

```
┌─────────────────────────────────────────────────────────┐
│  Component-Level       │  < 5 minutes   │  Automated    │
│  (Failover)            │                │  failover     │
├─────────────────────────────────────────────────────────┤
│  Facility-Level        │  4-8 hours     │  Secondary    │
│  (Datacenter Failure)  │                │  site restore │
├─────────────────────────────────────────────────────────┤
│  Regional-Level        │  8-24 hours    │  Geographic   │
│  (Natural Disaster)    │                │  DR site      │
└─────────────────────────────────────────────────────────┘
```

**💼 Business Impact of Disasters**:
- ❌ **Without DR**: Inability to enforce configuration compliance, deploy changes, or onboard new nodes
- ✅ **With DR**: Minimal interruption, automated failover for most scenarios, documented procedures for major events

### 🧪 Testing & Validation

**📅 Quarterly DR Tests**: Full recovery drills validate:
- ✅ Backup integrity and restore procedures
- ✅ Team readiness and communication protocols
- ✅ Recovery time objective achievement
- ✅ Documentation accuracy and completeness

**📊 Test Schedule**:
- 🗓️ **Last Test Date**: TBD (schedule quarterly after production deployment)  
- 🗓️ **Next Test Date**: TBD + 90 days

### 👥 Intended Audience

| Role | Primary Use |
|------|-------------|
| 🚨 **DR Team** | Primary responsibility for disaster recovery execution |
| 🏗️ **Infrastructure Engineers** | Component-specific recovery procedures |
| 👨‍💼 **Operations Management** | Decision authority for DR activation |
| 📊 **Business Stakeholders** | Understanding of recovery capabilities and timelines |

---

## 1. Document Purpose and Scope

This Disaster Recovery Plan provides comprehensive procedures for recovering the Configuration Management infrastructure from any failure scenario—from simple component failures to catastrophic regional disasters.

**What This Plan Covers**:
1. **Recovery Objectives**: RTO and RPO for every component
2. **Disaster Scenarios**: Classification and response procedures for all failure modes
3. **Recovery Procedures**: Step-by-step technical procedures with verification steps
4. **Team Organization**: Roles, responsibilities, and communication protocols
5. **Testing Requirements**: DR drill procedures and success criteria

**Business Continuity Context**:
- Configuration Management is a **Tier 1 Critical Service** (must recover within 4 hours)
- Supports 100% of production infrastructure (1,000+ managed nodes)
- Required for: Security compliance, change deployment, incident response, new node provisioning

### Scope Definition

**In Scope** (Covered by this DR plan):
- All control plane infrastructure (DSC Pull Servers, Ansible Tower/AWX, HashiCorp Vault)
- Supporting infrastructure (monitoring, databases, secrets management)
- Configuration data, Git repositories, and documentation
- Operational procedures and runbooks

**Out of Scope** (Covered by separate DR plans):
- Managed nodes (recovered by application teams using this infrastructure after restoration)
- End-user workstations
- General corporate infrastructure (network, Active Directory, etc.)
- Application-specific data on managed nodes

---

## 2. Recovery Objectives

### 2.1 Component-Level Recovery Objectives

The table below defines Recovery Time Objective (RTO) and Recovery Point Objective (RPO) for each infrastructure component. These objectives drive backup frequency, redundancy requirements, and recovery procedures.

| Component | RTO | RPO | Priority | Impact of Loss | Recovery Method |
|-----------|-----|-----|----------|----------------|-----------------|
| **HashiCorp Vault** | 1 hour | 1 hour | Critical | Cannot decrypt secrets; managed nodes cannot authenticate | Automated HA failover (primary); restore from snapshot (secondary) |
| **DSC Pull Server** | 4 hours | 4 hours | High | Windows nodes cannot pull configurations; drift detection stops | Restore from VM backup; re-register nodes |
| **Ansible Tower/AWX** | 4 hours | 6 hours | High | Cannot orchestrate changes; automation workflows stopped | Restore from database backup; redeploy containers |
| **SQL Server (DSC)** | 4 hours | 4 hours | High | DSC Pull Server inoperable; no node status data | Restore from database backup with log shipping |
| **PostgreSQL (AWX)** | 4 hours | 6 hours | High | Ansible Tower inoperable; job history lost | Restore from database backup |
| **Prometheus/Grafana** | 8 hours | 24 hours | Medium | No metrics or dashboards; alerting stopped | Restore from VM backup; reconfigure data sources |
| **Git Repository** | 2 hours | 1 hour | High | Cannot deploy configuration changes; no version control | Restore from git mirror or cloud backup |
| **Monitoring (Prometheus)** | 8 hours | 24 hours | Medium | Visibility loss; no metrics or alerting | Redeploy from IaC; historic data loss acceptable |

**RTO Definitions**:
- **RTO (Recovery Time Objective)**: Maximum acceptable downtime from disaster declaration to service restoration
- **RPO (Recovery Point Objective)**: Maximum acceptable data loss measured in time (e.g., 4-hour RPO = can lose up to 4 hours of data)

**Priority Classifications**:
- **Critical**: Must recover within 1-2 hours (immediate business impact)
- **High**: Must recover within 4 hours (significant operational impact)
- **Medium**: Must recover within 8 hours (degraded operations acceptable temporarily)

### 2.2 Service-Level Recovery Objectives

**End-to-End Service Restoration Timeline**:

| Recovery Milestone | Target Time | Description |
|-------------------|-------------|-------------|
| **Disaster Declaration** | T+0 | Incident confirmed as disaster; DR plan activated |
| **Team Assembly** | T+15 min | DR team assembled; roles assigned; initial assessment |
| **Vault Restoration** | T+1 hour | Vault operational; secrets accessible |
| **Git Repository** | T+2 hours | Configuration code accessible for deployment |
| **Control Plane (DSC/Ansible)** | T+4 hours | Configuration management operational; can deploy changes |
| **Database Services** | T+4 hours | SQL Server / PostgreSQL operational; data restored |
| **Monitoring Restoration** | T+8 hours | Prometheus, Grafana operational; alerting functional |
| **Full Service Validation** | T+8-12 hours | All components tested; managed nodes reconnected |

---

## 3. Disaster Scenarios & Classification

### 3.1 Disaster Classification Matrix

Disasters are classified into three levels based on scope and impact. Classification determines response procedures and escalation requirements.

**Level 1: Component Failure** (Localized)
- **Scope**: Single server, service, or infrastructure component fails
- **Examples**: 
  - DSC Pull Server VM crashes
  - Database instance failure (with HA standby available)
  - Network switch failure
  - Single disk failure
- **Recovery Approach**: Failover to redundant component OR restore from backup
- **Typical RTO**: 15 minutes (automated failover) to 4 hours (restore from backup)
- **Authority**: Operations team handles recovery; notify management

**Level 2: Facility Failure** (Datacenter/Regional)
- **Scope**: Entire datacenter or availability zone unavailable
- **Examples**:
  - Data center power outage (>4 hours)
  - Data center fire, flood, or physical damage
  - Complete loss of datacenter connectivity
  - Cloud provider availability zone failure
- **Recovery Approach**: Failover to secondary site OR rebuild in alternate location
- **Typical RTO**: 4-8 hours (secondary site available) to 24 hours (rebuild required)
- **Authority**: Requires management approval; follow business continuity plan

**Level 3: Regional Failure** (Geographic)
- **Scope**: Entire geographic region affected (natural disaster, major cloud outage)
- **Examples**:
  - Hurricane, earthquake, or major natural disaster
  - Extended cloud provider regional outage
  - Widespread infrastructure failure affecting multiple datacenters
- **Recovery Approach**: Geographic failover to distant DR site
- **Typical RTO**: 8-24 hours (DR site pre-provisioned) to 72 hours (rebuild from scratch)
- **Authority**: Executive leadership approval required; invoke business continuity plan

### 3.2 Disaster Declaration Criteria

**When to Declare a Disaster** (activate this DR plan):

1. **Critical component unavailable** for >30 minutes with no immediate fix
2. **Multiple components failed** simultaneously indicating systemic issue
3. **Data loss detected** that cannot be recovered from recent backups
4. **Facility inaccessible** (physical access denied or unsafe)
5. **Recovery time will exceed 4 hours** using standard troubleshooting

**Authority to Declare Disaster**:
- **Business Hours**: Operations Manager or Infrastructure Director
- **After Hours**: On-call Incident Commander or backup contact

**Declaration Process**:
1. On-call engineer assesses situation and recommends disaster declaration
2. Operations Manager (or backup) confirms and officially declares disaster
3. DR team paged via mass notification (PagerDuty, phone tree)
4. Incident bridge opened for coordination
5. Status page updated (internal stakeholders notified)

---

**Level 4 - Cyber Attack**
- Ransomware, data breach, coordinated attack
- Recovery: Clean restore from offline backups, forensic investigation
- Example: Ransomware encrypts all systems

### 3.2 Disaster Declaration

**Authority to Declare:**
- Infrastructure Manager
- CTO
- Director of Operations

**Declaration Criteria:**
- System unavailable for >2 hours with no ETA for resolution
- Data loss detected
- Security breach requiring system rebuild
- Physical disaster at primary data center

**Declaration Process:**
1. Incident identified and assessed
2. Decision maker notified
3. Disaster declared via emergency communication channel
4. DR team assembled
5. DR plan activation announced
6. Begin recovery procedures

---

## 4. DR Team Roles and Responsibilities

### 4.1 Team Structure

**DR Commander**
- **Primary:** Adrian Johnson (adrian207@gmail.com)
- **Backup:** [Infrastructure Manager Name]
- **Responsibilities:**
  - Overall coordination
  - Decision making
  - Communication with executive leadership
  - Declares when recovery is complete

**Infrastructure Lead**
- **Primary:** [Senior Infrastructure Engineer]
- **Backup:** [Infrastructure Engineer]
- **Responsibilities:**
  - Server provisioning and recovery
  - Network configuration
  - Coordinates with cloud/datacenter team

**Database Administrator**
- **Primary:** [DBA]
- **Backup:** [Junior DBA]
- **Responsibilities:**
  - Database recovery
  - Data integrity verification
  - Performance optimization post-recovery

**Security Engineer**
- **Primary:** [Security Engineer]
- **Backup:** [Security Analyst]
- **Responsibilities:**
  - Vault recovery and unsealing
  - Certificate management
  - Security validation post-recovery

**Application Engineer**
- **Primary:** [DevOps Lead]
- **Backup:** [Senior DevOps Engineer]
- **Responsibilities:**
  - AWX/DSC service recovery
  - Configuration validation
  - Integration testing

**Communications Coordinator**
- **Primary:** [Operations Manager]
- **Backup:** [Project Manager]
- **Responsibilities:**
  - Stakeholder communication
  - Status updates
  - Documentation of recovery timeline

### 4.2 Contact Information

**DR Team Roster:**

| Name | Role | Phone | Email | Alternate Contact |
|------|------|-------|-------|-------------------|
| Adrian Johnson | DR Commander | [PHONE] | adrian207@gmail.com | [ALTERNATE] |
| [Name] | Infrastructure Lead | [PHONE] | [EMAIL] | [ALTERNATE] |
| [Name] | DBA | [PHONE] | [EMAIL] | [ALTERNATE] |
| [Name] | Security Engineer | [PHONE] | [EMAIL] | [ALTERNATE] |
| [Name] | Application Engineer | [PHONE] | [EMAIL] | [ALTERNATE] |
| [Name] | Comms Coordinator | [PHONE] | [EMAIL] | [ALTERNATE] |

**Escalation Contacts:**
- CTO: [Name, Phone, Email]
- Infrastructure Manager: [Name, Phone, Email]
- Security Director: [Name, Phone, Email]

**24/7 Contact Methods:**
- Primary: PagerDuty escalation
- Secondary: Mobile phones
- Tertiary: Microsoft Teams/Slack
- Emergency: Personal contact (if all digital communications down)

### 4.3 Assembly Procedures

**When Disaster Declared:**
1. DR Commander notifies all team members via emergency contact method
2. Team members acknowledge receipt within 15 minutes
3. Initial conference call/meeting within 30 minutes
4. Establish command center (physical or virtual)
5. Begin status assessment and recovery planning

**War Room:**
- **Physical:** Conference Room C, Building 2 (if accessible)
- **Virtual:** Microsoft Teams Channel: "DR-ConfigMgmt"
- **Bridge Line:** +1-555-0100, PIN: 123456#

---

## 5. Recovery Procedures

### 5.1 Pre-Recovery Assessment

**Step 1: Assess Damage Scope**

```bash
# Create assessment document
cat > /tmp/dr-assessment.txt <<EOF
DR Assessment - $(date)
DR Commander: [Name]
Disaster Type: [Level 1-4]
Time Discovered: [TIME]
Systems Affected:
- [ ] DSC Pull Servers
- [ ] AWX
- [ ] Vault
- [ ] SQL Server
- [ ] PostgreSQL
- [ ] Monitoring
- [ ] Git Repository
- [ ] Network Infrastructure

Data Loss: [YES/NO]
Estimated Data Loss Window: [TIME RANGE]

Initial Root Cause: [DESCRIPTION]
EOF
```

**Step 2: Locate Latest Backups**

```bash
# Verify backup availability
echo "=== Checking Backup Availability ===" >> /tmp/dr-assessment.txt

# SQL Server backups
ssh backup-server "ls -lh /backup/sql/ | tail -10" >> /tmp/dr-assessment.txt

# Vault snapshots
ssh backup-server "ls -lh /backup/vault/snapshots/ | tail -10" >> /tmp/dr-assessment.txt

# AWX backups
ssh backup-server "ls -lh /backup/awx/ | tail -10" >> /tmp/dr-assessment.txt

# Git repository backups
ssh backup-server "ls -lh /backup/git/ | tail -10" >> /tmp/dr-assessment.txt
```

**Step 3: Determine Recovery Strategy**

- **Option A:** Restore in place (if infrastructure intact)
- **Option B:** Restore to new infrastructure (if original destroyed)
- **Option C:** Failover to DR site (if configured)

**Step 4: Notify Stakeholders**

```
TO: All Configuration Management Users
FROM: DR Commander
SUBJECT: [URGENT] Configuration Management DR Event

A disaster recovery event has been declared for the Configuration Management infrastructure.

Disaster Level: [1-4]
Impact: Configuration management unavailable
Expected Resolution: [TIME]
Status Updates: Every 2 hours via [METHOD]

Actions Required:
- Do not attempt manual configurations during this time
- Contact your manager for critical urgent changes
- Monitor [STATUS PAGE URL] for updates

The DR team is working to restore services. Thank you for your patience.

[DR Commander Name]
```

---

### 5.2 HashiCorp Vault Recovery

**Scenario:** Vault cluster completely destroyed

**Prerequisites:**
- Vault snapshots available in backup location
- Unseal keys retrievable from secure offline storage
- New infrastructure provisioned (if needed)

**Procedure:**

**Step 1: Provision Infrastructure**

```bash
cd terraform/production/vault

# If original infrastructure intact, skip this step
# Otherwise, provision new VMs
terraform init
terraform apply -var="vault_recovery_mode=true"

# Note new IP addresses
terraform output vault_ips
```

**Step 2: Install Vault**

```bash
# Run Vault installation playbook
ansible-playbook -i inventory/production/recovery playbooks/install-vault.yml
```

**Step 3: Retrieve Latest Snapshot**

```bash
# From backup server
LATEST_SNAPSHOT=$(ssh backup-server "ls -t /backup/vault/snapshots/vault_snapshot_*.snap | head -1")
echo "Latest snapshot: $LATEST_SNAPSHOT"

# Copy to local system
scp backup-server:$LATEST_SNAPSHOT /tmp/vault_snapshot.snap

# If encrypted, decrypt
gpg --decrypt /tmp/vault_snapshot.snap.gpg > /tmp/vault_snapshot.snap
```

**Step 4: Initialize New Vault Cluster**

```bash
ssh vault-01 "export VAULT_ADDR='https://127.0.0.1:8200' && vault operator init -recovery-shares=1 -recovery-threshold=1"

# Save recovery keys (for auto-unseal scenario)
```

**Step 5: Restore Snapshot**

```bash
# Copy snapshot to vault server
scp /tmp/vault_snapshot.snap vault-01:/tmp/

# Restore snapshot
ssh vault-01 "export VAULT_ADDR='https://127.0.0.1:8200' && vault operator raft snapshot restore /tmp/vault_snapshot.snap"
```

**Step 6: Unseal Vault** (if not using auto-unseal)

```bash
# Retrieve unseal keys from secure offline storage
# (Physical safe, HSM, password manager, etc.)

ssh vault-01 "export VAULT_ADDR='https://127.0.0.1:8200' && vault operator unseal <key1>"
ssh vault-01 "export VAULT_ADDR='https://127.0.0.1:8200' && vault operator unseal <key2>"
ssh vault-01 "export VAULT_ADDR='https://127.0.0.1:8200' && vault operator unseal <key3>"
```

**Step 7: Join Additional Nodes**

```bash
# Get join token
JOIN_TOKEN=$(ssh vault-01 "export VAULT_ADDR='https://127.0.0.1:8200' && vault operator raft join https://vault-01:8200 -format=json | jq -r '.leader_client_ca_cert'")

# Join vault-02
ssh vault-02 "export VAULT_ADDR='https://127.0.0.1:8200' && vault operator raft join https://vault-01:8200"

# Join vault-03
ssh vault-03 "export VAULT_ADDR='https://127.0.0.1:8200' && vault operator raft join https://vault-01:8200"

# Unseal additional nodes
ssh vault-02 "vault operator unseal <key1> && vault operator unseal <key2> && vault operator unseal <key3>"
ssh vault-03 "vault operator unseal <key1> && vault operator unseal <key2> && vault operator unseal <key3>"
```

**Step 8: Verify Cluster Health**

```bash
ssh vault-01 "export VAULT_ADDR='https://127.0.0.1:8200' && vault operator members"

# Expected output: 3 nodes, all active

# Test secret retrieval
ssh vault-01 "export VAULT_ADDR='https://127.0.0.1:8200' && vault login <root-token> && vault kv get secret/production/test"
```

**Step 9: Update DNS (if IP addresses changed)**

```bash
# Update DNS records to point to new Vault IPs
# Via your DNS management system
```

**Recovery Time:** 1-2 hours  
**RPO Achievement:** Yes (if snapshot within 1 hour)

---

### 5.3 DSC Pull Server Recovery

**Scenario:** DSC Pull Servers destroyed, SQL database intact

**Procedure:**

**Step 1: Provision New Servers**

```bash
cd terraform/production/dsc-pull-servers
terraform apply
```

**Step 2: Install DSC Pull Server Components**

```powershell
# On each new DSC Pull Server
Invoke-Command -ComputerName dsc-01-new,dsc-02-new -ScriptBlock {
    # Install IIS
    Install-WindowsFeature -Name Web-Server,Web-Asp-Net45,Web-Mgmt-Service
    
    # Install DSC Service
    Install-WindowsFeature -Name DSC-Service
    
    # Configure IIS for DSC
    Install-Module -Name xPSDesiredStateConfiguration -Force
    
    # Import DSC resource
    Import-Module xPSDesiredStateConfiguration
}
```

**Step 3: Restore Configuration Files**

```powershell
# Restore modules and configurations from backup
$BackupServer = "\\backup-server\DSCBackup"
$DSCPullServers = @("dsc-01-new", "dsc-02-new")

foreach ($Server in $DSCPullServers) {
    # Restore modules
    Copy-Item "$BackupServer\Modules\*" "\\$Server\C$\Program Files\WindowsPowerShell\DscService\Modules\" -Recurse -Force
    
    # Restore configurations
    Copy-Item "$BackupServer\Configuration\*" "\\$Server\C$\Program Files\WindowsPowerShell\DscService\Configuration\" -Recurse -Force
    
    # Restore registration keys
    Copy-Item "$BackupServer\RegistrationKeys.txt" "\\$Server\C$\Program Files\WindowsPowerShell\DscService\"
}
```

**Step 4: Configure Database Connection**

```powershell
# Update web.config on each pull server
$DSCServers = @("dsc-01-new", "dsc-02-new")
$SQLServer = "10.10.30.10"  # Existing SQL server

foreach ($Server in $DSCServers) {
    Invoke-Command -ComputerName $Server -ScriptBlock {
        $webConfig = "C:\Program Files\WindowsPowerShell\DscService\web.config"
        $xml = [xml](Get-Content $webConfig)
        
        $connString = $xml.configuration.appSettings.add | Where-Object {$_.key -eq "dbconnectionstr"}
        $connString.value = "Provider=SQLOLEDB;Data Source=$using:SQLServer;Initial Catalog=DSC;Integrated Security=SSPI;"
        
        $xml.Save($webConfig)
    }
}
```

**Step 5: Install SSL Certificates**

```powershell
# Restore certificates from Vault or cert backup
$CertPassword = ConvertTo-SecureString "CertPassword" -AsPlainText -Force
$DSCServers = @("dsc-01-new", "dsc-02-new")

foreach ($Server in $DSCServers) {
    # Copy certificate
    Copy-Item "\\backup-server\certs\dsc.corp.contoso.com.pfx" "\\$Server\C$\Temp\"
    
    # Import certificate
    Invoke-Command -ComputerName $Server -ScriptBlock {
        Import-PfxCertificate -FilePath "C:\Temp\dsc.corp.contoso.com.pfx" `
            -CertStoreLocation Cert:\LocalMachine\My `
            -Password $using:CertPassword
        
        # Bind to IIS
        $cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Subject -like "*dsc.corp.contoso.com*"}
        New-WebBinding -Name "Default Web Site" -Protocol https -Port 443
        $binding = Get-WebBinding -Name "Default Web Site" -Protocol https
        $binding.AddSslCertificate($cert.Thumbprint, "My")
    }
}
```

**Step 6: Configure DFS-R** (if used)

```powershell
# Add new servers to DFS-R replication group
Add-DfsrMember -GroupName "DSC-Replication" -ComputerName "dsc-01-new","dsc-02-new"

# Configure replication folders
Set-DfsrMembership -GroupName "DSC-Replication" -FolderName "Modules" `
    -ComputerName "dsc-01-new" -ContentPath "C:\Program Files\WindowsPowerShell\DscService\Modules"
```

**Step 7: Update Load Balancer**

```bash
# Remove old servers from LB pool
# Add new servers to LB pool
# Via your load balancer management interface

# Azure example:
az network lb address-pool address remove --lb-name lb-dsc-prod --pool-name backend-pool --ip-address 10.10.10.10
az network lb address-pool address add --lb-name lb-dsc-prod --pool-name backend-pool --ip-address 10.10.10.15
```

**Step 8: Verify Pull Server Operation**

```powershell
# Test pull server endpoint
Invoke-WebRequest -Uri "https://dsc.corp.contoso.com/PSDSCPullServer.svc" -UseBasicParsing

# Should return HTTP 200

# Test node registration
$TestNode = "testnode01"
Invoke-Command -ComputerName $TestNode -ScriptBlock {
    Update-DscConfiguration -Wait -Verbose
}

# Check database for successful check-in
$Query = "SELECT TOP 10 NodeName, LastCheckIn FROM StatusReport ORDER BY LastCheckIn DESC"
Invoke-Sqlcmd -ServerInstance "10.10.30.10" -Database "DSC" -Query $Query
```

**Recovery Time:** 3-4 hours  
**RPO Achievement:** Yes (if database backup within 4 hours)

---

### 5.4 Ansible AWX Recovery

**Scenario:** AWX server destroyed

**Procedure:**

**Step 1: Provision New Server**

```bash
cd terraform/production/awx
terraform apply -var="awx_recovery_mode=true"
```

**Step 2: Install AWX**

```bash
# SSH to new AWX server
ssh ubuntu@<new-awx-ip>

# Clone AWX
git clone https://github.com/ansible/awx.git
cd awx
git checkout 23.3.0

cd installer
cp inventory inventory.bak
nano inventory
```

Configure inventory with production settings (external PostgreSQL)

```bash
ansible-playbook -i inventory install.yml
```

**Step 3: Restore AWX Configuration**

```bash
# Get latest AWX backup
LATEST_BACKUP=$(ssh backup-server "ls -t /backup/awx/awx_backup_*.json | head -1")
scp backup-server:$LATEST_BACKUP /tmp/awx_backup.json

# Install AWX CLI
pip3 install awxkit

# Configure AWX CLI
awx --conf.host http://localhost \
    --conf.username admin \
    --conf.password <admin-password> \
    login

# Restore configuration
awx import < /tmp/awx_backup.json
```

**Step 4: Sync Projects**

```bash
# Trigger project sync for all projects
for project_id in $(awx projects list -f json | jq -r '.[].id'); do
    awx projects update $project_id --monitor
done
```

**Step 5: Sync Inventories**

```bash
# Sync all dynamic inventory sources
for source_id in $(awx inventory_sources list -f json | jq -r '.[].id'); do
    awx inventory_sources update $source_id --monitor
done
```

**Step 6: Verify AWX Operation**

```bash
# List job templates
awx job_templates list -f human

# Launch test job
awx job_templates launch "Test - Connectivity Check" --monitor

# Verify successful completion
```

**Step 7: Update DNS**

```bash
# Update DNS record for awx.corp.contoso.com to point to new IP
# Via your DNS management system
```

**Recovery Time:** 3-4 hours  
**RPO Achievement:** Partial (projects resynced from Git, recent job history may be lost within RPO window)

---

### 5.5 SQL Server Database Recovery

**Scenario:** SQL Server failed, backups available

**Procedure:**

**Step 1: Provision New SQL Server** (if needed)

```bash
cd terraform/production/sql-server
terraform apply
```

**Step 2: Install SQL Server**

```powershell
# Automated via Terraform/Ansible or manual installation
# Install SQL Server 2019 Standard Edition
```

**Step 3: Restore Database from Backup**

```powershell
# Copy latest backup from backup server
$BackupPath = "\\backup-server\SQLBackups"
$LatestFullBackup = Get-ChildItem "$BackupPath\DSC_Full_*.bak" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$LatestDiffBackup = Get-ChildItem "$BackupPath\DSC_Diff_*.bak" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

# Copy to SQL server
Copy-Item $LatestFullBackup.FullName "E:\SQLBackups\"
Copy-Item $LatestDiffBackup.FullName "E:\SQLBackups\"

# Restore full backup (with NORECOVERY to apply differential)
Restore-SqlDatabase -ServerInstance "localhost" -Database "DSC" `
    -BackupFile "E:\SQLBackups\$($LatestFullBackup.Name)" `
    -NoRecovery -ReplaceDatabase

# Restore differential backup
Restore-SqlDatabase -ServerInstance "localhost" -Database "DSC" `
    -BackupFile "E:\SQLBackups\$($LatestDiffBackup.Name)" `
    -NoRecovery

# If transaction log backups available, restore those too
$LogBackups = Get-ChildItem "$BackupPath\DSC_Log_*.trn" | 
    Where-Object {$_.LastWriteTime -gt $LatestDiffBackup.LastWriteTime} |
    Sort-Object LastWriteTime

foreach ($LogBackup in $LogBackups) {
    Copy-Item $LogBackup.FullName "E:\SQLBackups\"
    Restore-SqlDatabase -ServerInstance "localhost" -Database "DSC" `
        -BackupFile "E:\SQLBackups\$($LogBackup.Name)" `
        -NoRecovery
}

# Final recovery
Restore-SqlDatabase -ServerInstance "localhost" -Database "DSC" -NoRecovery:$false
```

**Step 4: Verify Database Integrity**

```powershell
# Check database status
Invoke-Sqlcmd -ServerInstance "localhost" -Query "SELECT name, state_desc FROM sys.databases WHERE name = 'DSC'"

# Run integrity check
Invoke-Sqlcmd -ServerInstance "localhost" -Database "DSC" -Query "DBCC CHECKDB('DSC') WITH NO_INFOMSGS"

# Verify data
Invoke-Sqlcmd -ServerInstance "localhost" -Database "DSC" -Query "SELECT COUNT(*) as NodeCount FROM dbo.RegistrationData"
```

**Step 5: Update Connection Strings** (if IP changed)

Update all systems pointing to SQL Server with new connection string

**Recovery Time:** 2-4 hours  
**RPO Achievement:** Yes (based on backup frequency)

---

### 5.6 PostgreSQL Database Recovery

**Scenario:** PostgreSQL database for AWX failed

**Procedure:**

**Step 1: Provision New PostgreSQL Server** (if needed)

```bash
cd terraform/production/postgresql
terraform apply
```

**Step 2: Install PostgreSQL**

```bash
ansible-playbook -i inventory/production playbooks/install-postgresql.yml
```

**Step 3: Restore Database**

```bash
# Copy latest backup
LATEST_BACKUP=$(ssh backup-server "ls -t /backup/postgresql/awx_*.dump | head -1")
scp backup-server:$LATEST_BACKUP /tmp/awx_backup.dump

# Create database
sudo -u postgres psql <<EOF
CREATE DATABASE awx;
CREATE USER awx WITH PASSWORD 'SecurePassword123!';
GRANT ALL PRIVILEGES ON DATABASE awx TO awx;
EOF

# Restore database
sudo -u postgres pg_restore -d awx /tmp/awx_backup.dump

# Or if using SQL dump:
sudo -u postgres psql awx < /tmp/awx_backup.sql
```

**Step 4: Verify Database**

```bash
sudo -u postgres psql -d awx -c "SELECT COUNT(*) FROM main_jobevent;"
```

**Step 5: Update AWX Connection** (if IP changed)

Update AWX configuration to point to new PostgreSQL server

**Recovery Time:** 2-3 hours  
**RPO Achievement:** Yes (based on backup frequency)

---

### 5.7 Complete Infrastructure Recovery

**Scenario:** Total site loss, rebuild from scratch

**Procedure:**

**Phase 1: Infrastructure Provisioning (Day 1)**

```bash
# Provision all infrastructure via Terraform
cd terraform/production

# Provision in order:
terraform apply -target=module.network
terraform apply -target=module.vault
terraform apply -target=module.databases
terraform apply -target=module.control_plane
terraform apply -target=module.monitoring
```

**Phase 2: Base Configuration (Day 1-2)**

```bash
# Apply base configuration to all systems
ansible-playbook -i inventory/production/recovery playbooks/base-config.yml
```

**Phase 3: Core Services Recovery (Day 2)**

1. Recover Vault (Section 5.2)
2. Recover Databases (Sections 5.5, 5.6)

**Phase 4: Control Plane Recovery (Day 2-3)**

1. Recover DSC Pull Servers (Section 5.3)
2. Recover Ansible AWX (Section 5.4)

**Phase 5: Supporting Services (Day 3)**

1. Recover Monitoring (Prometheus, Grafana)
2. Recover Alerting (Alertmanager)

**Phase 6: Validation and Testing (Day 3-4)**

1. Test node onboarding
2. Test configuration deployment
3. Test secrets retrieval
4. Test monitoring and alerting
5. Load testing

**Total Recovery Time:** 3-4 days for complete rebuild  
**RPO Achievement:** Variable based on backup currency

---

## 6. Post-Recovery Procedures

### 6.1 Validation Checklist

After recovery, verify all systems operational:

**Infrastructure Health:**
- [ ] All VMs/servers powered on and accessible
- [ ] Network connectivity verified
- [ ] DNS resolution working
- [ ] Firewall rules applied
- [ ] Load balancers functioning

**Service Health:**
- [ ] Vault unsealed and accessible
- [ ] DSC Pull Servers responding
- [ ] AWX web UI accessible
- [ ] SQL Server online
- [ ] PostgreSQL online
- [ ] Prometheus collecting metrics
- [ ] Grafana displaying dashboards

**Functional Validation:**
- [ ] Test node can register with pull server
- [ ] Test configuration successfully deployed
- [ ] Secrets can be retrieved from Vault
- [ ] AWX can execute test job
- [ ] Monitoring alerts functioning
- [ ] Backups resuming automatically

**Data Integrity:**
- [ ] Spot-check database records
- [ ] Verify configuration files present
- [ ] Verify Git repositories synced
- [ ] Verify secret values correct

**Performance:**
- [ ] Response times within normal range
- [ ] Resource utilization normal
- [ ] No errors in logs

### 6.2 Communication

**Recovery Complete Announcement:**

```
TO: All Configuration Management Users
FROM: DR Commander
SUBJECT: Configuration Management Services Restored

The Configuration Management infrastructure has been successfully recovered and is now operational.

Recovery Completed: [DATE/TIME]
Total Downtime: [DURATION]
Data Loss: [NONE / MINIMAL / DESCRIPTION]

All services are now available:
- DSC Pull Server: https://dsc.corp.contoso.com
- Ansible AWX: https://awx.corp.contoso.com
- Grafana: https://grafana.corp.contoso.com

If you experience any issues, please contact the operations team.

Thank you for your patience during this recovery.

[DR Commander Name]
```

### 6.3 Documentation

**Required Documentation:**
1. **DR Event Log:** Timeline of all recovery activities
2. **Recovery Metrics:** Actual RTO/RPO achieved vs. targets
3. **Issues Encountered:** Problems during recovery
4. **Lessons Learned:** What worked, what didn't
5. **Action Items:** Improvements to procedures or infrastructure

**DR Event Report Template:**

```
DISASTER RECOVERY EVENT REPORT

Event ID: DR-2025-001
Date: [DATE]
DR Commander: [NAME]

1. INCIDENT SUMMARY
   - Disaster Type: [Level 1-4, description]
   - Root Cause: [Description]
   - Systems Affected: [List]
   - Time Discovered: [TIME]
   - Time Declared: [TIME]
   - Time Resolved: [TIME]
   - Total Downtime: [DURATION]

2. RECOVERY OBJECTIVES
   | Component | Target RTO | Actual RTO | Target RPO | Actual RPO | Met? |
   |-----------|------------|------------|------------|------------|------|
   | Vault     | 1 hour     | [ACTUAL]   | 1 hour     | [ACTUAL]   | Y/N  |
   | DSC       | 4 hours    | [ACTUAL]   | 4 hours    | [ACTUAL]   | Y/N  |
   | AWX       | 4 hours    | [ACTUAL]   | 6 hours    | [ACTUAL]   | Y/N  |

3. RECOVERY TIMELINE
   [Detailed timeline of activities]

4. ISSUES ENCOUNTERED
   - [Issue 1 and resolution]
   - [Issue 2 and resolution]

5. LESSONS LEARNED
   - What Went Well: [List]
   - What Needs Improvement: [List]

6. ACTION ITEMS
   | Item | Owner | Due Date | Status |
   |------|-------|----------|--------|
   | [Action 1] | [Owner] | [Date] | Open |

7. RECOMMENDATIONS
   [Recommendations for preventing recurrence or improving recovery]

Prepared By: [Name]
Date: [Date]
Approved By: [DR Commander]
```

---

## 7. DR Testing

### 7.1 Testing Schedule

**Test Frequency:**
- **Quarterly:** Tabletop exercise (2 hours)
- **Semi-Annual:** Component recovery test (4 hours)
- **Annual:** Full DR exercise (8 hours + 1 day recovery)

**Test Planning:**
- Schedule 60 days in advance
- Notify stakeholders 30 days in advance
- Prepare test plan 14 days in advance
- Conduct pre-test meeting 7 days in advance

### 7.2 Tabletop Exercise

**Purpose:** Validate team knowledge of procedures without actual recovery

**Procedure:**
1. Assemble DR team
2. Present disaster scenario
3. Team walks through recovery procedures step-by-step
4. Identify gaps or issues
5. Document findings
6. Update procedures as needed

**Example Scenarios:**
- Ransomware encrypts all production systems
- Data center fire destroys all servers
- Database corruption detected
- Key team member unavailable

### 7.3 Component Recovery Test

**Purpose:** Validate recovery of one component in non-production

**Procedure:**
1. Choose component to test (rotate each test)
2. Take snapshot/backup of current state
3. Destroy component in test environment
4. Execute recovery procedures
5. Validate recovery successful
6. Restore to pre-test state
7. Document results

**Test Rotation:**
- Q1: Vault recovery
- Q2: Database recovery
- Q3: Control plane recovery
- Q4: Monitoring recovery

### 7.4 Full DR Exercise

**Purpose:** Validate complete DR capability

**Procedure:**
1. Schedule maintenance window (Saturday, 8 AM - 5 PM)
2. Notify all stakeholders
3. Take snapshots of production environment (for quick rollback)
4. Simulate disaster (shut down all production systems)
5. Execute full recovery procedures
6. Validate all services restored
7. Run validation tests
8. Either keep recovered systems or rollback to snapshots
9. Conduct post-exercise review

**Success Criteria:**
- All RTO targets met
- All RPO targets met
- All validation tests pass
- DR team successfully executed procedures

**Test Report:**

Document results, findings, and action items from test

---

## 8. DR Infrastructure and Resources

### 8.1 Backup Infrastructure

**Primary Backup Storage:**
- Location: [On-premises NAS / Cloud storage]
- Capacity: 10 TB
- Retention: Per backup policy (Section 8 of main spec)
- Security: Encrypted, access controlled

**Offsite Backup Storage:**
- Location: [Cloud provider / Secondary datacenter]
- Capacity: 10 TB
- Replication: Daily sync from primary
- Security: Encrypted, immutable for 30 days

**Backup Verification:**
- Automated verification: Daily (checksum validation)
- Test restore: Monthly (one random backup)

### 8.2 DR Site Configuration

**Option 1: Cold DR Site** (rebuild on demand)
- Cloud provider account with pre-configured Terraform
- Recovery time: 3-4 days
- Cost: Low (pay as you go)

**Option 2: Warm DR Site** (minimal infrastructure running)
- Vault cluster running (unsealed)
- Databases with replication
- Control plane infrastructure provisioned but powered off
- Recovery time: 4-8 hours
- Cost: Medium

**Option 3: Hot DR Site** (active/active or active/standby)
- All infrastructure running
- Active replication
- Automatic failover
- Recovery time: <1 hour
- Cost: High (2x infrastructure)

**Current Configuration:** [Specify which option is implemented]

### 8.3 Required Assets for Recovery

**Physical Items:**
- Vault unseal keys (in physical safe)
- Break-glass account credentials (in sealed envelope)
- Recovery documentation (printed copy)
- Contact lists (printed copy)
- External hard drive with offline backups (updated monthly)

**Digital Assets:**
- Terraform code (Git repository)
- Ansible playbooks (Git repository)
- Documentation (Git repository)
- Backup data (primary and offsite storage)
- Software installation media (if not downloadable)
- License keys (stored in password manager)

**Access Requirements:**
- Cloud provider credentials
- DNS management access
- Certificate authority access
- Backup storage access
- Physical facility access (if applicable)

---

## 9. Continuous Improvement

### 9.1 DR Plan Maintenance

**Review Schedule:**
- Quarterly: Light review (contact updates, minor procedure updates)
- Annual: Full review (comprehensive update)
- Post-DR Event: Update based on lessons learned
- After Major Architecture Change: Update affected sections

**Review Responsibilities:**
- DR Commander: Oversees review process
- Infrastructure Lead: Technical accuracy
- Security Engineer: Security controls
- All Team Members: Review sections relevant to their role

### 9.2 Metrics and KPIs

**Track and Report:**
- RTO/RPO targets vs. actual (from tests and real events)
- Backup success rate (target: 100%)
- Test restore success rate (target: >95%)
- DR team response time (target: <30 minutes)
- DR exercise completion rate (target: 100% of scheduled exercises)

**Improvement Targets:**
- Reduce RTO by 10% year over year
- Reduce RPO by 10% year over year
- Increase automation of recovery procedures

---

## 10. Appendix

### Appendix A: Quick Reference - Emergency Contacts

```
EMERGENCY CONTACTS

DR Commander: Adrian Johnson
Mobile: [PHONE]
Email: adrian207@gmail.com

PagerDuty Escalation: 1-844-700-XXXX
Account: [ACCOUNT ID]

Backup Site Access: [PROVIDER] Support 1-800-XXX-XXXX

Cloud Provider Support:
- Azure: 1-800-XXX-XXXX, Subscription ID: [ID]
- AWS: 1-800-XXX-XXXX, Account ID: [ID]
```

### Appendix B: Recovery Time Calculation

**RTO Breakdown Example:**

For DSC Pull Server recovery (4 hour RTO):
- Infrastructure provisioning: 30 minutes
- OS installation/configuration: 60 minutes
- Application installation: 45 minutes
- Configuration restore: 30 minutes
- Database connectivity: 15 minutes
- Testing and validation: 60 minutes
- **Total:** 3 hours 40 minutes (within 4 hour RTO)

### Appendix C: Disaster Declaration Form

```
DISASTER DECLARATION FORM

Date/Time: ___________________
Declared By: ___________________  Title: ___________________

Disaster Level: ☐ Level 1  ☐ Level 2  ☐ Level 3  ☐ Level 4

Description of Incident:
________________________________________________________________________
________________________________________________________________________

Systems Affected:
☐ Vault  ☐ DSC Pull Servers  ☐ AWX  ☐ SQL Server  ☐ PostgreSQL  ☐ Monitoring  ☐ Other: __________

Estimated Impact:
☐ Complete outage  ☐ Partial degradation  ☐ Data loss

Recovery Strategy:
☐ Restore in place  ☐ Restore to new infrastructure  ☐ Failover to DR site

DR Team Assembled: ☐ Yes  ☐ No
Stakeholders Notified: ☐ Yes  ☐ No

Signature: ___________________  Date: ___________________
```

---

## Document Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-17 | Adrian Johnson | Initial release |

---

**Document End**

