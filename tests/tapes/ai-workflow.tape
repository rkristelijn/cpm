Output docs/features/ai-workflow.gif

Set Shell "bash"
Set Width 900
Set Height 700
Set FontSize 13

Hide
Type "source tests/tapes/setup-ai-demo.sh"
Enter
Sleep 1s
Show

Type "# AI generated code with issues — check quality"
Enter
Sleep 1.5s

Type "bat src/main.cpp"
Enter
Sleep 3s

Type "# cpm catches formatting violations"
Enter
Sleep 1s

Type "cpm check --fast 2>&1 | tail -12"
Enter
Sleep 5s

Type "# Auto-fix: cpm format cleans the code"
Enter
Sleep 1.5s

Type "cpm format 2>&1 | tail -5"
Enter
Sleep 3s

Type "# Formatted — but the secret is still there"
Enter
Sleep 1s

Type "bat src/main.cpp"
Enter
Sleep 4s

Type "# cpm findings shows what to fix next"
Enter
Sleep 1.5s

Type "cpm findings"
Enter
Sleep 3s
