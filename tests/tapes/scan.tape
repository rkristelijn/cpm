Output docs/features/scan.gif

Set Shell "bash"
Set Width 900
Set Height 600
Set FontSize 14

Type "# Scan repos for quality metrics (<1s for 100+ repos)"
Enter
Sleep 1s

Type "./cpm scan .. --depth 1 | head -40"
Enter
Sleep 5s
