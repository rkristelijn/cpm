Output docs/features/new.gif

Set Shell "bash"
Set Width 900
Set Height 600
Set FontSize 14

Hide
Type "alias cpm=/Users/nlrxk0145/git/hub/cpm/cpm"
Enter
Type "cd $(mktemp -d)"
Enter
Sleep 0.5s
Show

Type "# Scaffold a new C++ project"
Enter
Sleep 1s

Type "cpm new code-cpp-hello-world"
Enter
Sleep 2s

Type "ls code-cpp-hello-world/"
Enter
Sleep 1.5s

Type "cd code-cpp-hello-world"
Enter
Sleep 0.5s

Type "# Add a test file and a module"
Enter
Sleep 1s

Type "cpm new test parser"
Enter
Sleep 1s

Type "cpm new module utils"
Enter
Sleep 1s

Type "ls src/"
Enter
Sleep 2s
