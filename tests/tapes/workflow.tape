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

Type "cpm get"
Enter
Sleep 3s

Type "cpm bump patch"
Enter
Sleep 1s

Type "cpm version"
Enter
Sleep 1.5s

Type "cpm set lang typescript"
Enter
Sleep 1s

Type "cpm get lang"
Enter
Sleep 2s
