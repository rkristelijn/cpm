# ADR-150: Paranoia Mode — Encrypted Git Push with Obfuscated Filenames

**Status**: Proposed  
**Date**: 2026-07-04  
**Context**: Storing sensitive personal notes (career, health, legal) in a remote git repo

## Problem

Users want to store sensitive content in a git repository for:

- Version control and history
- Backup via remote (GitLab, GitHub)
- Cross-device sync

But the remote repository is not fully trusted:

- Work GitLab repos may be auditable by IT admins
- GitHub private repos can be subpoenaed or breached
- Filenames alone leak information (e.g., `career/burnout/therapist-notes.md`)

## Decision

Implement a "paranoia mode" git filter that:

1. **Encrypts file contents** before commit/push (GPG or age)
2. **Obfuscates filenames** in the remote (SHA-256 hash or random UUID mapping)
3. **Works transparently** locally (clean/smudge filters)
4. **Stores the mapping** locally only (never pushed)

## Architecture

```text
LOCAL (cleartext)                    REMOTE (encrypted)
─────────────────                   ────────────────────
career/burnout/notes.md       →     data/a3f8b2c1.enc
career/burnout/timeline.md    →     data/7d4e9f01.enc
legal/uber-zaak/claim.md      →     data/e2c8a4b7.enc
.paranoia/                          (never pushed)
├── manifest.json.gpg               ← filename→hash mapping
├── identity.age                    ← private key
└── config.toml                     ← settings
```

### Git Filter (clean/smudge)

```toml
# .paranoia/config.toml
[encryption]
method = "age"              # or "gpg"
recipient = "age1..."       # public key (safe to commit)

[obfuscation]
method = "sha256"           # or "uuid4" for random names
salt = "local-only-salt"    # never pushed, makes hashes irreversible
prefix = "data/"            # remote directory

[remote]
branch = "encrypted"        # push encrypted branch
manifest = "local-only"     # manifest never pushed
```

### Workflow

```bash
# Setup
paranoia init                 # Generate keypair, create .paranoia/
paranoia add career/          # Mark directory for encryption

# Normal work (transparent)
vim career/burnout/notes.md   # Edit in cleartext
git add career/               # Clean filter encrypts + renames
git commit -m "update"        # Commit contains encrypted blobs

# What gets pushed
git push origin encrypted     # Remote sees: data/a3f8b2c1.enc, data/7d4e9f01.enc

# Clone on new device
git clone <repo>              # Get encrypted blobs
paranoia unlock               # Enter passphrase → decrypt manifest → restore filenames
```

### Key Design Choices

| Choice | Rationale |
|---|---|
| **age over GPG** | Simpler, no keyring needed, designed for file encryption |
| **Filename obfuscation** | Filenames are metadata — "burnout.md" leaks info without content |
| **Local manifest** | Mapping file→hash is itself PII; store only locally |
| **Salt-based hashing** | Same file always gets same hash (deterministic for git), but salt prevents rainbow tables |
| **Separate branch** | Keep plaintext branch local-only, push only encrypted branch |

## Alternatives Considered

| Alternative | Rejected because |
|---|---|
| **git-crypt** | Encrypts content but NOT filenames |
| **git-remote-gcrypt** | Encrypts entire repo but no selective per-dir encryption |
| **SOPS** | Designed for config values, not full files |
| **EncFS/gocryptfs** | OS-level; doesn't integrate with git branching |
| **Manual GPG per file** | No automation, breaks git diff/log |

## Implementation Plan

### Phase 1: Core (MVP)

- [ ] `paranoia init` — create config + keypair
- [ ] `paranoia add <path>` — mark files for encryption
- [ ] Git clean filter: encrypt + rename on `git add`
- [ ] Git smudge filter: decrypt + restore on `git checkout`
- [ ] Local manifest (JSON, encrypted with same key)

### Phase 2: Usability

- [ ] `paranoia status` — show what's encrypted
- [ ] `paranoia diff` — diff cleartext even though remote has encrypted
- [ ] `paranoia unlock` — restore on new clone
- [ ] `paranoia rotate` — re-encrypt with new key

### Phase 3: Integration

- [ ] cpm hook: prevent pushing plaintext branch accidentally
- [ ] cpm check: verify no cleartext leaks to remote branch
- [ ] Backup key to macOS Keychain / password manager

## Security Model

| Threat | Mitigation |
|---|---|
| Remote admin reads files | Content encrypted with age/GPG |
| Remote admin reads filenames | Filenames are hashed (salt local-only) |
| Key loss | Backup key in password manager / Keychain |
| Key compromise | `paranoia rotate` re-encrypts everything |
| Accidental plaintext push | Pre-push hook blocks plaintext branch |
| Attacker has repo + brute-force | age uses scrypt KDF; salt makes filename hashes useless |

## Existing Tools Analysis

| Tool | Content encryption | Filename obfuscation | Git integration | Notes |
|---|---|---|---|---|
| **git-crypt** | ✅ AES-256 | ❌ Cleartext names | ✅ Native filters | Most popular, but filenames leak |
| **git-remote-gcrypt** | ✅ GPG full repo | ✅ Everything encrypted | ⚠️ Special remote | All-or-nothing, complex setup |
| **transcrypt** | ✅ OpenSSL | ❌ Cleartext names | ✅ Clean/smudge | Simple but same filename problem |
| **age + custom** | ✅ age | ✅ Custom | 🔨 Build required | Our approach: best of both |

## References

- [age encryption](https://github.com/FiloSottile/age) — Simple, modern file encryption
- [git-crypt](https://github.com/AGWA/git-crypt) — Transparent encryption for git
- [NIST SP 800-122](https://csrc.nist.gov/publications/detail/sp/800-122/final) — PII confidentiality
- ISO 27001 A.8.24 — Use of cryptography

## Consequences

- Adds complexity to git workflow
- Requires key management discipline
- Breaks GitHub/GitLab web UI (files are encrypted blobs)
- git log shows encrypted commit messages (optional: keep messages clear)
- CI/CD cannot process encrypted content without key
