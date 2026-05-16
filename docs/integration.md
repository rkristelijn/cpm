# CPM Integration Guide

## Quick Setup

```bash
# In je project repo (workspace-tui, llama-cli, etc)
bash ../cpm/setup-cpm.sh
```

Dit maakt:

- Symlink `lib/cpm` → `../cpm/lib`
- Voegt includes toe aan Makefile
- Scripts kunnen nu `source lib/cpm/shell/ui.sh` gebruiken

## Gebruik

### In Makefile

```makefile
# Bovenaan Makefile
include lib/cpm/make/common.mk
include lib/cpm/make/quality.mk
include lib/cpm/make/git.mk
include lib/cpm/make/registry.mk

# Nu heb je automatisch:
# - LOG=1 pattern
# - help target
# - check-fast/check/check-all
# - hooks target
# - skip/unskip targets
```

### In Scripts

```bash
#!/usr/bin/env bash
# Gebruik CPM UI library
source lib/cpm/shell/ui.sh

print_step "01/10" "gitleaks" "success" "2s"
print_error "check failed"
```

### In Git Hooks

```bash
#!/usr/bin/env bash
source lib/cpm/shell/ui.sh
source lib/cpm/shell/log.sh

# Registry-driven checks
REGISTRY=".config/checks-registry.json"
CHECKS=$(jq -r '.checks | to_entries[] | 
  select(.value.tier == "pre-commit") | .key' "$REGISTRY")

for check in $CHECKS; do
  "check_${check//-/_}" && STATUS=0 || STATUS=$?
  print_step "$num" "$check" "$([[ $STATUS -eq 0 ]] && echo success || echo error)"
done

log_run "pre-commit" 0
```

## Updates

Omdat het een symlink is, krijg je automatisch updates:

```bash
cd cpm
git pull
# Alle repos die lib/cpm symlinken krijgen nu de updates
```

## Migration naar CPM Binary (Toekomst)

Als de CPM binary klaar is:

```bash
cpm init --migrate
# Verwijdert symlinks
# Genereert cpm.toml
# Makefile delegeert naar cpm binary
```

Dan wordt je Makefile:

```makefile
check:
	@cpm check

format:
	@cpm format

lint:
	@cpm lint
```

## Voordelen Symlink Aanpak

✅ **Instant updates** - Pull in cpm, alle repos hebben het  
✅ **Geen duplicatie** - Één bron van waarheid  
✅ **Backwards compatible** - Werkt met bestaande Makefiles  
✅ **Gradual migration** - Stap voor stap overstappen  
✅ **No binary needed** - Werkt met shell scripts  

## Nadelen

⚠️ **Relatief pad** - Werkt alleen als cpm in ../cpm staat  
⚠️ **Symlink support** - Moet ondersteund worden door OS  

## Alternatief: Absolute Pad

Als je cpm op een vaste locatie hebt:

```bash
# In ~/.zshrc of ~/.bashrc
export CPM_LIB="$HOME/git/hub/cpm/lib"

# In Makefile
include $(CPM_LIB)/make/common.mk
```

## Checklist per Repo

- [ ] Run `bash ../cpm/setup-cpm.sh`
- [ ] Verify `lib/cpm` symlink exists
- [ ] Test `make help`
- [ ] Test `make check-fast`
- [ ] Update scripts to use `lib/cpm/shell/ui.sh`
- [ ] Update git hooks to use CPM patterns
- [ ] Remove duplicated code (ui.sh, log.sh, etc)
