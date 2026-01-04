# CLAUDE.md - Terraform Project Guidelines

This document defines the rules and conventions for this Terraform repository. Follow these guidelines strictly to maintain project consistency.

---

## 📁 Project Structure

```
.
├── environments/           # Environment-specific configurations
│   ├── dev/
│   ├── staging/
│   └── prod/
├── modules/                # Reusable Terraform modules
│   └── <module-name>/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── README.md
├── scripts/                # Helper scripts
├── docs/                   # Additional documentation
├── .terraform.lock.hcl     # Dependency lock file (do not edit manually)
├── CLAUDE.md               # This file
└── README.md
```

---

## 🏷️ Naming Conventions

### Files
- Use lowercase with underscores: `my_module.tf`
- Standard file names per module/environment:
  - `main.tf` - Primary resources
  - `variables.tf` - Input variables
  - `outputs.tf` - Output values
  - `locals.tf` - Local values
  - `data.tf` - Data sources
  - `providers.tf` - Provider configurations
  - `versions.tf` - Terraform and provider version constraints
  - `backend.tf` - Backend configuration (environments only)

### Resources & Data Sources
- Use lowercase with underscores
- Prefix with the service/purpose: `aws_instance.web_server`
- Use descriptive, meaningful names: `this` or `main` for single resources in a module

### Variables
- Use lowercase with underscores: `instance_type`
- Prefix booleans with `enable_`, `is_`, or `has_`: `enable_monitoring`
- Use plural for lists/sets: `subnet_ids`, `security_group_ids`

### Outputs
- Use lowercase with underscores
- Mirror the resource attribute where possible: `instance_id`, `arn`

### Modules
- Use lowercase with hyphens for directory names: `vpc-network`
- Use lowercase with underscores in module blocks: `module "vpc_network"`

### Tags
- Always include these standard tags:
  ```hcl
  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    Owner       = var.owner
  }
  ```

---

## 📝 Code Style

### Formatting
- Run `terraform fmt -recursive` before committing
- Use 2 spaces for indentation (Terraform default)
- Align `=` signs in blocks for readability when practical
- One blank line between resource blocks
- No trailing whitespace

### Block Order (within a file)
1. `terraform` block
2. `provider` blocks
3. `locals` blocks
4. `data` sources
5. `resource` blocks
6. `module` blocks

### Attribute Order (within a block)
1. `count` or `for_each` (meta-arguments)
2. Required arguments (alphabetically)
3. Optional arguments (alphabetically)
4. `tags` (always last for resources)
5. `depends_on`, `lifecycle` (meta-arguments at end)

### Variable Definitions
Always include in this order:
```hcl
variable "example" {
  description = "Description of the variable"
  type        = string
  default     = "default_value"  # optional
  sensitive   = true             # if applicable
  
  validation {                   # if applicable
    condition     = length(var.example) > 0
    error_message = "Example cannot be empty."
  }
}
```

### Output Definitions
Always include:
```hcl
output "example" {
  description = "Description of the output"
  value       = resource.example.attribute
  sensitive   = true  # if applicable
}
```

---

## 🔒 Security Rules

### Never Do
- ❌ Never hardcode secrets, passwords, or API keys
- ❌ Never commit `.tfstate` files
- ❌ Never commit `.tfvars` files containing secrets
- ❌ Never use `*` for IAM permissions in production
- ❌ Never disable security features without documented justification

### Always Do
- ✅ Use variables or secrets manager for sensitive values
- ✅ Mark sensitive variables with `sensitive = true`
- ✅ Use least-privilege IAM policies
- ✅ Enable encryption at rest for storage resources
- ✅ Enable encryption in transit where applicable
- ✅ Use security groups with minimal required access
- ✅ Reference secrets from AWS Secrets Manager, HashiCorp Vault, or similar

### State Security
- Store state in remote backend (S3, GCS, Terraform Cloud, etc.)
- Enable state encryption
- Enable state locking
- Restrict access to state files

---

## 📦 Module Guidelines

### Module Design Principles
- Single responsibility: one module = one logical component
- Modules should be reusable across environments
- Avoid hardcoding environment-specific values
- Provide sensible defaults where appropriate
- Document all variables and outputs

### Required Module Files
Every module must have:
- `main.tf` - Core resources
- `variables.tf` - All input variables with descriptions
- `outputs.tf` - All outputs with descriptions
- `versions.tf` - Required Terraform and provider versions
- `README.md` - Usage documentation

### Module README Template
```markdown
# Module Name

Brief description of what this module does.

## Usage

\`\`\`hcl
module "example" {
  source = "../modules/example"
  
  variable1 = "value1"
  variable2 = "value2"
}
\`\`\`

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| variable1 | Description | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| output1 | Description |
```

---

## 🔄 Version Constraints

### Terraform Version
```hcl
terraform {
  required_version = ">= 1.5.0, < 2.0.0"
}
```

### Provider Versions
- Use pessimistic constraint operator: `~> 5.0` (allows 5.x but not 6.0)
- Pin to major version minimum in modules
- Be more specific in root modules/environments

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

---

## 🌍 Environment Management

### Environment Isolation
- Each environment has its own directory under `environments/`
- Each environment has its own state file
- Use workspaces sparingly; prefer directory separation

### Environment Variables
- Use `terraform.tfvars` for non-sensitive values
- Use environment variables or secrets manager for sensitive values
- Never commit sensitive `.tfvars` files

### Backend Configuration
```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "env/${var.environment}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

---

## ✅ Pre-Commit Checklist

Before committing any Terraform code:

1. [ ] Run `terraform fmt -recursive`
2. [ ] Run `terraform validate`
3. [ ] Run `terraform plan` and review changes
4. [ ] Ensure no secrets are hardcoded
5. [ ] Update documentation if needed
6. [ ] Add/update tests if applicable
7. [ ] Verify `.gitignore` excludes sensitive files

---

## 🚫 .gitignore Requirements

Ensure the repository includes:
```gitignore
# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
crash.log
crash.*.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Sensitive files
*.tfvars
!example.tfvars
.env
*.pem
*.key

# IDE
.idea/
.vscode/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
```

---

## 📚 Documentation Requirements

### Inline Comments
- Use `#` for single-line comments
- Explain non-obvious logic or workarounds
- Reference ticket numbers for temporary fixes: `# TODO: Remove after JIRA-123`

### Resource Documentation
```hcl
# This security group allows inbound HTTPS traffic from the load balancer
# and all outbound traffic for application dependencies
resource "aws_security_group" "app" {
  # ...
}
```

---

## 🧪 Testing Guidelines

### Validation
- Use `validation` blocks for input variables
- Use `precondition` and `postcondition` for resource validation

```hcl
variable "environment" {
  type        = string
  description = "Deployment environment"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
```

### Testing Tools (if applicable)
- Use `terraform test` for unit testing (Terraform 1.6+)
- Use Terratest for integration testing
- Use tfsec or Checkov for security scanning

---

## 🛠️ Common Patterns

### Conditional Resource Creation
```hcl
resource "aws_resource" "example" {
  count = var.create_resource ? 1 : 0
  # ...
}
```

### Dynamic Blocks
```hcl
dynamic "ingress" {
  for_each = var.ingress_rules
  content {
    from_port   = ingress.value.from_port
    to_port     = ingress.value.to_port
    protocol    = ingress.value.protocol
    cidr_blocks = ingress.value.cidr_blocks
  }
}
```

### For Each with Maps
```hcl
resource "aws_instance" "example" {
  for_each = var.instances
  
  ami           = each.value.ami
  instance_type = each.value.instance_type
  
  tags = {
    Name = each.key
  }
}
```

---

## ⚠️ Important Reminders

1. **Plan Before Apply**: Always run `terraform plan` and review before applying
2. **State is Sacred**: Never manually edit state files; use `terraform state` commands
3. **Imports**: Document all imported resources with comments
4. **Destroy with Caution**: Double-check the plan when destroying resources
5. **Lock Versions**: Commit `.terraform.lock.hcl` to ensure consistent provider versions

---

## 🔗 References

- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)