#!/usr/bin/env bash
# tests/test_lui.sh — contract tests for scripts/lui.sh (the `lui` CLI).
# Seams:
#   1. tree discovery: $LUI_ROOT wins; a non-tree path is rejected
#   2. `sync` delegates to scripts/sync.sh and passes arguments through
#   3. `status` is read-only: it runs sync.sh --prune --dry-run
#   4. `version` / `root` / `help` behave; unknown subcommand exits 2
#   5. never runs as root (EUID guard present in the script text)
# Method: a fixture tree whose sync.sh is a stub that echoes its arguments.
# USAGE: ./tests/test_lui.sh   (exit 0 = all pass)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LUI="$ROOT/scripts/lui.sh"
PASS=0; FAILN=0
ok()  { PASS=$((PASS+1)); echo "  ok: $1"; }
bad() { FAILN=$((FAILN+1)); echo "  FAIL: $1"; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/tree/scripts"
cat > "$T/tree/scripts/sync.sh" <<'EOF'
#!/usr/bin/env bash
echo "SYNC-CALLED: $*"
exit 0
EOF
chmod +x "$T/tree/scripts/sync.sh"

run() { LUI_ROOT="$T/tree" bash "$LUI" "$@" 2>&1; }
rc()  { LUI_ROOT="$T/tree" bash "$LUI" "$@" >/dev/null 2>&1; echo $?; }

echo "== 1. tree discovery =="
[[ "$(run root)" == "$T/tree" ]] \
  && ok "root resolves from LUI_ROOT" || bad "root wrong: $(run root)"
OUT=$(LUI_ROOT="$T/not-a-tree" bash "$LUI" root 2>&1); RC=$?
[[ "$RC" -ne 0 && "$OUT" == *"does not look like"* ]] \
  && ok "non-tree LUI_ROOT rejected" || bad "bad root accepted: rc=$RC out=$OUT"

echo "== 2. sync delegates and passes arguments through =="
[[ "$(run sync)" == "SYNC-CALLED: " ]] \
  && ok "bare sync delegates" || bad "bare sync: $(run sync)"
[[ "$(run sync --prune --dry-run)" == "SYNC-CALLED: --prune --dry-run" ]] \
  && ok "sync passes flags through" || bad "flag pass-through: $(run sync --prune --dry-run)"
[[ "$(run sync --prune --yes)" == "SYNC-CALLED: --prune --yes" ]] \
  && ok "sync passes --yes" || bad "--yes pass-through: $(run sync --prune --yes)"

echo "== 3. status is read-only =="
[[ "$(run status)" == "SYNC-CALLED: --prune --dry-run" ]] \
  && ok "status maps to --prune --dry-run" || bad "status wrong: $(run status)"

echo "== 4. version / help / unknown =="
[[ "$(run version)" == lui\ * ]] \
  && ok "version prints a version" || bad "version: $(run version)"
run help | grep -q '^USAGE' \
  && ok "help prints usage" || bad "help missing usage"
[[ "$(run)" == *USAGE* ]] \
  && ok "no arguments prints usage" || bad "bare invocation: $(run)"
[[ "$(rc frobnicate)" -eq 2 ]] \
  && ok "unknown subcommand exits 2" || bad "unknown subcommand rc=$(rc frobnicate)"

echo "== 5. root guard =="
grep -q 'do not run lui as root' "$LUI" \
  && ok "EUID root guard present" || bad "no root guard in $LUI"

echo ""
echo "tests: $PASS passed, $FAILN failed"
[[ "$FAILN" -eq 0 ]]
