# cpm encrypt — Design

## Concept

Two encryption modes for repos with sensitive content:

| Mode | Tool | What's encrypted | Use case |
|------|------|-----------------|----------|
| `transparent` | git-crypt | File content only | Journal, docs, ADRs — need git history |
| `vault` | age + obfuscated names | Content + filenames | Credentials, HR, truly secret |

## Architecture: C+ (Encrypted Remote, Plain Local)

### Principle

```
LOCAL (your machine)          REMOTE (GitLab)
─────────────────────         ──────────────────
docs/journal/2026-08-18.md    vault/a3f9e1b2.age
docs/adr/003-encryption.md    vault/7c4d2e8f.age
.manifest (gitignored)        README.md
full git history              commit: "chore: minor updates"
diffs, blame, branches        opaque blobs only
```

### How it works

Two git branches coexist:
- **`local` branch** (default, where you work): plain text, full git history
- **`main` branch** (what gets pushed): only `vault/` blobs + README

The `cpm encrypt push` command:
1. Encrypts all tracked files → `vault/{hash}.age`
2. Updates manifest (hash→path mapping, encrypted too)
3. Switches to `main`, replaces content with vault/ only
4. Commits with random bland message
5. Pushes `main` to remote
6. Switches back to `local`

The `cpm encrypt pull` command (new machine):
1. Clones repo (gets only vault/ blobs on main)
2. Decrypts all blobs using age key
3. Reconstructs file tree from manifest
4. Creates local branch with full plain text

### What you get

| Feature | Local | Remote |
|---------|-------|--------|
| File content readable | ✅ | ❌ encrypted |
| Filenames visible | ✅ | ❌ hashed |
| Folder structure visible | ✅ | ❌ flat vault/ |
| Git diff | ✅ | ❌ binary |
| Git blame | ✅ | ❌ |
| Git log | ✅ | Only bland messages |
| Commit messages | Real (local only) | Random bland |

### Security model

- **Content:** encrypted with age (X25519)
- **Filenames:** salted SHA-256 hash (salt in manifest, manifest also encrypted)
- **Commit messages on remote:** randomized, reveal nothing
- **Folder structure on remote:** flat `vault/` directory
- **Local git history:** full, plain text, never leaves your machine
- **Key:** age key in `~/.config/sops/age/keys.txt`

## cpm commands (proposed)

```bash
cpm encrypt init                 # Setup git-crypt + .gitattributes + commit-msg hook
cpm encrypt status               # Show what's encrypted, what's plain
cpm encrypt add <path>           # Add path to .gitattributes (transparent mode)
cpm encrypt vault add <file>     # Encrypt to vault (obfuscated mode)
cpm encrypt vault sync           # Re-encrypt all vault items
cpm encrypt check                # Verify: no plaintext secrets on remote, 
                                 #         commit messages clean,
                                 #         .gitattributes covers sensitive paths
```

### commit-msg hook (installed by `cpm encrypt init`)

Overwrites every commit message with a random bland developer message that leaks zero information:

```
chore: reduce code duplication
fix: correct precedence
chore: flatten directory structure
chore: update CI step
chore: normalize path separators
```

50 messages that read as real commits but reveal nothing about actual content. Installed automatically as `.githooks/commit-msg` when `cpm encrypt init` is run.

## Setup flow

```bash
# 1. Install git-crypt
brew install git-crypt

# 2. Init in repo
cpm encrypt init
# → runs: git-crypt init
# → creates: .gitattributes with encryption patterns
# → creates: .cpm/encrypt.toml (config: which paths, which mode)

# 3. Add GPG key (or symmetric key)
git-crypt add-gpg-user <KEY-ID>
# or for symmetric:
git-crypt export-key .cpm/git-crypt-key  # store securely

# 4. Existing files get encrypted on next push
git add .gitattributes docs/
git commit -m "chore: enable transparent encryption"
git push  # files are now encrypted on remote
```

## Open questions

1. GPG vs symmetric key for git-crypt? (symmetric = simpler for solo, GPG = multi-user)
2. Should `cpm encrypt check` run as a pre-commit hook?
3. Should commit message linting block messages with keywords like "salary", "burnout", names?
4. How to handle the migration from current vault.sh to hybrid model?
