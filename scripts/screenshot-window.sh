#!/usr/bin/env bash
# scripts/screenshot-window.sh — capture the ACTIVE window -> file -> Gradia.
# Area mode lives in the Print bind (grim+slurp); full-webpage capture is a
# browser feature (Helium DevTools: full-page screenshot), not an OS tool.
set -euo pipefail
geom=$(hyprctl activewindow -j | python3 -c 'import json,sys; w=json.load(sys.stdin); b=w["at"]; s=w["size"]; print(f"{b[0]},{b[1]} {s[0]}x{s[1]}")')
shotdir="$HOME/Pictures/Screenshots"
mkdir -p "$shotdir"
f="$shotdir/win-$(date +%Y%m%d-%H%M%S).png"
grim -g "$geom" "$f" && gradia "$f"
