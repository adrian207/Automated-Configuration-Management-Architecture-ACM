#!/bin/bash
# Script to update GitHub repository description and topics
# Run this script manually if you have proper GitHub permissions

REPO="adrian207/Automated-Configuration-Management-Architecture-ACM"
DESCRIPTION="Enterprise-grade configuration management platform delivering automated compliance, security, and operational efficiency across hybrid cloud environments using Terraform, Ansible, DSC, Vault, and Prometheus."

echo "🔧 Updating GitHub Repository Settings..."
echo ""
echo "Repository: $REPO"
echo ""

# Add description (requires repo admin permissions)
echo "📝 Setting repository description..."
gh repo edit "$REPO" --description "$DESCRIPTION" 2>&1

# Add topics/tags
echo ""
echo "🏷️  Adding repository topics..."
gh repo edit "$REPO" --add-topic "terraform" 2>&1
gh repo edit "$REPO" --add-topic "ansible" 2>&1
gh repo edit "$REPO" --add-topic "infrastructure-as-code" 2>&1
gh repo edit "$REPO" --add-topic "hashicorp-vault" 2>&1
gh repo edit "$REPO" --add-topic "prometheus" 2>&1
gh repo edit "$REPO" --add-topic "grafana" 2>&1
gh repo edit "$REPO" --add-topic "powershell-dsc" 2>&1
gh repo edit "$REPO" --add-topic "configuration-management" 2>&1
gh repo edit "$REPO" --add-topic "azure" 2>&1
gh repo edit "$REPO" --add-topic "aws" 2>&1
gh repo edit "$REPO" --add-topic "multi-cloud" 2>&1
gh repo edit "$REPO" --add-topic "devops" 2>&1
gh repo edit "$REPO" --add-topic "gitops" 2>&1
gh repo edit "$REPO" --add-topic "automation" 2>&1
gh repo edit "$REPO" --add-topic "security" 2>&1
gh repo edit "$REPO" --add-topic "compliance" 2>&1
gh repo edit "$REPO" --add-topic "zero-trust" 2>&1
gh repo edit "$REPO" --add-topic "monitoring" 2>&1
gh repo edit "$REPO" --add-topic "observability" 2>&1
gh repo edit "$REPO" --add-topic "enterprise" 2>&1

echo ""
echo "✅ Repository settings update complete!"
echo ""
echo "Verify at: https://github.com/$REPO"
