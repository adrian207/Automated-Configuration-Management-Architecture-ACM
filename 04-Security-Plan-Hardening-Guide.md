# Security Plan & Hardening Guide
## Automated Configuration Management Architecture

**Version:** 1.0  
**Date:** October 17, 2025  
**Status:** Draft  
**Author:** Adrian Johnson  
**Email:** adrian207@gmail.com

**Classification:** Confidential - Internal Use Only

---

## 1. Document Purpose

This Security Plan defines the security controls, hardening standards, and security procedures for the Automated Configuration Management Architecture. It provides detailed guidance on implementing and maintaining security across all components.

**Target Audience:** Security engineers, system administrators, compliance officers

---

## 2. Security Architecture Overview

### 2.1 Security Principles

The security architecture is built on the following principles:

1. **Defense in Depth:** Multiple layers of security controls
2. **Least Privilege:** Minimal access rights required to perform duties
3. **Zero Trust:** Verify explicitly, use least privileged access, assume breach
4. **Encryption Everywhere:** Data encrypted in transit and at rest
5. **Auditability:** All actions logged and monitored

### 2.2 Security Boundaries

```
┌─────────────────────────────────────────────────────┐
│                External Network                      │
│               (Untrusted - Internet)                 │
└──────────────────────┬──────────────────────────────┘
                       │
              ┌────────▼────────┐
              │   Firewall      │
              │  (Edge Defense) │
              └────────┬────────┘
                       │
┌──────────────────────▼───────────────────────────────┐
│            DMZ / Jump Host Zone                      │
│            (Bastion Hosts with MFA)                  │
└──────────────────────┬───────────────────────────────┘
                       │
              ┌────────▼────────┐
              │  Internal FW    │
              └─────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
┌───────▼──────┐ ┌────▼─────┐ ┌─────▼────────┐
│Management    │ │Monitoring│ │Data Tier     │
│Tier          │ │Tier      │ │(Most         │
│(Control      │ │          │ │Restricted)   │
│Plane)        │ │          │ │              │
└──────────────┘ └──────────┘ └──────────────┘
```

---

## 3. Access Control

### 3.1 Authentication Requirements

#### 3.1.1 Human User Authentication

**Interactive Access Requirements:**
- Multi-factor authentication (MFA) mandatory for all administrative access
- Strong password policy: minimum 14 characters, complexity requirements
- Account lockout after 5 failed attempts
- Session timeout: 15 minutes of inactivity
- Re-authentication required for privileged operations

**Supported MFA Methods (in order of preference):**
1. Hardware tokens (YubiKey, smart cards)
2. TOTP authenticator apps (Microsoft Authenticator, Google Authenticator)
3. Push notifications (Duo, Okta)

**Password Policy:**
```
Minimum Length: 14 characters
Complexity: Must contain:
  - Uppercase letters (A-Z)
  - Lowercase letters (a-z)
  - Numbers (0-9)
  - Special characters (!@#$%^&*)
Password History: Last 12 passwords cannot be reused
Maximum Age: 90 days
Minimum Age: 1 day
Lockout Threshold: 5 failed attempts
Lockout Duration: 30 minutes (or admin unlock)
```

#### 3.1.2 Service Account Authentication

**Requirements:**
- No interactive login permitted
- SSH key-based authentication (4096-bit RSA minimum)
- API tokens with expiration (maximum 90 days)
- Service principal authentication for cloud services
- Secrets stored only in HashiCorp Vault

**SSH Key Standards:**
```bash
# Generate compliant SSH key
ssh-keygen -t rsa -b 4096 -C "svc-ansible-prod@contoso.com"

# Or use Ed25519 (preferred)
ssh-keygen -t ed25519 -C "svc-ansible-prod@contoso.com"
```

### 3.2 Authorization (RBAC)

#### 3.2.1 Role Definitions

**Platform Administrator**
```yaml
permissions:
  - full_admin_access
  - vault_root_access
  - modify_rbac_policies
  - emergency_access
restrictions:
  - maximum_2_3_accounts
  - activity_logging_mandatory
  - quarterly_access_review
```

**Configuration Engineer**
```yaml
permissions:
  - read_write_git_repositories
  - create_modify_configurations
  - read_secrets_vault (no write/delete)
  - execute_playbooks_dev_test
  - request_prod_deployments
restrictions:
  - cannot_bypass_approvals
  - cannot_modify_rbac
  - audit_all_actions
```

**Operations Engineer**
```yaml
permissions:
  - read_only_configurations
  - execute_approved_playbooks_prod
  - read_monitoring_dashboards
  - acknowledge_alerts
  - read_audit_logs
restrictions:
  - no_configuration_modification
  - no_secrets_access
  - no_rbac_modification
```

**Security Auditor**
```yaml
permissions:
  - read_only_all_systems
  - read_audit_logs
  - export_compliance_reports
restrictions:
  - no_execute_permissions
  - no_secrets_values (metadata only)
  - no_configuration_changes
```

#### 3.2.2 RBAC Implementation

**Active Directory Groups:**
```
CN=ConfigMgmt-PlatformAdmins,OU=Security Groups,DC=corp,DC=contoso,DC=com
CN=ConfigMgmt-ConfigEngineers,OU=Security Groups,DC=corp,DC=contoso,DC=com
CN=ConfigMgmt-OpsEngineers,OU=Security Groups,DC=corp,DC=contoso,DC=com
CN=ConfigMgmt-Auditors,OU=Security Groups,DC=corp,DC=contoso,DC=com
```

**Vault Policies:**

File: `ansible-policy.hcl`
```hcl
# Policy for Ansible service account
path "secret/data/production/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/production/*" {
  capabilities = ["list"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
```

File: `config-engineer-policy.hcl`
```hcl
# Policy for Configuration Engineers
path "secret/data/development/*" {
  capabilities = ["read", "list"]
}

path "secret/data/test/*" {
  capabilities = ["read", "list"]
}

path "secret/data/production/*" {
  capabilities = ["read", "list"]
  # Cannot write or delete
}

path "secret/metadata/*" {
  capabilities = ["list"]
}
```

**AWX/Tower RBAC:**

```python
# Configure via AWX API or UI
# Organization: IT Operations
#   Team: Platform Administrators
#     Permissions: Admin on all resources
#   Team: Configuration Engineers
#     Permissions: Use on dev/test inventories, Execute on dev/test job templates
#   Team: Operations Engineers
#     Permissions: Execute on production job templates, Read on inventories
```

### 3.3 Privileged Access Management

#### 3.3.1 Just-in-Time (JIT) Access

For highly privileged operations, implement JIT access:

**Procedure:**
1. Request elevated access via ServiceNow ticket
2. Manager approval required
3. Access granted for specific time window (max 8 hours)
4. All actions during elevated session logged
5. Access automatically revoked after time window

**Implementation:**
- Use CyberArk, BeyondTrust, or similar PAM solution
- Or implement with Vault dynamic secrets + approval workflow

#### 3.3.2 Break-Glass Procedures

**Emergency Access Accounts:**
- Stored in physical safe, sealed envelope
- Password rotated after each use
- Use logged and reviewed by security team
- Requires incident ticket documenting justification

**Break-Glass Triggers:**
- All platform administrators unavailable
- Critical security incident requiring immediate response
- Vault completely sealed with no unseal keys available (use backup unseal method)

---

## 4. Network Security

### 4.1 Firewall Rules (Detailed)

All firewall rules from DDD Section 7.1 must be implemented with the following additional requirements:

**Default Policies:**
- Inbound: DENY ALL (whitelist only)
- Outbound: DENY ALL except explicitly permitted
- Logging: LOG ALL denied connections

**Rule Review:**
- Quarterly review of all firewall rules
- Remove unused rules
- Document business justification for each rule

### 4.2 Network Segmentation

**VLANs/Subnets:**
- Management Tier: VLAN 10, 10.10.10.0/24
- Monitoring Tier: VLAN 20, 10.10.20.0/24
- Data Tier: VLAN 30, 10.10.30.0/24
- Managed Nodes: VLAN 100, 10.10.100.0/22

**Inter-VLAN Routing:**
- Controlled by firewall/L3 switch ACLs
- No direct communication between tiers without explicit rule
- All cross-tier traffic logged

### 4.3 Network Intrusion Detection

**IDS/IPS Deployment:**
- Deploy IDS sensors on all tier boundaries
- Monitor for:
  - Port scanning
  - Brute force authentication attempts
  - Unusual data exfiltration patterns
  - Known attack signatures

**Recommended Tools:**
- Snort
- Suricata
- Commercial: Palo Alto, Cisco Firepower

---

## 5. Encryption

### 5.1 Data in Transit

**Requirements:**
- TLS 1.2 minimum (TLS 1.3 preferred)
- Strong cipher suites only
- Perfect Forward Secrecy (PFS) required
- Certificate pinning for critical connections

**Approved Cipher Suites:**
```
TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
```

**Disabled/Forbidden:**
- SSLv2, SSLv3, TLS 1.0, TLS 1.1
- Export-grade ciphers
- NULL ciphers
- RC4
- DES, 3DES

**OpenSSL Configuration Example:**
```
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-CHACHA20-POLY1305';
ssl_prefer_server_ciphers on;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;
```

### 5.2 Data at Rest

**Encryption Requirements:**
- All secrets encrypted in HashiCorp Vault (AES-256-GCM)
- Database encryption: Transparent Data Encryption (TDE) on SQL Server
- Disk encryption: BitLocker (Windows), LUKS (Linux)
- Backup encryption: AES-256 encryption for all backups

**Implementation:**

**SQL Server TDE:**
```sql
-- Create Database Master Key
USE master;
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'StrongPassword!23';

-- Create Certificate
CREATE CERTIFICATE TDECert WITH SUBJECT = 'DSC Database TDE Certificate';

-- Create Database Encryption Key
USE DSC;
CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_256
ENCRYPTION BY SERVER CERTIFICATE TDECert;

-- Enable TDE
ALTER DATABASE DSC SET ENCRYPTION ON;
```

**Linux Disk Encryption (LUKS):**
```bash
# Already encrypted at provisioning, verify:
cryptsetup status /dev/mapper/data

# Should show: cipher: aes-xts-plain64, keysize: 512 bits
```

### 5.3 Secrets Management

**HashiCorp Vault Configuration:**

**Transit Encryption Engine** (for application-level encryption):
```bash
# Enable transit engine
vault secrets enable transit

# Create encryption key
vault write -f transit/keys/app-data

# Encrypt data
vault write transit/encrypt/app-data plaintext=$(base64 <<< "sensitive data")

# Decrypt data
vault write transit/decrypt/app-data ciphertext="vault:v1:..."
```

**Encrypted Storage Backend:**
- Vault data encrypted at rest by default
- Seal/Unseal mechanism protects master key
- Unseal keys split using Shamir's Secret Sharing (5 keys, threshold 3)

---

## 6. Operating System Hardening

### 6.1 Windows Server Hardening

**Apply CIS Benchmark for Windows Server 2022:**

**Key Hardening Steps:**

1. **Disable Unnecessary Services**
```powershell
$ServicesToDisable = @(
    'RemoteRegistry',
    'SSDPSRV',
    'upnphost',
    'WerSvc',
    'WSearch'
)

foreach ($Service in $ServicesToDisable) {
    Set-Service -Name $Service -StartupType Disabled
    Stop-Service -Name $Service -Force -ErrorAction SilentlyContinue
}
```

2. **Configure Windows Firewall**
```powershell
# Enable firewall on all profiles
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

# Block all inbound by default
Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block

# Allow outbound by default (restrict further as needed)
Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultOutboundAction Allow
```

3. **Enable Audit Logging**
```powershell
# Configure audit policies
auditpol /set /subcategory:"Logon" /success:enable /failure:enable
auditpol /set /subcategory:"Account Lockout" /success:enable /failure:enable
auditpol /set /subcategory:"User Account Management" /success:enable /failure:enable
auditpol /set /subcategory:"Security Group Management" /success:enable /failure:enable
auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable
```

4. **Configure Security Options**
```powershell
# Rename Administrator account
Rename-LocalUser -Name "Administrator" -NewName "Admin_$(Get-Random)"

# Disable Guest account
Disable-LocalUser -Name "Guest"

# Configure password policy (via GPO preferred)
net accounts /minpwlen:14 /maxpwage:90 /minpwage:1 /uniquepw:12
```

5. **Enable Credential Guard** (Windows Server 2016+)
```powershell
# Enable via Registry
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -Value 1 -PropertyType DWORD -Force
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "RequirePlatformSecurityFeatures" -Value 1 -PropertyType DWORD -Force
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LsaCfgFlags" -Value 1 -PropertyType DWORD -Force
```

6. **Install Security Updates**
```powershell
# Install Windows Updates (use PSWindowsUpdate module)
Install-PackageProvider -Name NuGet -Force
Install-Module -Name PSWindowsUpdate -Force
Get-WindowsUpdate -Install -AcceptAll -AutoReboot
```

### 6.2 Linux Server Hardening

**Apply CIS Benchmark for Ubuntu 22.04 / RHEL 9:**

**Automated Hardening with Ansible:**

File: `ansible/roles/linux-hardening/tasks/main.yml`
```yaml
---
- name: Install security updates
  apt:
    upgrade: dist
    update_cache: yes
  when: ansible_os_family == "Debian"

- name: Disable root login via SSH
  lineinfile:
    path: /etc/ssh/sshd_config
    regexp: '^PermitRootLogin'
    line: 'PermitRootLogin no'
    state: present
  notify: restart sshd

- name: Disable password authentication (key-based only)
  lineinfile:
    path: /etc/ssh/sshd_config
    regexp: '^PasswordAuthentication'
    line: 'PasswordAuthentication no'
    state: present
  notify: restart sshd

- name: Configure SSH banner
  copy:
    dest: /etc/ssh/banner
    content: |
      ***************************************************************************
      UNAUTHORIZED ACCESS TO THIS DEVICE IS PROHIBITED
      All connections are monitored and recorded.
      Disconnect IMMEDIATELY if you are not an authorized user.
      ***************************************************************************
  notify: restart sshd

- name: Enable SSH banner
  lineinfile:
    path: /etc/ssh/sshd_config
    regexp: '^#?Banner'
    line: 'Banner /etc/ssh/banner'
  notify: restart sshd

- name: Configure firewall (ufw)
  ufw:
    rule: "{{ item.rule }}"
    port: "{{ item.port }}"
    proto: "{{ item.proto }}"
  loop:
    - { rule: 'allow', port: '22', proto: 'tcp' }
    - { rule: 'allow', port: '9100', proto: 'tcp' }  # node_exporter
  when: ansible_os_family == "Debian"

- name: Enable firewall
  ufw:
    state: enabled
  when: ansible_os_family == "Debian"

- name: Configure auditd
  copy:
    dest: /etc/audit/rules.d/hardening.rules
    content: |
      # Log all commands executed by root
      -a exit,always -F arch=b64 -F euid=0 -S execve -k root-commands
      -a exit,always -F arch=b32 -F euid=0 -S execve -k root-commands
      
      # Log file deletions
      -a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -k delete
      
      # Log changes to system configuration
      -w /etc/passwd -p wa -k passwd_changes
      -w /etc/group -p wa -k group_changes
      -w /etc/shadow -p wa -k shadow_changes
      -w /etc/sudoers -p wa -k sudoers_changes
  notify: restart auditd

- name: Set file permissions on sensitive files
  file:
    path: "{{ item }}"
    mode: '0600'
  loop:
    - /etc/shadow
    - /etc/gshadow

- name: Install and configure fail2ban
  apt:
    name: fail2ban
    state: present
  when: ansible_os_family == "Debian"

- name: Configure fail2ban for SSH
  copy:
    dest: /etc/fail2ban/jail.local
    content: |
      [sshd]
      enabled = true
      port = 22
      filter = sshd
      logpath = /var/log/auth.log
      maxretry = 3
      bantime = 3600
  notify: restart fail2ban

- name: Disable unused filesystems
  copy:
    dest: /etc/modprobe.d/hardening.conf
    content: |
      install cramfs /bin/true
      install freevxfs /bin/true
      install jffs2 /bin/true
      install hfs /bin/true
      install hfsplus /bin/true
      install udf /bin/true
      install usb-storage /bin/true

- name: Configure kernel parameters (sysctl)
  sysctl:
    name: "{{ item.name }}"
    value: "{{ item.value }}"
    state: present
    reload: yes
  loop:
    - { name: 'net.ipv4.conf.all.send_redirects', value: '0' }
    - { name: 'net.ipv4.conf.default.send_redirects', value: '0' }
    - { name: 'net.ipv4.conf.all.accept_source_route', value: '0' }
    - { name: 'net.ipv4.conf.default.accept_source_route', value: '0' }
    - { name: 'net.ipv4.conf.all.accept_redirects', value: '0' }
    - { name: 'net.ipv4.conf.default.accept_redirects', value: '0' }
    - { name: 'net.ipv4.icmp_echo_ignore_all', value: '0' }
    - { name: 'net.ipv4.icmp_echo_ignore_broadcasts', value: '1' }
    - { name: 'net.ipv4.tcp_syncookies', value: '1' }
    - { name: 'kernel.dmesg_restrict', value: '1' }
```

---

## 7. Application Security

### 7.1 DSC Pull Server Security

**IIS Hardening:**
```powershell
# Remove unnecessary HTTP headers
Remove-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Filter "system.webServer/httpProtocol/customHeaders" -Name . -AtElement @{name='X-Powered-By'}

# Add security headers
Add-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -Filter "system.webServer/httpProtocol/customHeaders" -Name . -Value @{name='X-Content-Type-Options';value='nosniff'}
Add-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -Filter "system.webServer/httpProtocol/customHeaders" -Name . -Value @{name='X-Frame-Options';value='DENY'}
Add-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -Filter "system.webServer/httpProtocol/customHeaders" -Name . -Value @{name='Strict-Transport-Security';value='max-age=31536000'}

# Disable directory browsing
Set-WebConfigurationProperty -Filter /system.webServer/directoryBrowse -Name enabled -Value false

# Configure request filtering
Set-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Filter "system.webServer/security/requestFiltering" -Name "allowDoubleEscaping" -Value $false
Set-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Filter "system.webServer/security/requestFiltering" -Name "allowHighBitCharacters" -Value $false

# Set max request length (100 MB)
Set-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Filter "system.webServer/security/requestFiltering/requestLimits" -Name "maxAllowedContentLength" -Value 104857600
```

**SSL/TLS Configuration:**
```powershell
# Disable weak protocols
New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server' -Force
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server' -Name 'Enabled' -Value 0 -PropertyType DWORD -Force

New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server' -Force
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server' -Name 'Enabled' -Value 0 -PropertyType DWORD -Force

# Enable TLS 1.2 and 1.3
New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -Force
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -Name 'Enabled' -Value 1 -PropertyType DWORD -Force
```

### 7.2 Ansible AWX Security

**Configuration Hardening:**

File: `/etc/tower/settings.py` (or via UI)
```python
# Session security
SESSION_COOKIE_SECURE = True
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = 'Strict'
SESSION_COOKIE_AGE = 900  # 15 minutes

# CSRF protection
CSRF_COOKIE_SECURE = True
CSRF_COOKIE_HTTPONLY = True

# Disable insecure features
ALLOW_JINJA_IN_EXTRA_VARS = False

# Logging
LOG_AGGREGATOR_ENABLED = True
LOG_AGGREGATOR_LEVEL = 'INFO'

# API rate limiting
REST_API_RATE_LIMIT = '100/minute'
```

**Container Security:**
```bash
# Run Docker bench security script
docker run -it --net host --pid host --userns host --cap-add audit_control \
  -v /var/lib:/var/lib \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /usr/lib/systemd:/usr/lib/systemd \
  -v /etc:/etc --label docker_bench_security \
  docker/docker-bench-security

# Review and remediate findings
```

### 7.3 HashiCorp Vault Security

**Production Vault Configuration:**

File: `/opt/vault/config/vault.hcl`
```hcl
storage "raft" {
  path = "/opt/vault/data"
  node_id = "vault-01"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_cert_file = "/opt/vault/tls/vault.crt"
  tls_key_file = "/opt/vault/tls/vault.key"
  tls_min_version = "tls12"
  tls_cipher_suites = "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
  tls_require_and_verify_client_cert = false
  tls_disable_client_certs = false
}

# Enable audit logging
audit_device "file" {
  type = "file"
  path = "/var/log/vault/audit.log"
  log_raw = false
  hmac_accessor = true
  mode = "0600"
  format = "json"
}

# Telemetry for monitoring
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = false
  unauthenticated_metrics_access = false
}

# Enable UI with restrictions
ui = true
ui_header = "Production Vault - Handle with Care"

# Seal configuration (auto-unseal with Azure Key Vault in production)
seal "azurekeyvault" {
  tenant_id      = "your-tenant-id"
  client_id      = "your-client-id"
  client_secret  = "your-client-secret"
  vault_name     = "contoso-vault-unseal"
  key_name       = "vault-unseal-key"
}
```

**Vault Policies Best Practices:**
- Create specific policies for each use case (no overly permissive policies)
- Use path-based restrictions
- Implement time-based access with TTLs
- Regular audit of policy assignments

---

## 8. Vulnerability Management

### 8.1 Vulnerability Scanning

**Scanning Schedule:**
- Weekly: Authenticated scans of all control plane systems
- Monthly: Comprehensive network scans
- After major changes: Ad-hoc scans

**Tools:**
- Nessus Professional
- OpenVAS
- Qualys
- Cloud-native: Azure Security Center, AWS Inspector

**Process:**
1. Run scheduled scan
2. Review findings (prioritize by CVSS score)
3. Create remediation tickets for vulnerabilities >7.0 CVSS
4. Patch within SLA:
   - Critical (9.0-10.0): 7 days
   - High (7.0-8.9): 30 days
   - Medium (4.0-6.9): 90 days
   - Low (0.1-3.9): Next maintenance window

### 8.2 Patch Management

**Patch Schedule:**
- Security patches: Monthly (or emergency as needed)
- Feature updates: Quarterly
- Major version upgrades: Annually (with testing)

**Process:** See Operations Manual SOP-006

### 8.3 Penetration Testing

**Schedule:** Annual or after major architecture changes

**Scope:**
- External network perimeter
- Internal network segmentation
- Authentication mechanisms
- Web application security (AWX UI, Grafana)
- API security (Vault, AWX)
- Privilege escalation paths

**Vendors:** Engage qualified third-party penetration testing firm

---

## 9. Security Monitoring and Incident Response

### 9.1 Security Event Logging

**Log Sources:**
- Windows Event Logs (Security, System, Application)
- Linux syslog
- Application logs (IIS, Vault, AWX, SQL Server)
- Firewall logs
- Authentication logs (AD, Vault)

**Log Collection:**
- Centralize in SIEM or log aggregation platform
- Forward to: Splunk, ELK Stack, Azure Sentinel, or similar
- Real-time correlation and alerting

**Events to Monitor:**
- Failed authentication attempts (>3 in 5 minutes)
- Privilege escalation
- Configuration changes
- Access to sensitive secrets
- Unusual data transfer volumes
- After-hours administrative activity

### 9.2 Security Alerts

**Critical Security Alerts:**

1. **Multiple Failed Authentication Attempts**
   - Threshold: 5 failed attempts in 5 minutes from single source
   - Response: Automatic IP block, notify security team

2. **Root/Administrator Login**
   - Trigger: Any root or built-in administrator login
   - Response: Immediate notification, verify legitimacy

3. **Unauthorized Configuration Change**
   - Trigger: Configuration file modified outside change window
   - Response: Alert security team, investigate

4. **Secrets Access Spike**
   - Trigger: 10x normal rate of secret access
   - Response: Investigate potential secret exfiltration

5. **New Administrative User Created**
   - Trigger: Any new user added to privileged group
   - Response: Verify authorization, alert security team

### 9.3 Incident Response

**Incident Classification:**
- **P1 - Critical:** Active breach, data exfiltration, ransomware
- **P2 - High:** Suspected breach, privilege escalation, malware
- **P3 - Medium:** Policy violation, suspicious activity
- **P4 - Low:** Security misconfiguration

**Incident Response Team:**
- Incident Commander
- Security Analyst
- System Administrator
- Network Engineer
- Legal/Compliance (for P1/P2)

**Incident Response Procedures:**

**Phase 1: Detection and Analysis**
1. Security alert received or suspicious activity reported
2. Triage: Determine if true incident
3. Classify severity
4. Assemble incident response team
5. Begin documenting timeline

**Phase 2: Containment**
1. Isolate affected systems (disconnect from network if needed)
2. Preserve evidence (disk images, memory dumps, logs)
3. Change compromised credentials
4. Block malicious IPs/domains at firewall

**Phase 3: Eradication**
1. Identify and remove root cause (malware, backdoors, unauthorized accounts)
2. Patch vulnerabilities that were exploited
3. Scan all systems for indicators of compromise

**Phase 4: Recovery**
1. Restore systems from clean backups if needed
2. Verify systems clean before reconnecting to network
3. Monitor closely for signs of persistence

**Phase 5: Lessons Learned**
1. Post-incident review meeting
2. Document what happened, what worked, what didn't
3. Update security controls, procedures, training
4. Share findings with team

---

## 10. Compliance and Audit

### 10.1 Compliance Requirements

**Frameworks:**
- SOC 2 Type II
- PCI DSS (if processing payment data)
- HIPAA (if handling healthcare data)
- ISO 27001
- NIST Cybersecurity Framework

**Compliance Mapping:**

| Control | SOC 2 | PCI DSS | HIPAA | Implementation |
|---------|-------|---------|-------|----------------|
| Access Control | CC6.1 | 7.1 | 164.308(a)(4) | Section 3.2 RBAC |
| Encryption | CC6.7 | 4.1 | 164.312(a)(2) | Section 5 Encryption |
| Audit Logging | CC7.2 | 10.1 | 164.312(b) | Section 9.1 Logging |
| Change Management | CC8.1 | 6.4 | 164.308(a)(8) | Main Spec Section 12 |
| Vulnerability Management | CC7.1 | 6.2, 11.2 | 164.308(a)(8) | Section 8 Vuln Mgmt |

### 10.2 Audit Evidence Collection

**Automated Evidence Collection:**

```bash
# Script: /opt/scripts/collect-audit-evidence.sh

#!/bin/bash
# Collect compliance audit evidence

EVIDENCE_DIR="/backup/compliance-evidence/$(date +%Y%m%d)"
mkdir -p $EVIDENCE_DIR

# Access control evidence
echo "Collecting access control evidence..."
vault policy list > $EVIDENCE_DIR/vault-policies.txt
for policy in $(vault policy list); do
    vault policy read $policy > $EVIDENCE_DIR/vault-policy-$policy.hcl
done

# User list from AD
ldapsearch -h dc.contoso.com -b "OU=Security Groups,DC=corp,DC=contoso,DC=com" -s sub "(cn=ConfigMgmt-*)" > $EVIDENCE_DIR/ad-groups.txt

# Audit logs (last 90 days)
journalctl --since "90 days ago" -u vault -u awx > $EVIDENCE_DIR/service-logs.txt

# Configuration files (sanitize secrets!)
cp /opt/vault/config/vault.hcl $EVIDENCE_DIR/
sed -i 's/client_secret = .*/client_secret = "REDACTED"/' $EVIDENCE_DIR/vault.hcl

# Vulnerability scan results (latest)
cp /opt/vulnerability-scans/latest-scan.pdf $EVIDENCE_DIR/

# Backup verification
ls -lh /backup/* > $EVIDENCE_DIR/backup-inventory.txt

# Encrypt evidence package
tar -czf $EVIDENCE_DIR.tar.gz $EVIDENCE_DIR
gpg --encrypt --recipient auditor@contoso.com $EVIDENCE_DIR.tar.gz

echo "Evidence package created: $EVIDENCE_DIR.tar.gz.gpg"
```

**Run monthly before compliance review**

### 10.3 Security Audit Checklist

**Quarterly Security Audit:**

- [ ] Review all user accounts, remove inactive users
- [ ] Review privileged access, verify still required
- [ ] Review firewall rules, remove unused rules
- [ ] Review Vault policies, ensure least privilege
- [ ] Review audit logs for suspicious activity
- [ ] Verify MFA enabled for all users
- [ ] Verify backup and restore tests completed
- [ ] Review vulnerability scan results, verify remediation
- [ ] Review certificate expiration dates
- [ ] Review service account password rotation compliance
- [ ] Test break-glass procedures
- [ ] Review and update security documentation

---

## 11. Security Training

### 11.1 Role-Based Training Requirements

| Role | Required Training | Frequency |
|------|------------------|-----------|
| All Staff | Security Awareness | Annual |
| Platform Administrators | Advanced Security, Incident Response | Annual |
| Configuration Engineers | Secure Coding, Secrets Management | Annual |
| Operations Engineers | Security Operations, Threat Detection | Annual |

### 11.2 Security Awareness Topics

- Password security and MFA
- Phishing recognition
- Social engineering
- Data handling and classification
- Incident reporting procedures
- Acceptable use policy
- Remote work security

### 11.3 Phishing Simulations

**Frequency:** Quarterly

**Process:**
1. Send simulated phishing emails to staff
2. Track who clicks links or submits credentials
3. Provide immediate feedback and training
4. Trend reporting to management
5. Additional training for repeat offenders

---

## 12. Third-Party Security

### 12.1 Vendor Security Assessment

For all third-party services (SendGrid, PagerDuty, etc.):

**Requirements:**
- SOC 2 Type II report (less than 12 months old)
- Vendor questionnaire completed
- Data Processing Agreement (DPA) signed
- Annual security assessment

### 12.2 API Key Management

**For Third-Party API Keys:**
- Store only in Vault (never in code or config files)
- Rotate every 180 days
- Use most restrictive permissions possible
- Monitor usage for anomalies
- Revoke immediately upon vendor contract termination

---

## 13. Appendix: Security Checklist

### Pre-Deployment Security Checklist

- [ ] All systems patched to current levels
- [ ] Strong passwords configured (14+ characters, complexity)
- [ ] MFA enabled for all admin accounts
- [ ] Firewall rules implemented and tested
- [ ] Encryption enabled (TLS, disk encryption, TDE)
- [ ] Audit logging enabled on all systems
- [ ] RBAC policies implemented
- [ ] Service accounts use key-based auth (no passwords)
- [ ] Secrets stored only in Vault
- [ ] Security monitoring configured
- [ ] IDS/IPS deployed
- [ ] Vulnerability scan completed, critical issues remediated
- [ ] Penetration test completed (for production)
- [ ] Security documentation reviewed and approved
- [ ] Incident response plan documented
- [ ] Backup and recovery tested
- [ ] DR plan documented and tested

---

## Document Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-17 | Adrian Johnson | Initial release |

---

**Document End**

