# Automated Configuration Management Architecture (ACM)

Terraform and Ansible that build a configuration management platform in Azure: a HashiCorp Vault cluster for secrets, PowerShell DSC pull servers for Windows configuration, AWX for running Ansible, Prometheus, Grafana and Alertmanager for monitoring, and a replicated PostgreSQL pair. Managed Linux and Windows nodes are enrolled into it. Dev and prod environments share one Terraform module and one set of roles.

## Architecture

| Tier | Hosts (dev IPs; prod uses 10.20.x) | What runs there |
|---|---|---|
| Management | `vault-01..03` (10.10.10.20-22) | Vault 1.15 cluster with integrated Raft storage |
| | `dsc-pull-01..02` (10.10.10.30-31, Windows Server 2022) | DSC pull service publishing `WindowsBase` and `WebServer` |
| | `awx-01` (10.10.10.40) | AWX on single-node k3s through the AWX Operator (web UI on port 30080) |
| Monitoring | `prometheus-01` (10.10.20.10) | Prometheus 2.48 with alert rules |
| | `grafana-01` (10.10.20.20) | Grafana 10.2, Prometheus datasource and dashboards provisioned |
| | `alertmanager-01` (10.10.20.30) | Alertmanager with email and webhook routing |
| Data | `postgres-01` (primary), `postgres-02` (replica) (10.10.30.10-11) | PostgreSQL 15 with streaming replication over a slot; Grafana's database |
| Nodes | Optional RHEL 9 and Windows Server 2022 VMs (10.10.100.0/22) | Node Exporter or windows_exporter; Windows nodes pull their DSC configuration |

Every Linux host runs Node Exporter and every Windows host windows_exporter. PostgreSQL hosts run postgres_exporter, and Prometheus also scrapes Vault's metrics endpoint. None of the VMs has a public IP, so run Terraform's output steps and Ansible from a machine inside the VNet, or over a VPN or Azure Bastion.

## Repository layout

```
terraform/
  modules/azure/          Network, VMs, Key Vault, optional backups; tests/ has plan tests with a mocked provider
  environments/dev, prod  Environment settings (address space, sizes, backups on in prod)
ansible/
  inventory/dev, prod     Hosts and groups matching the Terraform IPs; group_vars/all/vaulted.yml.example
  playbooks/              site.yml and the tier playbooks below
  roles/                  common, node_exporter, vault, docker, awx, prometheus, grafana, alertmanager, postgresql
dsc/
  configurations/         WindowsBase.ps1, WebServer.ps1
  Publish-DscConfigurations.ps1, Set-DscPullClient.ps1
monitoring/               Grafana dashboard JSON and a reference Prometheus config
scripts/deployment/       deploy-infrastructure.sh: Terraform then Ansible for one environment
docs/                     Design, implementation, operations, security, DR, test and monitoring documents
```

`ansible/playbooks/site.yml` runs, in order:

1. `management-tier.yml`: Vault install, initialisation and unseal; DSC pull servers, including publishing the configurations and resource modules; AWX
2. `data-tier.yml`: PostgreSQL primary, then replicas
3. `monitoring-tier.yml`: Prometheus, Grafana, Alertmanager
4. `configure-linux-nodes.yml`, `configure-windows-nodes.yml`: enrol managed nodes (Windows nodes register with the pull server)
5. `deploy-monitoring-agents.yml`: exporters and Prometheus file-based targets
6. `validate-deployment.yml`: read-only health checks of every service

## Requirements

- Azure subscription; Terraform 1.5+ (1.7+ to run the module tests) and the Azure CLI
- An Azure Storage account for Terraform state (`rg-terraform-state` / `stterraformstate` in the environment configs; change to yours)
- Ansible with the collections in `ansible/requirements.yml` (`ansible-galaxy collection install -r ansible/requirements.yml`)
- An SSH key pair; a password for the Windows local administrator

## Deploy

```bash
git clone https://github.com/adrian207/Automated-Configuration-Management-Architecture-ACM.git
cd Automated-Configuration-Management-Architecture-ACM

# 1. Infrastructure
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars      # set windows_admin_password
terraform init -backend-config="key=configmgmt-dev.tfstate"
terraform apply
terraform output

# 2. Secrets for Ansible
cd ../../../ansible
cp inventory/dev/group_vars/all/vaulted.yml.example inventory/dev/group_vars/all/vaulted.yml
# set the passwords, the DSC registration key (any GUID) and the same windows_admin_password
ansible-vault encrypt inventory/dev/group_vars/all/vaulted.yml

# 3. Configuration (dev inventory is the default; use -i inventory/prod/hosts.yml for prod)
ansible-galaxy collection install -r requirements.yml
ansible-playbook playbooks/site.yml --ask-vault-pass
```

`scripts/deployment/deploy-infrastructure.sh dev` runs the same Terraform and Ansible steps in sequence. To add managed nodes, set `linux_node_count` or `windows_node_count` in the environment's `main.tf`, apply, and list the nodes with their IPs under `linux_nodes` / `windows_nodes` in the inventory.

After deployment:

- **Vault:** the unseal keys and root token are saved on `vault-01` in `/opt/vault/vault-init-keys.json` (root only). Move them to their key holders and delete the file, or switch to auto-unseal with Azure Key Vault.
- **AWX:** `http://10.10.10.40:30080`, user `admin`. The password is your `awx_admin_password`, or the one the role prints how to read.
- **Grafana:** `http://10.10.20.20:3000`, user `admin`, password `grafana_admin_password`.

## CI

- **`ansible-lint.yml`:** runs yamllint, ansible-lint and a syntax check when `ansible/` changes.
- **`terraform-deploy.yml`:**
  - On every push or pull request that touches `terraform/`: format check, validation of both environments, the module plan tests, and tfsec and Checkov scans.
  - A plan for `dev` (`develop` branch and pull requests) or `prod` (`main`).
  - **Applies run only when started by hand:** Actions → Terraform Deploy → Run workflow, choosing dev or prod. Prod uses the `prod-approval` environment.
  - Repository secrets needed: `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_SUBSCRIPTION_ID`, `AZURE_TENANT_ID`, `WINDOWS_ADMIN_PASSWORD`, `SSH_PUBLIC_KEY`, and optionally `SLACK_WEBHOOK`.

## Tests

| Check | Command | What it covers |
|---|---|---|
| Terraform plan tests | `cd terraform/modules/azure && terraform init -backend=false && terraform test` | VM counts, static IPs matching the inventory, backup coverage, Windows password requirement |
| Ansible lint | `cd ansible && ansible-lint` | All playbooks and roles (production profile) |
| Syntax | `ansible-playbook -i inventory/prod/hosts.yml --syntax-check playbooks/site.yml` | Both inventories |

Configuration files were also rendered from the dev inventory and checked with the real tools:

- `promtool` 2.48 for the Prometheus config and rules, `amtool` 0.27 for Alertmanager.
- **Vault 1.15.4:** started with the generated config, then initialised and unsealed through the same API calls the playbook makes.
- **PostgreSQL:** a primary with the generated settings, a replica cloned with the role's `pg_basebackup` command (streaming confirmed), and the exporter's TLS login.

## Status and limitations

- **Not yet deployed end to end.** The roles, playbooks and Terraform have been checked as described above, but the whole platform has not been applied to Azure and run from start to finish.
- **Lab defaults to change for production:**
  - Vault listens over plain HTTP inside the VNet (`vault_tls_disable: true`); set it to false and provide certificates.
  - The DSC pull server uses HTTP on port 8080.
  - PostgreSQL uses self-signed certificates.
  - Windows VMs use a local administrator with NTLM; join them to a domain to use Kerberos.
- AWX runs on a single k3s node and holds its own PostgreSQL inside k3s, separate from the data tier.
- The documents in `docs/` describe the target design and operating procedures, written before this code; check a feature against the code before relying on it.

## License

MIT. See [LICENSE](LICENSE).

## Author

Adrian Johnson · [github.com/adrian207](https://github.com/adrian207)
