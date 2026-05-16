Output docs/features/new.gif

Set Shell "bash"
Set Width 900
Set Height 600
Set FontSize 14

# Sandbox
Type "cd $(mktemp -d)"
Enter
Sleep 1s

# Create new project
Type "./cpm new code-cpp-hello-world"
Enter
Sleep 2s

Type "ls code-cpp-hello-world/"
Enter
Sleep 1s

# Add a test and module
Type "cd code-cpp-hello-world"
Enter
Sleep 0.5s

Type "./cpm new test parser"
Enter
Sleep 1s

Type "./cpm new module utils"
Enter
Sleep 1s

Type "ls src/"
Enter
Sleep 2s
