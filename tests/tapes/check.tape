Output docs/features/check.gif

Set Shell "bash"
Set Width 900
Set Height 700
Set FontSize 14

Type "# Tier 1: format + build (pre-commit)"
Enter
Sleep 1s

Type "./cpm check --fast"
Enter
Sleep 6s

Type "# Tier 2: + lint + test (pre-push)"
Enter
Sleep 1s

Type "CPM_MOCK=1 ./cpm check"
Enter
Sleep 4s

Type "# Tier 3: + coverage + sast (CI)"
Enter
Sleep 1s

Type "CPM_MOCK=1 ./cpm check --full"
Enter
Sleep 4s
