# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in cpm, please report it responsibly.

**Do NOT open a public issue.**

Instead, email: security@cpm.dev (or open a private security advisory on GitHub).

## What to include

- Description of the vulnerability
- Steps to reproduce
- Impact assessment
- Suggested fix (if any)

## Response timeline

- Acknowledgment: within 48 hours
- Assessment: within 7 days
- Fix: within 30 days for critical, 90 days for low severity

## Scope

- The `cpm` binary itself
- Shell scripts in `checks/` and `lib/`
- Configuration parsing (cpm.toml)
- Git hook installation

## Out of scope

- External tools invoked by cpm (semgrep, gitleaks, etc.) — report to their maintainers
- Findings in scanned repositories — those are the repo owner's responsibility
