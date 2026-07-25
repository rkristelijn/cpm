# Launchpad PPA Setup Guide

## Prerequisites

- Ubuntu/Launchpad account (launchpad.net)
- GPG key (RSA 4096-bit recommended)

## Steps

### 1. Generate GPG key

```bash
gpg --batch --gen-key <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: Your Name
Name-Email: your-email@example.com
Expire-Date: 2y
%commit
EOF
```

Verify:

```bash
gpg --list-keys --keyid-format long your-email@example.com
```

Note your fingerprint (40 hex chars, e.g., `8BAD27160105F27EF30946C4E1FC12DD9004A865`).

### 2. Upload key to Ubuntu keyserver

```bash
# Try direct (port 11371)
gpg --keyserver keyserver.ubuntu.com --send-keys <FINGERPRINT>

# If blocked by firewall, use curl upload:
gpg --armor --export <FINGERPRINT> | \
  curl -s --data-urlencode "keytext@-" https://keyserver.ubuntu.com/pks/add
```

Verify it's there:

```bash
curl -s "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x<FINGERPRINT>" | head -3
```

### 3. Create PPA on Launchpad

1. Go to: <https://launchpad.net/~/+activate-ppa>
2. URL: `your-package-name`
3. Display name: `Your Package`
4. Accept Terms of Use

### 4. Import key into Launchpad

1. Go to: <https://launchpad.net/~/+editpgpkeys>
2. Paste fingerprint (with spaces): `XXXX XXXX XXXX XXXX ...`
3. Click "Import Key"
4. Check email for encrypted verification message

### 5. Decrypt verification email

```bash
# Copy the PGP message from email, save to file, then:
gpg --decrypt < verification-email.asc

# Or pipe directly:
cat << 'EOF' | gpg --decrypt
-----BEGIN PGP MESSAGE-----
<paste encrypted content>
-----END PGP MESSAGE-----
EOF
```

Click the `https://launchpad.net/token/XXXX` link from the decrypted message.

### 6. Upload packages to PPA

```bash
dput ppa:your-username/your-ppa <package>_<version>_source.changes
```

## Troubleshooting

### "No route to host" on keyserver

Your network/firewall blocks port 11371 (HKP). Use the curl method:

```bash
gpg --armor --export <FINGERPRINT> | \
  curl -s --data-urlencode "keytext@-" https://keyserver.ubuntu.com/pks/add
```

### "Launchpad could not import the OpenPGP key"

Key sync takes 2-10 minutes. Wait and retry the confirmation link.
Verify key is actually on the server:

```bash
curl -s "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x<FINGERPRINT>" | head -3
```

### Key not found after upload

Try uploading to multiple servers — they sync between each other:

```bash
gpg --armor --export <FINGERPRINT> | curl -s --data-urlencode "keytext@-" https://keyserver.ubuntu.com/pks/add
gpg --keyserver hkps://keys.openpgp.org --send-keys <FINGERPRINT>
```

## Building .deb source packages

```bash
# Install tools
sudo apt install devscripts debhelper dh-make

# Create source package
cd your-project
dh_make --createorig -s -y
dpkg-buildpackage -S -sa -k<FINGERPRINT>

# Upload to PPA
dput ppa:your-username/your-ppa ../*_source.changes
```

## References

- <https://help.launchpad.net/Packaging/PPA>
- <https://help.ubuntu.com/community/GnuPrivacyGuardHowto>
