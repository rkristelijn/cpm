#!/usr/bin/env bash
# cpm:ignore-file SH-QUAL-014 — detector/test source: contains the patterns it checks for
# check-dangerous-shell.sh — Detect dangerous/evil bash patterns in scripts.
# @see ADR-129 (unified findings contract)
source "$(dirname "$0")/../../../lib/shell/check.sh"

# Combined regex — one grep pass for all dangerous patterns
# Categories: filesystem, permissions, git, process, network, history, disk
COMBINED='rm -rf /[^v]|rm -rf \$[^{]|:\(\)\{.*\|.*\};:|dd if=.*/dev/(zero|urandom).*of=.*/dev/sd|chmod -R 777 /[^.]|chmod.*777|chown -R.*root.*/[^.]|eval "\$|eval \$[^(]|curl.*\| *[bs]h|wget.*\| *sh|wget.*-O-.*\| *sh|>\s*/dev/sd|git push.*--force|git reset --hard|git clean -fd|nohup.*rm|history -c|export HISTSIZE=0|unset HISTFILE|mkfs\.|find / -delete|find \. -delete|kill -9 -1|shred |truncate -s 0|cat /dev/(u?random|zero) >|mv .* /dev/null|ln -sf /dev/null|export PATH=.*/dev/null|alias (ls|cd|cp|mv)=.*rm|chmod 000 |crontab -r|passwd -d|DROP (DATABASE|TABLE)|iptables -F'

# Single grep pass — fast
hits=$(grep -rnE "$COMBINED" \
  --include='*.sh' \
  --exclude-dir=.git --exclude-dir=vendor --exclude-dir=node_modules --exclude-dir=.tmp \
  --exclude='check-dangerous-shell.sh' \
  --exclude='check-sql-antipatterns.sh' \
  --exclude='check-nestjs.sh' \
  . 2>/dev/null | grep -v "cpm:ignore\|^[[:space:]]*#" || true)

[[ -z "$hits" ]] && exit 0

# Classify each hit
while IFS= read -r hit; do
  [[ -z "$hit" ]] && continue
  file="${hit%%:*}"; rest="${hit#*:}"
  linenum="${rest%%:*}"; line="${rest#*:}"
  file="${file#./}"
  [[ "$line" =~ ^[[:space:]]*# ]] && continue

  case "$line" in
    *'rm -rf /'*) [[ "$line" != *'rm -rf /var'* ]] && findings_add "error" "$file:$linenum" "rm-rf-root" "rm -rf on root/absolute path" "Use relative paths" "" ;;
    *'rm -rf $'*) findings_add "warning" "$file:$linenum" "rm-rf-unquoted-var" "rm -rf with unquoted variable" "Quote variables" "" ;;
    *':(){'*) findings_add "error" "$file:$linenum" "fork-bomb" "Fork bomb detected" "Remove immediately" "" ;;
    *'dd if='*'/dev/sd'*) findings_add "error" "$file:$linenum" "dd-disk-wipe" "dd writing to disk device" "Verify target" "" ;;
    *'chmod -R 777 /'*) findings_add "error" "$file:$linenum" "chmod-777-root" "chmod 777 on absolute path" "Use least-privilege" "" ;;
    *'chmod 000 '*) findings_add "error" "$file:$linenum" "chmod-000" "chmod 000 removes all access" "Use appropriate permissions" "" ;;
    *'chmod'*'777'*) findings_add "warning" "$file:$linenum" "chmod-777" "chmod 777 grants full access" "Use 755/644" "" ;;
    *'chown -R'*'root'*'/'*) findings_add "warning" "$file:$linenum" "chown-root-absolute" "chown root on absolute path" "Verify path" "" ;;
    *'eval "$'*|*'eval $'*) findings_add "warning" "$file:$linenum" "eval-variable" "eval with variable (injection risk)" "Use arrays instead" "" ;;
    *'curl'*'| sh'*|*'curl'*'| bash'*|*'wget'*'| sh'*|*'wget'*'-O-'*'| sh'*) findings_add "warning" "$file:$linenum" "curl-pipe-sh" "Piping download to shell" "Download, inspect, then execute" "" ;;
    *'git push'*'--force'*) findings_add "warning" "$file:$linenum" "git-force-push" "Force push destroys history" "Use --force-with-lease" "" ;;
    *'git reset --hard'*) findings_add "warning" "$file:$linenum" "git-reset-hard" "Hard reset discards changes" "Stash first" "" ;;
    *'git clean -fd'*) findings_add "warning" "$file:$linenum" "git-clean-force" "Force clean removes files" "Use -n (dry-run) first" "" ;;
    *'nohup'*'rm'*) findings_add "error" "$file:$linenum" "nohup-rm" "Background deletion" "Avoid nohup with rm" "" ;;
    *'history -c'*|*'HISTSIZE=0'*|*'unset HISTFILE'*) findings_add "warning" "$file:$linenum" "history-tamper" "History manipulation" "Investigate why" "" ;;
    *'mkfs.'*) findings_add "error" "$file:$linenum" "mkfs-format" "Filesystem format command" "Verify correct device" "" ;;
    *'find / -delete'*|*'find . -delete'*) findings_add "error" "$file:$linenum" "find-delete" "Recursive delete via find" "Add -maxdepth and specific path" "" ;;
    *'kill -9 -1'*) findings_add "error" "$file:$linenum" "kill-all" "Kill all user processes" "Target specific PIDs" "" ;;
    *'shred '*) findings_add "warning" "$file:$linenum" "shred" "Secure file destruction" "Verify target files" "" ;;
    *'truncate -s 0'*) findings_add "warning" "$file:$linenum" "truncate-zero" "Truncating file to zero bytes" "Verify target" "" ;;
    *'cat /dev/'*'>'*) findings_add "error" "$file:$linenum" "cat-dev-to-disk" "Writing device stream to target" "Verify target" "" ;;
    *'mv '*'/dev/null'*) findings_add "error" "$file:$linenum" "mv-to-devnull" "Moving files to /dev/null" "Use rm if intentional" "" ;;
    *'ln -sf /dev/null'*) findings_add "warning" "$file:$linenum" "symlink-devnull" "Symlinking to /dev/null" "Verify target file" "" ;;
    *'export PATH='*'/dev/null'*) findings_add "error" "$file:$linenum" "path-destroy" "PATH set to /dev/null" "Remove this line" "" ;;
    *'alias '*'='*'rm'*) findings_add "error" "$file:$linenum" "evil-alias" "Alias hiding destructive command" "Remove malicious alias" "" ;;
    *'crontab -r'*) findings_add "warning" "$file:$linenum" "crontab-remove" "Removing all cron jobs" "Use crontab -l first" "" ;;
    *'passwd -d'*) findings_add "error" "$file:$linenum" "passwd-remove" "Removing password (security risk)" "Never remove passwords" "" ;;
    *'DROP DATABASE'*|*'DROP TABLE'*) findings_add "error" "$file:$linenum" "sql-drop" "SQL DROP command in script" "Add confirmation/backup step" "" ;;
    *'iptables -F'*) findings_add "warning" "$file:$linenum" "firewall-flush" "Flushing all firewall rules" "Save rules first: iptables-save" "" ;;
  esac
done <<< "$hits"
