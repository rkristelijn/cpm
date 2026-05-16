Output docs/features/demo.gif

Set Shell "bash"
Set Width 900
Set Height 700
Set FontSize 13

Hide
Type "alias cpm=/Users/nlrxk0145/git/hub/cpm/cpm"
Enter
Type "cd $(mktemp -d)"
Enter
Type "cpm new code-cpp-demo-app >/dev/null && cd code-cpp-demo-app"
Enter
Type "echo '#include <iostream>' > src/main.cpp"
Enter
Type "echo 'using namespace std;' >> src/main.cpp"
Enter
Type "echo 'int main( ){int x=42;if(x>10){cout<<x<<endl;}return 0;}' >> src/main.cpp"
Enter
Sleep 0.5s
Show

Type "# A messy C++ project with formatting issues"
Enter
Sleep 1.5s

Type "bat src/main.cpp"
Enter
Sleep 3s

Type "# cpm check catches the formatting violation"
Enter
Sleep 1.5s

Type "cpm check --fast 2>&1 | tail -10"
Enter
Sleep 5s

Type "# Auto-fix: cpm format rewrites the code"
Enter
Sleep 1.5s

Type "cpm format"
Enter
Sleep 3s

Type "# Code is now properly formatted"
Enter
Sleep 1s

Type "bat src/main.cpp"
Enter
Sleep 4s

Type "# Disable a check you don't need"
Enter
Sleep 1.5s

Type "cpm set code-yaml-syntax-format false"
Enter
Sleep 1.5s

Type "cpm get code-yaml-syntax-format"
Enter
Sleep 3s
