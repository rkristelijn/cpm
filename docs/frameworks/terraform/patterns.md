# Terraform Patterns — 15 Checkable Best Practices

This document defines 15 checkable Terraform patterns for code quality and operational excellence.

## 1. Remote State Configuration

**Pattern:** Terraform state must be stored remotely with proper backend configuration.

**Why:** Local state files are not safe for teams. Remote state enables locking, versioning, and collaboration.

**Check:** `backend` block exists in `main.tf` or a dedicated `backend.tf` file.

```hcl
# Correct
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/network/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

**Fix:** Run `terraform init -migrate-state` to migrate local state to remote backend.

---

## 2. State Locking

**Pattern:** State locking must be enabled to prevent concurrent operations.

**Why:** Without locking, multiple team members can corrupt state by running `terraform apply` simultaneously.

**Check:** DynamoDB table (AWS) or equivalent locking mechanism is configured in backend.

```hcl
# S3 backend with locking
terraform {
  backend "s3" {
    # ... other settings
    dynamodb_table = "terraform-locks"
  }
}
```

**Fix:** Add `dynamodb_table` to backend configuration and create the table.

---

## 3. Provider Version Pins

**Pattern:** Provider versions must be pinned to avoid breaking changes from automatic upgrades.

**Why:** Unpinned providers can upgrade silently, causing unexpected behavior or failures.

**Check:** `required_providers` block specifies version constraints.

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

**Fix:** Add version constraints to `required_providers` block.

---

## 4. Module Structure

**Pattern:** Root module should delegate resource creation to child modules for reusability.

**Why:** Modules promote consistency and reduce duplication across environments.

**Check:** Resources are grouped into modules or the configuration uses external modules.

```hcl
# Root module using child modules
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  # ... inputs
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"
  # ... inputs
}
```

**Fix:** Refactor resources into modules using `module` blocks.

---

## 5. Variable Validation

**Pattern:** Input variables must have validation blocks to catch invalid values early.

**Why:** Validation provides immediate feedback on invalid inputs during `terraform plan`.

**Check:** Variables with `validation` blocks or type constraints.

```hcl
variable "environment" {
  type        = string
  description = "Deployment environment"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "instance_count" {
  type        = number
  description = "Number of instances"

  validation {
    condition     = var.instance_count > 0 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}
```

**Fix:** Add `validation` blocks to variables with constraints.

---

## 6. Output Descriptions

**Pattern:** All outputs must have descriptions explaining their purpose and values.

**Why:** Outputs are often used by other teams or CI/CD pipelines; descriptions provide context.

**Check:** Every `output` block has a `description` argument.

```hcl
output "vpc_id" {
  description = "The ID of the VPC created"
  value       = module.vpc.vpc_id
}

output "load_balancer_dns" {
  description = "DNS name of the application load balancer"
  value       = aws_lb.alb.dns_name
}
```

**Fix:** Add `description` to all output blocks.

---

## 7. No Hardcoded Values

**Pattern:** Sensitive or environment-specific values must not be hardcoded.

**Why:** Hardcoded values make configurations non-portable and risk credential exposure.

**Check:** No literal strings for credentials, ARNs, or resource IDs.

```hcl
# Incorrect — hardcoded
provider "aws" {
  access_key = "AKIAIOSFODNN7EXAMPLE"
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}

# Correct — using variables
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}
```

**Fix:** Replace hardcoded values with `var.*` references.

---

## 8. Lifecycle Rules

**Pattern:** Resources with `lifecycle` blocks should have explicit create_before_destroy or prevent_destroy settings.

**Why:** Lifecycle rules prevent accidental destruction and ensure zero-downtime deployments.

**Check:** Resources with `lifecycle { create_before_destroy = true }` or `prevent_destroy = true`.

```hcl
resource "aws_db_instance" "database" {
  # ... other arguments

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_s3_bucket" "important" {
  # ... other arguments

  lifecycle {
    prevent_destroy = true
  }
}
```

**Fix:** Add `lifecycle` blocks to critical resources.

---

## 9. Data Sources vs Resources

**Pattern:** Use `data` sources for reading existing resources; use `resource` blocks for creating new ones.

**Why:** Confusing data sources with resources leads to unintended modifications or plan errors.

**Check:** No `resource` blocks that only read state without creating infrastructure.

```hcl
# Data source — reading existing
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Resource — creating new
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
}
```

**Fix:** Use `data` blocks for lookups, `resource` blocks for creation.

---

## 10. Sensitive Variables

**Pattern:** Variables containing secrets must be marked as `sensitive`.

**Why:** Prevents sensitive values from appearing in logs, plans, and state output.

**Check:** Variables with `sensitive = true` for credentials, keys, and secrets.

```hcl
variable "db_password" {
  type        = string
  description = "Database administrator password"
  sensitive   = true
}

variable "api_key" {
  type        = string
  description = "Third-party API key"
  sensitive   = true
}
```

**Fix:** Add `sensitive = true` to variable definitions containing secrets.

---

## 11. Remote State Data Sources

**Pattern:** Use `terraform_remote_state` to share state between configurations.

**Why:** Enables loose coupling between infrastructure components managed in separate state files.

**Check:** `terraform_remote_state` data sources for cross-state references.

```hcl
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "terraform-state"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

# Use the state data
resource "aws_instance" "web" {
  subnet_id = data.terraform_remote_state.network.outputs.subnet_id
}
```

**Fix:** Use `terraform_remote_state` for cross-configuration references.

---

## 12. Empty String Handling

**Pattern:** Use `coalesce` or `try` functions to handle optional values safely.

**Why:** Prevents errors when optional variables are null or empty.

**Check:** Use of `coalesce()`, `try()`, or conditional expressions for optional values.

```hcl
# Using coalesce for optional tags
locals {
  environment = coalesce(var.environment, "unknown")
}

# Using try for dynamic lookups
resource "aws_security_group_rule" "example" {
  # ... other arguments
  source_security_group_id = try(data.aws_security_group.external.id, null)
}
```

**Fix:** Wrap optional values with `coalesce()` or `try()`.

---

## 13. Count and For_each Meta-Arguments

**Pattern:** Use `count` or `for_each` for creating multiple similar resources.

**Why:** Reduces duplication and enables dynamic resource creation based on variables.

**Check:** Resources using `count` or `for_each` for repeated infrastructure.

```hcl
# Using count for multiple instances
resource "aws_instance" "server" {
  count         = var.instance_count
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = element(var.subnet_ids, count.index)
}

# Using for_each for multiple security group rules
resource "aws_security_group_rule" "http" {
  for_each          = toset(["80", "443"])
  description       = "Port ${each.value}"
  type              = "ingress"
  from_port         = each.value
  to_port           = each.value
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web.id
}
```

**Fix:** Refactor repeated resources into `count` or `for_each` blocks.

---

## 14. Prevent Sensitive Data in State

**Pattern:** Use `sensitive = true` on outputs that expose sensitive values.

**Why:** State file contains all output values; sensitive outputs must be masked.

**Check:** Outputs with `sensitive = true` for passwords, keys, and tokens.

```hcl
output "database_password" {
  description = "The generated database password"
  value       = random_password.db.result
  sensitive   = true
}

output "api_secret" {
  description = "Third-party API secret"
  value       = var.api_secret
  sensitive   = true
}
```

**Fix:** Add `sensitive = true` to outputs containing secrets.

---

## 15. Workspaces for Environment Isolation

**Pattern:** Use Terraform workspaces for environment-specific state isolation.

**Why:** Workspaces enable single-configuration multi-environment deployments with isolated state.

**Check:** Configuration uses `terraform.workspace` for environment-specific values.

```hcl
# Using workspace for environment-specific values
locals {
  environment = terraform.workspace

  # Environment-specific instance sizes
  instance_type = lookup({
    default = "t3.micro"
    dev     = "t3.micro"
    prod    = "t3.large"
  }, terraform.workspace, "t3.micro")
}

# Environment-specific tags
tags = {
  Environment = terraform.workspace
  ManagedBy   = "Terraform"
}
```

**Fix:** Use `terraform.workspace` and workspace-specific variable maps.

---

## Summary Table

| # | Pattern | Category | Severity |
|---|---------|----------|----------|
| 1 | Remote State | State Management | Error |
| 2 | State Locking | State Management | Error |
| 3 | Provider Version Pins | Dependencies | Warning |
| 4 | Module Structure | Architecture | Warning |
| 5 | Variable Validation | Input Validation | Warning |
| 6 | Output Descriptions | Documentation | Info |
| 7 | No Hardcoded Values | Security | Error |
| 8 | Lifecycle Rules | Reliability | Warning |
| 9 | Data Sources vs Resources | Correctness | Error |
| 10 | Sensitive Variables | Security | Warning |
| 11 | Remote State Data Sources | Architecture | Info |
| 12 | Empty String Handling | Robustness | Info |
| 13 | Count/For_each | Efficiency | Info |
| 14 | Prevent Sensitive in State | Security | Error |
| 15 | Workspaces | Operations | Info |

## References

- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Terraform Style Conventions](https://developer.hashicorp.com/terraform/language/style)
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
