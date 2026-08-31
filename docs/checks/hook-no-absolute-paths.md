# no-absolute-paths

## What it catches
Hardcoded absolute paths, home directory references (`~/`), and parent directory escapes (`../`) in staged code.

## Why it matters
- **Portability**: `/Users/john/project/config.json` breaks on every other machine
- **PII leak**: absolute paths expose usernames and directory structure
- **Repo escape**: `../../../etc/passwd` references files outside the repository
- **Security**: paths like `/home/deploy/.ssh/id_rsa` in code are a red flag

## Patterns detected

| Pattern | Example | Risk |
|---------|---------|------|
| Unix absolute | `/Users/remi/Documents/...` | Leaks username, non-portable |
| Unix system | `/etc/config`, `/var/log/...` | Server-specific, non-portable |
| Windows absolute | `C:\Users\John\Desktop\...` | Leaks username, non-portable |
| Home reference | `~/Documents/...` | Machine-specific |
| Parent escape | `../../outside-repo/secret` | References outside repo scope |

## Safe patterns (not flagged)
- `/dev/null`, `/dev/zero`, `/dev/urandom` — standard Unix devices
- `https://...` URL paths
- `import x from '../utils'` — relative imports in JS/TS
- Comment-only lines

## Examples
```
# Bad
config_path = "/Users/remi/project/config.json"
backup_dir = "~/Desktop/backups"
secret = open("../../.env").read()
data = "C:\\Users\\John\\data.csv"

# Good
config_path = os.environ.get("CONFIG_PATH", "config.json")
backup_dir = Path(__file__).parent / "backups"
secret = load_dotenv()
data = Path("data") / "data.csv"
```

## Override
- Global: `cpm hook --global --disable no-absolute-paths`
- Per-repo: add to cpm.toml:
  ```toml
  [hooks.global]
  no-absolute-paths = false
  ```
- Per-line: add `cpm:ignore path` comment
- One commit: `git commit --no-verify`
