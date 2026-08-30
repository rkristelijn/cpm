# Research: IAM Golden Rules as Code — Static Analysis for Identity & Access Management

**Date:** 2026-08-28
**Status:** Research
**See also:** ADR-166 (rule engine extensions), IAC-SEC-016 (wildcard IAM)

## Context

101 golden rules for Identity & Access Management (IAM), Active Directory (AD), and authorization governance were provided as operational guidelines. The question: can cpm enforce these rules through static analysis of Infrastructure-as-Code (IaC) and configuration files?

## IaC Formats Where IAM is Defined

Identity and access configuration lives in these scannable file formats:

| Format | Extensions | What it defines | Provider |
|--------|-----------|----------------|----------|
| **Terraform (AWS IAM)** | `.tf` `.hcl` | IAM policies, roles, users, groups, SCPs | `hashicorp/aws` |
| **Terraform (Azure AD / Entra ID)** | `.tf` `.hcl` | Users, groups, conditional access policies, app registrations, RBAC | `hashicorp/azuread`, `hashicorp/azurerm` |
| **Terraform (GCP IAM)** | `.tf` `.hcl` | IAM bindings, service accounts, workload identity | `hashicorp/google` |
| **Terraform (AD on-prem)** | `.tf` `.hcl` | AD users, groups, OUs, GPOs | `hashicorp/ad` (experimental) |
| **CloudFormation** | `.yaml` `.json` | IAM policies, roles, groups, SAML providers | AWS native |
| **Pulumi** | `.ts` `.py` `.go` | Same as Terraform targets, programmatic | Multi-cloud |
| **Kubernetes RBAC** | `.yaml` | Roles, ClusterRoles, RoleBindings, ServiceAccounts | K8s native |
| **Azure Bicep** | `.bicep` | RBAC role assignments, managed identities, conditional access | Azure native |
| **PowerShell DSC** | `.ps1` `.psm1` | AD forest config, GPO, user/group management | Windows DSC |
| **Conditional Access JSON** | `.json` | MFA policies, location/device conditions, session controls | Entra ID export |
| **AWS SCPs** | `.json` | Organization-level permission boundaries | AWS Organizations |
| **Ansible** | `.yaml` `.yml` | AD users, groups, GPOs, LDAP config | `microsoft.ad` collection |
| **Group Policy (GPO exports)** | `.xml` | Password policy, lockout policy, audit settings | Windows GPMC export |

## Rule Mapping: 101 Rules → Scannable Patterns

### Phase 1: High-value, directly scannable (32 rules)

These rules map directly to regex patterns on known file formats.

#### AWS IAM (Terraform + CloudFormation)

| Rule # | Golden Rule | Detection | File pattern |
|--------|------------|-----------|-------------|
| 4 | Least Privilege | `Action: "*"` or `Resource: "*"` | `.tf` `.json` with `aws_iam` |
| 2 | No direct user→resource | `aws_iam_user_policy` (direct attach) | `.tf` |
| 6 | Separate admin accounts | `AdministratorAccess` on non-admin paths | `.tf` `.json` |
| 14 | Time-bound access | IAM role without `max_session_duration` | `.tf` |
| 81 | Tiered admin | No condition keys on admin policies | `.tf` `.json` |
| 89 | JIT access | `aws_iam_role` without STS session tags | `.tf` |

#### Azure AD / Entra ID (Terraform azuread provider)

| Rule # | Golden Rule | Detection | File pattern |
|--------|------------|-----------|-------------|
| 21 | MFA everywhere | `azuread_conditional_access_policy` without MFA grant | `.tf` |
| 22 | Phishing-resistant MFA | Conditional access allowing `password` auth strength | `.tf` |
| 33 | Conditional Access | No `azuread_conditional_access_policy` resources at all | `.tf` (file-absence) |
| 46 | Domain Admins empty | `azuread_group_member` adding to Global Admin role | `.tf` |
| 5 | No shared accounts | `azuread_user` without `employee_id` or unique identifier | `.tf` |
| 28 | Legacy auth disabled | Conditional access not blocking legacy protocols | `.tf` |

#### Kubernetes RBAC

| Rule # | Golden Rule | Detection | File pattern |
|--------|------------|-----------|-------------|
| 4 | Least Privilege | `ClusterRole` with `verbs: ["*"]` or `resources: ["*"]` | `.yaml` |
| 2 | No direct binding | `ClusterRoleBinding` bound to user instead of group | `.yaml` |
| 17 | Separate test/prod | ServiceAccount in `default` namespace | `.yaml` |
| 12 | No interactive login | ServiceAccount with `automountServiceAccountToken: true` | `.yaml` |

#### Terraform General

| Rule # | Golden Rule | Detection | File pattern |
|--------|------------|-----------|-------------|
| 26 | No plaintext passwords | `password =` or `secret =` with literal string | `.tf` |
| 11 | Managed Service Accounts | `aws_iam_user` for machine identity (should be role) | `.tf` |
| 83 | LAPS equivalent | No rotation on `aws_iam_access_key` | `.tf` |

#### PowerShell DSC / GPO exports

| Rule # | Golden Rule | Detection | File pattern |
|--------|------------|-----------|-------------|
| 24 | Long passphrases | `MinimumPasswordLength` < 14 | `.ps1` `.xml` |
| 30 | Account lockout | No `Account Lockout Threshold` configured | `.ps1` `.xml` |
| 23 | No periodic rotation | `MaximumPasswordAge` < 90 (forcing rotation) | `.ps1` `.xml` |
| 29 | AES Kerberos | `DES_CBC` or `RC4` in Kerberos config | `.ps1` `.xml` |
| 35 | Credential Guard | `LsaCfgFlags` not set to 1 | `.ps1` `.xml` |

### Phase 2: Cross-file / conditional checks (25 rules)

These need the phase 3 conditional engine (ADR-166) or cross-file analysis.

| Rule # | Golden Rule | Why cross-file |
|--------|------------|---------------|
| 3 | AGDLP principle | Need to trace user→global group→domain local→permission across files |
| 16 | Prevent role creep | Need to compare current vs previous state (git diff analysis) |
| 52 | Access reviews | Check if review mechanism exists anywhere in IaC + docs |
| 87 | IAM as source of truth | Check if HR integration exists (conditional: if users defined, must have source) |
| 9 | Offboarding process | Check if lifecycle automation exists |

### Phase 3: Governance / documentation rules (20 rules)

These check for the *existence* of documentation and processes — perfect for `file-absence` engine.

| Rule # | Golden Rule | Detection |
|--------|------------|-----------|
| 97 | Break-glass procedure | `file-absence`: no `BREAK-GLASS.md` or `emergency-access.md` |
| 100 | IAM policy doc | `file-absence`: no IAM policy document in `docs/` |
| 43 | Group descriptions | `absence` in `.tf`: `azuread_group` without `description` |
| 59 | Group ownership | `absence` in `.tf`: `azuread_group` without `owners` |

### Not statically scannable (24 rules)

These are runtime/operational checks that require live AD/cloud API access:

| Rules | Category | Why not scannable |
|-------|----------|------------------|
| 8, 10, 18 | Inactive/shadow accounts | Requires live directory query |
| 36 | SPN misuse / Kerberoasting | Requires runtime SPN enumeration |
| 73 | Time sync (NTP) | Runtime check |
| 74 | System State backup | Operational verification |
| 86 | Golden/Silver ticket | SIEM correlation |
| 99 | Vulnerability scan | Requires tools like PingCastle/BloodHound |

## Implementation Plan

### Phase 1: Terraform + K8s IAM rules (new rule files)

Create `rules/iam/` directory with ~30 rules targeting:

```text
rules/iam/
  IAM-001-wildcard-action.rule          # Rule 4: least privilege
  IAM-002-direct-user-policy.rule       # Rule 2: no user→resource
  IAM-003-no-mfa-condition.rule         # Rule 21: MFA everywhere
  IAM-004-admin-without-condition.rule  # Rule 81: tiered admin
  IAM-005-plaintext-password.rule       # Rule 26: no plaintext
  IAM-006-shared-account.rule           # Rule 5: no shared accounts
  IAM-007-wildcard-k8s-rbac.rule        # Rule 4: K8s least privilege
  IAM-008-user-binding.rule             # Rule 2: K8s group binding
  IAM-009-default-namespace-sa.rule     # Rule 17: test/prod separation
  IAM-010-no-session-duration.rule      # Rule 14: time-bound access
  ...
```

File types targeted: `.tf`, `.hcl`, `.yaml` (K8s), `.json` (CloudFormation/SCP/Conditional Access)

### Phase 2: GPO + PowerShell DSC rules

Create `rules/gpo/` targeting `.ps1`, `.psm1`, `.xml` GPO exports:

```text
rules/gpo/
  GPO-001-weak-password-length.rule     # Rule 24: min 14 chars
  GPO-002-forced-rotation.rule          # Rule 23: no forced rotation
  GPO-003-no-lockout.rule               # Rule 30: account lockout
  GPO-004-weak-kerberos.rule            # Rule 29: AES only
  GPO-005-no-credential-guard.rule      # Rule 35: Credential Guard
  ...
```

### Phase 3: Governance file-absence rules

Using the new `file-absence` engine:

```text
rules/governance/
  GOV-001-missing-iam-policy.rule       # Rule 100: IAM policy doc
  GOV-002-missing-break-glass.rule      # Rule 97: break-glass procedure
  GOV-003-missing-offboarding.rule      # Rule 9: offboarding process
  GOV-004-missing-access-review.rule    # Rule 52: access reviews
```

## Coverage Summary

| Category | Total rules | Scannable | Phase 1 | Phase 2 | Phase 3 | Not scannable |
|----------|------------|-----------|---------|---------|---------|--------------|
| Users & Accounts (1-20) | 20 | 14 | 8 | 2 | 4 | 6 |
| Passwords & Auth (21-40) | 20 | 15 | 7 | 5 | 3 | 5 |
| Groups & OUs (41-60) | 20 | 12 | 6 | 3 | 3 | 8 |
| AD Architecture & GPO (61-80) | 20 | 8 | 3 | 5 | 0 | 12 |
| Security & Governance (81-101) | 21 | 12 | 6 | 2 | 4 | 9 |
| **Total** | **101** | **61** | **30** | **17** | **14** | **40** |

60% of the 101 golden rules can be enforced through static analysis of IaC files. The remaining 40% require runtime checks against live directory services.

## Compliance Mapping

These IAM rules map to existing compliance frameworks cpm already tracks:

| Framework | Relevant controls |
|-----------|------------------|
| ISO 27001 | A.9 (Access Control) — all 101 rules |
| NIST 800-53 | AC-2 (Account Management), AC-3 (Access Enforcement), AC-6 (Least Privilege) |
| SOC 2 | CC6.1 (Logical Access), CC6.2 (Authentication), CC6.3 (Authorization) |
| PCI DSS | Req 7 (Restrict Access), Req 8 (Identify & Authenticate) |
| NIS2 | Art. 21(2)(i) — access control policies |
| DORA | Art. 9 — ICT access management |

## Next Steps

1. Create `rules/iam/` with phase 1 rules (Terraform + K8s)
2. Test against cpm-eval IAM fixtures
3. Add GPO/DSC rules in phase 2
4. Add governance file-absence rules in phase 3
5. Map rules to compliance framework IDs for `cpm findings --compliance` output
