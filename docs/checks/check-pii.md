# check-pii

Detect PII (Personally Identifiable Information) in code and staged changes.

## Modes

- **Full scan**: `bash checks/universal/security/check-pii.sh`
- **Staged only**: `bash checks/universal/security/check-pii.sh --staged`

## Severity

Error — blocks commit/pipeline.

## Output

Clickable `file:line` references:

```text
⚠ pii: src/config.yaml:42  pattern '\b\+31[0-9]{9}\b'
   phone: "+31612345678"
```

## Suppress

- **Inline**: `cpm:ignore pii` on the line
- **File-level**: add to `.config/.piiignore`

## References

- Source: `checks/universal/security/check-pii.sh`
- Manual: [`docs/features/pii-detection.md`](../features/pii-detection.md)
