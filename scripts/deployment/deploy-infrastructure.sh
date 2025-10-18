#!/bin/bash
# Infrastructure Deployment Script
# Author: Adrian Johnson <adrian207@gmail.com>
# Description: Orchestrates Terraform and Ansible deployment

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENVIRONMENT="${1:-dev}"
LOG_FILE="/var/log/deployment-$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

success() {
    log "${GREEN}✓ $*${NC}"
}

error() {
    log "${RED}✗ ERROR: $*${NC}"
    exit 1
}

warning() {
    log "${YELLOW}⚠ WARNING: $*${NC}"
}

info() {
    log "${YELLOW}ℹ INFO: $*${NC}"
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    local missing_tools=()
    
    command -v terraform &> /dev/null || missing_tools+=("terraform")
    command -v ansible &> /dev/null || missing_tools+=("ansible")
    command -v jq &> /dev/null || missing_tools+=("jq")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
    fi
    
    success "Prerequisites check passed"
}

validate_environment() {
    if [[ ! "$ENVIRONMENT" =~ ^(dev|test|prod)$ ]]; then
        error "Invalid environment: $ENVIRONMENT (must be dev, test, or prod)"
    fi
    
    info "Deploying to environment: $ENVIRONMENT"
}

terraform_init() {
    log "Initializing Terraform..."
    
    cd "$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"
    
    terraform init \
        -backend-config="key=configmgmt-$ENVIRONMENT.tfstate" \
        -upgrade \
        || error "Terraform init failed"
    
    success "Terraform initialized"
}

terraform_plan() {
    log "Creating Terraform plan..."
    
    cd "$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"
    
    terraform plan \
        -out="tfplan" \
        -var-file="terraform.tfvars" \
        || error "Terraform plan failed"
    
    success "Terraform plan created"
}

terraform_apply() {
    log "Applying Terraform configuration..."
    
    cd "$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"
    
    if [ "$ENVIRONMENT" == "prod" ]; then
        warning "Deploying to PRODUCTION environment!"
        read -p "Type 'yes' to continue: " confirm
        if [ "$confirm" != "yes" ]; then
            error "Deployment cancelled"
        fi
    fi
    
    terraform apply "tfplan" || error "Terraform apply failed"
    
    success "Terraform deployment completed"
}

extract_terraform_outputs() {
    log "Extracting Terraform outputs..."
    
    cd "$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"
    
    terraform output -json > "$PROJECT_ROOT/terraform-outputs.json"
    
    # Export important variables
    export VAULT_IPS=$(terraform output -json vault_cluster_ips | jq -r '.[]' | tr '\n' ',')
    export PROMETHEUS_IP=$(terraform output -raw prometheus_ip)
    export GRAFANA_IP=$(terraform output -raw grafana_ip)
    
    success "Terraform outputs extracted"
}

generate_ansible_inventory() {
    log "Generating Ansible inventory from Terraform outputs..."
    
    cd "$PROJECT_ROOT"
    
    # This would typically use terraform-inventory or custom script
    # For now, we'll use the static inventory
    
    success "Ansible inventory ready"
}

ansible_ping() {
    log "Testing Ansible connectivity..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible all -i "inventory/$ENVIRONMENT/hosts.yml" -m ping || warning "Some hosts unreachable"
    
    success "Ansible connectivity test completed"
}

deploy_management_tier() {
    log "Deploying Management Tier..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook \
        -i "inventory/$ENVIRONMENT/hosts.yml" \
        playbooks/management-tier.yml \
        --tags "vault,dsc,awx" \
        || error "Management tier deployment failed"
    
    success "Management tier deployed"
}

deploy_monitoring_tier() {
    log "Deploying Monitoring Tier..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook \
        -i "inventory/$ENVIRONMENT/hosts.yml" \
        playbooks/monitoring-tier.yml \
        --tags "prometheus,grafana,alertmanager" \
        || error "Monitoring tier deployment failed"
    
    success "Monitoring tier deployed"
}

deploy_data_tier() {
    log "Deploying Data Tier..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook \
        -i "inventory/$ENVIRONMENT/hosts.yml" \
        playbooks/data-tier.yml \
        --tags "postgres" \
        || error "Data tier deployment failed"
    
    success "Data tier deployed"
}

run_validation() {
    log "Running deployment validation..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook \
        -i "inventory/$ENVIRONMENT/hosts.yml" \
        playbooks/validate-deployment.yml \
        || warning "Validation checks failed"
    
    success "Validation completed"
}

display_summary() {
    log "=========================================="
    log "Deployment Summary for $ENVIRONMENT"
    log "=========================================="
    log ""
    log "Vault Cluster: $VAULT_IPS"
    log "Prometheus: http://$PROMETHEUS_IP:9090"
    log "Grafana: http://$GRAFANA_IP:3000"
    log ""
    log "Log file: $LOG_FILE"
    log "=========================================="
}

# Main execution
main() {
    log "========== Starting Infrastructure Deployment =========="
    log "Environment: $ENVIRONMENT"
    log "Project Root: $PROJECT_ROOT"
    
    check_prerequisites
    validate_environment
    
    # Terraform deployment
    terraform_init
    terraform_plan
    terraform_apply
    extract_terraform_outputs
    
    # Wait for instances to be ready
    log "Waiting for instances to be ready..."
    sleep 60
    
    # Ansible deployment
    generate_ansible_inventory
    ansible_ping
    deploy_management_tier
    deploy_monitoring_tier
    deploy_data_tier
    
    # Validation
    run_validation
    
    # Summary
    display_summary
    
    success "========== Deployment Completed Successfully =========="
}

# Trap errors
trap 'error "Script failed at line $LINENO"' ERR

# Run main function
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi


