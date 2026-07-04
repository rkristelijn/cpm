# Paranoia Mode — Encrypted Repo with Obfuscated Filenames

> For highly sensitive content that must be version-controlled but never readable on remote.

## When to use

- Personal notes in a work GitLab repo
- Career/health/legal documents in a backed-up git repo
- Anything where filenames alone would leak information

## How it works

```
YOU WORK HERE (cleartext)              GIT PUSHES THIS (encrypted)
────────────────────────               ─────────────────────────────
~/mnt/my-journal/                      ~/git/lab/my-journal/cipherdir/
├── burnout-notes.md                   ├── aXf7bQ2kL9mP/
├── salary-review.md          →        │   └── nK8vR3qW.enc
└── legal/                             ├── zY4tH6jN/
    └── uber-claim.md                  │   └── pL2xC9mB.enc
                                       └── wQ7nF5dK/
                                           └── hJ3sA8yE.enc
```

- **gocryptfs** provides real-time encryption via FUSE mount
- **Filenames** are encrypted with EME wide-block encryption
- **Content** is AES-256-GCM encrypted
- **Git** only sees the encrypted blobs in `cipherdir/`
- **Performance**: ~5% overhead (hardware AES-NI)

## Setup

### Prerequisites

```bash
# macOS
brew install --cask macfuse   # Restart required after first install
brew install gocryptfs

# Linux
apt install gocryptfs fuse3
```

### Create paranoia repo

```bash
cpm setup-paranoia-repo
```

Interactive prompts:
1. Repo name (e.g., `encrypted-journal`)
2. Repo location (default: `~/git/lab/<name>`)
3. Mount point (default: `~/mnt/<name>`)
4. Password (your decryption key — **BACK THIS UP**)

### What gets created

```
~/git/lab/encrypted-journal/           ← Git repo
├── .git/hooks/pre-commit             ← Blocks cleartext commits
├── .gitignore                        ← Blocks *.md, *.txt, etc.
├── README.encrypted.md               ← Instructions for decryption
└── cipherdir/                        ← Encrypted content
    ├── gocryptfs.conf                ← Config (safe to commit)
    ├── gocryptfs.diriv               ← Dir IV (needed for decrypt)
    └── <encrypted blobs>...

~/mnt/encrypted-journal/              ← Your workspace (FUSE mount)
├── notes.md                          ← Cleartext, instant access
└── whatever-you-want/
```

## Daily workflow

```bash
# 1. Work (transparent — no special commands)
vim ~/mnt/encrypted-journal/notes.md

# 2. Commit encrypted changes
cd ~/git/lab/encrypted-journal
git add cipherdir/
git commit -m "update $(date +%Y-%m-%d)"

# 3. Push (only encrypted blobs leave your machine)
git push
```

## Commands

| Command | What it does |
|---|---|
| `cpm setup-paranoia-repo` | Create new encrypted repo |
| `cpm setup-paranoia-repo --check` | Verify prerequisites + active mounts |
| `cpm setup-paranoia-repo --mount <repo>` | Mount existing repo |
| `cpm setup-paranoia-repo --unmount <mount>` | Unmount |

## Auto-mount at login (optional)

### macOS (LaunchAgent)

```xml
<!-- ~/Library/LaunchAgents/com.paranoia.mount.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.paranoia.mount</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>echo "YOUR_PASSWORD" | gocryptfs -allow_other ~/git/lab/encrypted-journal/cipherdir ~/mnt/encrypted-journal</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
```

> ⚠️ Storing password in LaunchAgent is a tradeoff. Alternative: use macOS Keychain.

### Keychain-backed auto-mount

```bash
# Store password in Keychain (once)
security add-generic-password -a "$USER" -s "paranoia-journal" -w "YOUR_PASSWORD"

# Mount script (reads from Keychain)
security find-generic-password -a "$USER" -s "paranoia-journal" -w \
  | gocryptfs -allow_other ~/git/lab/encrypted-journal/cipherdir ~/mnt/encrypted-journal
```

## Security model

| Threat | Protection |
|---|---|
| Remote admin reads files | AES-256-GCM encrypted content |
| Remote admin reads filenames | EME filename encryption |
| Password brute-force | scrypt KDF (128MB memory, 0.5s per attempt) |
| Accidental cleartext commit | Pre-commit hook blocks non-cipherdir files |
| Key loss | **YOU MUST BACKUP YOUR PASSWORD** |
| Mounted + attacker has local access | Same risk as any unlocked file |

## Clone on another device

```bash
git clone <repo-url>
cd encrypted-journal
mkdir -p ~/mnt/encrypted-journal
gocryptfs cipherdir ~/mnt/encrypted-journal
# Enter password → files appear in mount point
```

## Comparison with alternatives

| Approach | Content enc. | Filename enc. | Git-native | Transparent | Setup |
|---|---|---|---|---|---|
| **gocryptfs (this)** | ✅ AES-256 | ✅ EME | ✅ | ✅ FUSE | Medium |
| git-crypt | ✅ AES-256 | ❌ | ✅ | ✅ | Easy |
| git-remote-gcrypt | ✅ GPG | ✅ | ⚠️ Special remote | ❌ | Hard |
| Manual age/GPG | ✅ | ❌ | ❌ | ❌ | Manual |
| Encrypted .dmg | ✅ | ✅ | ❌ | ⚠️ Mount | Easy |

## References

- [ADR-150: Paranoia Mode](../adrs/adr-150-paranoia-mode-encrypted-push.md)
- [gocryptfs](https://github.com/rfjakob/gocryptfs) — Encrypted overlay filesystem
- [gocryptfs security audit (2017)](https://defuse.ca/audits/gocryptfs.htm)
- NIST SP 800-122 — PII Confidentiality
- ISO 27001 A.8.24 — Use of Cryptography
