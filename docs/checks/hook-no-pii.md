# hook-no-pii

## What it catches

Personally Identifiable Information — Dutch BSN numbers, IBANs, phone numbers (06/+31 format).

## Why it matters

PII in source code violates GDPR and privacy regulations. Accidental commits of test data with real BSNs or phone numbers create compliance risk and can lead to significant fines. Once in git history, PII is hard to fully remove.

## Examples

```text
# Bad
bsn = "123456789"
iban = "NL91ABNA0417164300"
phone = "0612345678"

# Good
bsn = "000000000"          # test BSN
iban = "NL00TEST0000000000" # test IBAN
phone = "${USER_PHONE}"     # from env
```

## Override

- Global: `cpm hook --global --disable no-pii`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  no-pii = false
  ```

- Inline: add `cpm:ignore pii` comment on the line
- Per-pattern: add `disable bsn` in `.config/.pii-config`
- One commit: `git commit --no-verify`
