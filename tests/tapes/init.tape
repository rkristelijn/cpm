Output docs/features/init.gif

Set Shell "bash"
Set Width 900
Set Height 600
Set FontSize 14

Hide
Type "alias cpm=./cpm"
Enter
Type "cd $(mktemp -d)"
Enter
Sleep 0.5s
Show

Type "# Initialize a new project with sensible defaults"
Enter
Sleep 1s

Type "cpm init"
Enter
Sleep 2s

Type "# Generated cpm.toml with tools, checks, and hooks"
Enter
Sleep 1s

Type "bat cpm.toml"
Enter
Sleep 4s
