# hook-no-pii

## What it catches

Personally Identifiable Information — 13 regex patterns covering Dutch, UK, US, and international PII formats.

## Pattern table

| Name | What | Regex |
|------|------|-------|
| `bsn` | Dutch citizen service number (9 digits) | `\b[0-9]{9}\b` |
| `iban` | IBAN (NL-focused, backward compat) | `\b[A-Z]{2}[0-9]{2}[A-Z0-9]{4}[0-9]{7}([A-Z0-9]{0,16})\b` |
| `phone-nl` | Dutch mobile (06...) | `\b06[0-9]{8}\b` |
| `phone-intl` | Dutch international (+31...) | `\b\+31[0-9]{9}\b` |
| `nl-postcode` | Dutch postcode (1234 AB) | `\b[1-9][0-9]{3}\s?[A-Z]{2}\b` |
| `nl-kenteken` | Dutch license plate | `\b[A-Z]{2}-[0-9]{3}-[A-Z]\b\|\b[0-9]-[A-Z]{3}-[0-9]{2}\b` |
| `uk-nino` | UK National Insurance Number | `\b[A-Z]{2}[0-9]{6}[A-Z]\b` |
| `uk-phone` | UK phone (+44...) | `\b\+44[0-9]{10}\b` |
| `us-ssn` | US Social Security Number | `\b[0-9]{3}-[0-9]{2}-[0-9]{4}\b` |
| `us-phone` | US phone (+1...) | `\b\+1[0-9]{10}\b` |
| `ipv4` | IPv4 address (private ranges excluded) | `\b[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\b` |
| `creditcard` | Credit card number (13-19 digits) | `\b[0-9]{13,19}\b` |
| `eu-iban` | EU-wide IBAN (broader than `iban`) | `\b[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}\b` |

### Notes

- **ipv4**: Private/loopback ranges are filtered out automatically (127.0.0.1, 0.0.0.0, 10.x, 172.16-31.x, 192.168.x).
- **creditcard**: Broad pattern — catches any 13-19 digit number. Luhn validation would reduce false positives but is too slow for a pre-commit hook. Use `disable creditcard` in `.config/.pii-config` if noisy.
- **eu-iban**: Broader than the existing `iban` pattern. The original stays for backward compatibility. This catches non-NL IBANs (DE, FR, BE, etc.).

## Why it matters

PII in source code violates GDPR and privacy regulations. Accidental commits of test data with real BSNs, SSNs, or phone numbers create compliance risk and can lead to significant fines. Once in git history, PII is hard to fully remove.

## Examples

```text
# Bad
bsn = "123456789"
iban = "NL91ABNA0417164300"
phone = "0612345678"
ssn = "123-45-6789"
server = "203.0.113.42"

# Good
bsn = "000000000"          # test BSN
iban = "NL00TEST0000000000" # test IBAN
phone = "${USER_PHONE}"     # from env
ssn = "000-00-0000"         # test SSN
server = "${DB_HOST}"       # from env
```

## Override

- Global: `cpm hook --global --disable no-pii`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  no-pii = false
  ```

- Inline: add `cpm:ignore pii` comment on the line
- Per-pattern: add `disable bsn` (or `disable creditcard`, etc.) in `.config/.pii-config`
- One commit: `git commit --no-verify`
