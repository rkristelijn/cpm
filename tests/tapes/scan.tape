Output docs/features/scan.gif

Set Shell "bash"
Set Width 900
Set Height 700
Set FontSize 14

Type "# Scan repos for quality metrics (<1s for 100+ repos)"
Enter
Sleep 1s

Type "./cpm scan .. --depth 1 | head -40"
Enter
Sleep 5s

Type "# Query findings for a specific repo"
Enter
Sleep 1.5s

Type "grep 'linux-intel' ~/.local/share/cpm/scan-findings.jsonl | bat -l json --plain"
Enter
Sleep 4s
