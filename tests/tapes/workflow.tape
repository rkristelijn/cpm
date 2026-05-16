Output docs/features/workflow.gif

Set Shell "bash"
Set Width 900
Set Height 600
Set FontSize 14

Hide
Type "alias cpm=/Users/nlrxk0145/git/hub/cpm/cpm"
Enter
Type "cd $(mktemp -d)"
Enter
Type "cpm init >/dev/null"
Enter
Sleep 0.5s
Show

Type "# Show all project configuration"
Enter
Sleep 1.5s

Type "cpm get | head -20"
Enter
Sleep 4s

Type "# Bump the patch version (0.1.0 → 0.1.1)"
Enter
Sleep 1.5s

Type "cpm bump patch"
Enter
Sleep 2s

Type "cpm version"
Enter
Sleep 2s

Type "# Change project language"
Enter
Sleep 1.5s

Type "cpm set lang typescript"
Enter
Sleep 2s

Type "cpm get lang"
Enter
Sleep 3s
