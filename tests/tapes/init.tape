Output docs/features/init.gif

Set Shell "bash"
Set Width 900
Set Height 600
Set FontSize 14

# Sandbox: fresh temp directory
Type "cd $(mktemp -d) && pwd"
Enter
Sleep 1s

Type "./cpm init"
Enter
Sleep 2s

Type "cat cpm.toml"
Enter
Sleep 4s
