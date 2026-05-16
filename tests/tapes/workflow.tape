Output docs/features/workflow.gif

Set Shell "bash"
Set Width 900
Set Height 600
Set FontSize 14

# Sandbox: create a fresh project
Type "export SANDBOX=$(mktemp -d) && cd $SANDBOX"
Enter
Sleep 1s

# Init
Type "./cpm init"
Enter
Sleep 2s

# Show config
Type "./cpm get"
Enter
Sleep 3s

# Bump version
Type "./cpm bump patch"
Enter
Sleep 1s

Type "./cpm version"
Enter
Sleep 1s

# Set a value
Type "./cpm set lang typescript"
Enter
Sleep 1s

Type "./cpm get lang"
Enter
Sleep 2s
