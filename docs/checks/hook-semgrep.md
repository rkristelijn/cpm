# hook-semgrep

## What it catches

Critical SAST vulnerabilities like SQL injection, XSS, command injection, and insecure deserialization.

## Why it matters

Semgrep catches security bugs at the code level before they reach production. These are the vulnerability classes most commonly exploited in the wild. Catching them pre-commit is orders of magnitude cheaper than finding them in production.

## Examples

```text
# Bad
query = "SELECT * FROM users WHERE id = " + user_input
subprocess.call(user_input, shell=True)

# Good
cursor.execute("SELECT * FROM users WHERE id = %s", (user_input,))
subprocess.call([binary, arg1], shell=False)
```

## Override

- Global: `cpm hook --global --disable semgrep`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  semgrep = false
  ```

- One commit: `git commit --no-verify`
