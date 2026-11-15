#!/usr/bin/env bash
# tests/test_theme.sh — contract tests for scripts/theme.sh ("lui theme").
# Seams:
#   1. list shows presets from a themes dir fixture
#   2. set merges ONLY palette keys into the user tokens file, preserving
#      other keys (barHeight stays user-set); creates dirs/files as needed
#   3. set on a nonexistent preset fails cleanly, tokens untouched
#   4. reset removes palette keys, keeps barHeight
#   5. show guesses the active preset correctly
# No matugen needed (wallpaper path guarded in its own command; skipped here).
# USAGE: ./tests/test_theme.sh   (exit 0 = all pass; needs jq)
set -u
command -v jq >/dev/null || { echo "SKIP: jq not installed"; exit 0; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
PASS=0; FAILN=0
ok()  { PASS=$((PASS+1)); echo "  ok: $1"; }
bad() { FAILN=$((FAILN+1)); echo "  FAIL: $1"; }

mkdir -p "$T/themes"
cat > "$T/themes/dusk.json" <<'EOF'
{ "name": "Dusk", "bg": "#111111", "surface": "#222222", "fg": "#eeeeee",
  "muted": "#555555", "accent": "#00ff00", "alt": "#ff00ff", "warn": "#ffaa00",
  "fontFamily": "MonoTest" }
EOF
export XDG_CONFIG_HOME="$T/config"
TOKENS="$T/config/lui/quickshell/tokens.json"
run() { ( cd "$T" && ROOT_OVERRIDE= bash "$ROOT/scripts/theme.sh" "$@" ); }
# theme.sh derives ROOT from its own path; themes dir must be at ../themes.
# Build a fixture tree layout: $T/tree/{scripts,themes} with theme.sh inside.
mkdir -p "$T/tree/scripts"
cp "$ROOT/scripts/theme.sh" "$T/tree/scripts/"
cp "$T/themes/dusk.json" /dev/null 2>/dev/null; mkdir -p "$T/tree/themes"
cp "$T/themes/"*.json "$T/tree/themes/"
run() { bash "$T/tree/scripts/theme.sh" "$@"; }

echo "== 1. list =="
OUT=$(run list)
[[ "$OUT" == *"dusk"* && "$OUT" == *"Dusk"* ]] \
  && ok "lists fixture preset" || bad "list: $OUT"

echo "== 2. set merges palette keys, preserves others =="
mkdir -p "$(dirname "$TOKENS")"
echo '{ "barHeight": 42 }' > "$TOKENS"
run set dusk >/dev/null
[[ "$(jq -r .barHeight "$TOKENS")" == "42" ]] \
  && ok "barHeight preserved" || bad "barHeight clobbered: $(cat "$TOKENS")"
[[ "$(jq -r .accent "$TOKENS")" == "#00ff00" ]] \
  && ok "palette key applied" || bad "accent missing: $(cat "$TOKENS")"
[[ "$(jq -r '.name // empty' "$TOKENS")" == "" ]] \
  && ok "internal name key not leaked" || bad "name leaked into tokens"

echo "== 3. unknown preset fails cleanly =="
BEFORE=$(cat "$TOKENS")
run set nosuch 2>/dev/null; RC=$?
[[ $RC -ne 0 && "$(cat "$TOKENS")" == "$BEFORE" ]] \
  && ok "missing preset: non-zero exit, tokens untouched" || bad "rc=$RC"

echo "== 4. reset removes palette, keeps barHeight =="
run reset >/dev/null
[[ "$(jq -r .barHeight "$TOKENS")" == "42" && "$(jq -r '.accent // empty' "$TOKENS")" == "" ]] \
  && ok "reset kept barHeight, dropped palette" || bad "tokens: $(cat "$TOKENS")"

echo "== 5. show detects active preset =="
run set dusk >/dev/null
OUT=$(run show)
[[ "$OUT" == *"matches preset: dusk"* ]] \
  && ok "show identified dusk" || bad "show: $OUT"

echo ""
echo "tests: $PASS passed, $FAILN failed"
[[ $FAILN -eq 0 ]]
