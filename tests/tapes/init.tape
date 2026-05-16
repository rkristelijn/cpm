Output docs/features/init.gif

Set Shell "bash"
Set Width 900
Set Height 600
Set FontSize 14

# Setup (hidden from user perspective)
Hide
Type "alias cpm=/Users/nlrxk0145/git/hub/cpm/cpm"
Enter
Type "cd $(mktemp -d)"
Enter
Sleep 0.5s
Show

Type "cpm init"
Enter
Sleep 2s

Type "cat cpm.toml"
Enter
Sleep 4s
