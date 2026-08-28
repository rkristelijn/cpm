# Lab Checks Gap Analysis — August 2026

> Cross-reference of check scripts in private repos against cpm's built-in checks.
> 68 unique checks analyzed across 4 sources.

## Summary

| Status | Count | Description |
|--------|-------|-------------|
| ✅ Already in cpm | 33 | Full equivalent exists |
| 🟡 Generalizable gap | 17 | Should be added to cpm |
| ⚪ Domain-specific | 18 | Org-internal, not for cpm |

## Sources analyzed

1. **Security tooling AI review** (19 checks) — `tech-services/security/security-tooling/src/tools/ai-review/checks/`
2. **Standard pipeline components** (34 templates) — `platform/devops/standard-pipelines/.../templates/`
3. **Per-repo .ci audit scripts** (6 unique) — `agility/ui/.ci/scripts/`, duplicated across repos
4. **Other standalone scripts** (11) — Various repos

## Gaps addressed (8 checks implemented)

| Check | Rules | Based on | File |
|-------|-------|----------|------|
| README structure | 7 | readme-audit/main-script.sh | check-readme-structure.sh |
| Shell strict mode | 3 | check-strict-mode.sh | check-shell-strict.sh |
| Curl safety | 3 | check-curl-timeout.sh | check-curl-safety.sh |
| Dead scripts | 1 | check-dead-scripts.sh | check-dead-scripts.sh |
| Markdown quality | 3 | check-code-block-lang.sh | check-markdown-quality.sh |
| Shell help text | 1 | check-help-text.sh | check-shell-help.sh |
| BusyBox compatibility | 10 | check-busybox-compat.sh | check-busybox-compat.sh |
| Orphan docs | 1 | check-orphan-docs.sh | check-orphan-docs.sh |
| **Total** | **29** | | |

## Remaining gaps (9 checks not yet implemented)

| # | Gap | Priority | Reason not implemented |
|---|-----|----------|------------------------|
| 1 | .NET vulnerability audit | Medium | Requires dotnet CLI, new language directory |
| 2 | .NET license compliance | Medium | Same — new checks/dotnet/ needed |
| 3 | .NET outdated packages | Medium | Same |
| 4 | .NET runtime detection | Medium | Same |
| 5 | .NET security analysis | Medium | Same |
| 6 | Hardcoded values in scripts | Low | Partially covered by check-magic-literals.sh |
| 7 | Docker image scanning | Low | Runtime dependency (Docker Scout/Trivy), high effort |
| 8 | DAST (ZAP) | Low | Requires running application, not static analysis |
| 9 | Go checks directory | Low | Go support claimed in README but no checks/go/ |

## Already covered by cpm (33 checks)

| Lab check | cpm equivalent |
|-----------|----------------|
| shellcheck | checks/universal/quality/check-shellcheck.sh |
| dead links | checks/universal/docs/check-dead-links.sh |
| Dutch detection | checks/universal/check-dutch.sh |
| dangerous shell | checks/universal/security/check-dangerous-shell.sh |
| PII detection | checks/universal/security/check-pii.sh |
| secret scanning | checks/universal/security/check-secrets-fast.sh |
| Unicode/trojan source | checks/universal/check-unicode.sh |
| dir size / file size | checks/universal/quality/check-file-size.sh |
| script length | checks/universal/quality/check-file-size.sh |
| code security (Semgrep) | checks/universal/security/check-sast.sh |
| Java audit | checks/java/check-java.sh |
| Java license | checks/java/check-java.sh |
| Java outdated | checks/java/check-java.sh |
| Java runtime | checks/universal/deps/check-runtime-eol.sh |
| Java security | checks/java/check-java.sh |
| PHP audit | checks/php/check-php-audit.sh |
| PHP license | checks/php/check-php-license.sh |
| PHP outdated | checks/php/check-php.sh |
| PHP runtime | checks/universal/deps/check-runtime-eol.sh |
| PHP security | checks/php/check-php.sh |
| TypeScript audit | checks/javascript/check-ts-audit.sh |
| TypeScript license | checks/javascript/check-ts-license.sh |
| TypeScript outdated | checks/javascript/check-ts-outdated.sh |
| TypeScript runtime | checks/javascript/check-runtime-pin.sh |
| TypeScript security | checks/universal/security/check-sast.sh |
| Terraform lint | checks/terraform/check-tf-lint.sh |
| Terraform security | checks/terraform/check-tf-security.sh |
| Terraform versions | checks/terraform/check-tf-patterns.sh |
| TODO scanning | checks/universal/quality/check-todo.sh |
| YAML lint | checks/universal/lint-yaml.sh |
| Lines of code | checks/universal/quality/check-file-size.sh |
| SBOM | checks/universal/security/check-sbom.sh |
| Secrets detection | checks/universal/security/check-secrets-fast.sh |

## Domain-specific checks (not for cpm)

These 18 checks are specific to the organization's infrastructure, CI framework, or regulatory requirements:

- GitLab CI pipeline structure audit (org's standard-pipelines framework)
- CI component consistency validation
- CI component MR-specific checks
- Port catalog integration (Port.io API push)
- Credential source validation (org's credential.sh pattern)
- Repo discoverability (security-tooling structure)
- Folder structure validation (security-tooling conventions)
- README exists in specific subdirs (org convention)
- ISO 27001 control claims verification
- Security standard chapter structure
- Fair use workstation audit
- Terraform plan safety (GitLab project management)
- Domain squatting monitor (org domains)
- ArgoCD token expiry monitor
- APS IaC compliance (org AWS conventions)
- lint-credentials (org's keychain abstraction)
- Pipeline audit (org's ci-cd-components)
- check-pipeline (org's GitLab CI conventions)
