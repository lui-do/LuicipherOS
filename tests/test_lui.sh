#!/usr/bin/env bash
# tests/test_lui.sh — contract tests for scripts/lui.sh (the `lui` CLI).
# Seams:
#   1. tree discovery: $LUI_ROOT wins; a non-tree path is rejected
#   2. `sync` delegates to scripts/sync.sh and passes arguments through
#   3. `status` is read-only: it runs sync.sh --prune --dry-run
#   3b. `local-apps` delegates to scripts/generate-local-apps.sh, args pass through
#   4. `version` / `root` / `help` behave; unknown subcommand exits 2
#   5. never runs as root (EUID guard present in the script text)
# Method: a fixture tree whose sync.sh and generate-local-apps.sh are stubs that
# echo their arguments.
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
cat > "$T/tree/scripts/generate-local-apps.sh" <<'EOF'
#!/usr/bin/env bash
echo "GEN-CALLED: $*"
exit 0
EOF
cat > "$T/tree/scripts/ai.sh" <<'EOF'
#!/usr/bin/env bash
echo "AI-CALLED: $*"
exit 0
EOF
chmod +x "$T/tree/scripts/sync.sh" "$T/tree/scripts/generate-local-apps.sh" "$T/tree/scripts/ai.sh"

run() { LUI_ROOT="$T/tree" bash "$LUI" "$@" 2>&1; }
rc()  { LUI_ROOT="$T/tree" bash "$LUI" "$@" >/dev/null 2>&1; echo $?; }

echo "== 1. tree discovery =="
[[ "$(run root)" == "$T/tree" ]] \
  && ok "root resolves from LUI_ROOT" || bad "root wrong: $(run root)"
OUT=$(LUI_ROOT="$T/not-a-tree" bash "$LUI" root 2>&1); RC=$?
[[ "$RC" -ne 0 && "$OUT" == *"does not look like"* ]] \
  && ok "non-tree LUI_ROOT rejected" || bad "bad root accepted: rc=$RC out=$OUT"

echo "== 2. sync delegates and passes arguments through =="
[[ "$(run sync)" == *"SYNC-CALLED:"* ]] \
  && ok "bare sync delegates" || bad "bare sync: $(run sync)"
[[ "$(run sync --prune --dry-run)" == *"SYNC-CALLED: --prune --dry-run"* ]] \
  && ok "sync passes flags through" || bad "flag pass-through: $(run sync --prune --dry-run)"
[[ "$(run sync --prune --yes)" == *"SYNC-CALLED: --prune --yes"* ]] \
  && ok "sync passes --yes" || bad "--yes pass-through: $(run sync --prune --yes)"
[[ "$(run sync --system)" == *"SYNC-CALLED: --system"* ]] \
  && ok "sync passes --system" || bad "--system pass-through: $(run sync --system)"
[[ "$(run sync --user work)" == *"SYNC-CALLED: --user work"* ]] \
  && ok "sync passes --user ACCOUNT" || bad "--user ACCOUNT pass-through: $(run sync --user work)"
[[ "$(run sync --user=work)" == *"SYNC-CALLED: --user=work"* ]] \
  && ok "sync passes --user=ACCOUNT" || bad "--user= pass-through: $(run sync --user=work)"

echo "== 3. status is read-only and names the tree =="
STATUS_OUT=$(run status)
[[ "$STATUS_OUT" == *"SYNC-CALLED: --prune --dry-run"* ]] \
  && ok "status maps to --prune --dry-run" || bad "status wrong: $STATUS_OUT"
[[ "$STATUS_OUT" == *"tree: $T/tree"* ]] \
  && ok "status prints the resolved tree" || bad "no tree banner: $STATUS_OUT"

echo "== 3b. home fallback warns (stale-clone guard) =="
# A copy of the CLI with LUI_ROOT unset and /opt absent resolves to $HOME/LuicipherOS.
mkdir -p "$T/fakehome/LuicipherOS/scripts" "$T/fakebin"
cp "$T/tree/scripts/sync.sh" "$T/fakehome/LuicipherOS/scripts/sync.sh"
# the copy must NOT sit inside a tree, so its own-tree rule misses and the
# $HOME/LuicipherOS fallback is what resolves
cp "$LUI" "$T/fakebin/lui"
OUT=$(env -u LUI_ROOT HOME="$T/fakehome" bash "$T/fakebin/lui" status 2>&1)
[[ "$OUT" == *"[home-fallback]"* ]] \
  && ok "tree banner marks the fallback" || bad "fallback not labelled: $OUT"
[[ "$OUT" != *"WARNING:"* ]] \
  && ok "safe path does not warn (no cry-wolf)" || bad "spurious warning on status: $OUT"
OUT=$(env -u LUI_ROOT HOME="$T/fakehome" bash "$T/fakebin/lui" sync --prune --dry-run 2>&1)
[[ "$OUT" == *"WARNING: this is this user's own clone"* ]] \
  && ok "prune on the fallback warns loudly" || bad "no prune warning: $OUT"
OUT=$(env -u LUI_ROOT HOME="$T/fakehome" LUI_ROOT="$T/tree" bash "$T/fakebin/lui" sync --prune --dry-run 2>&1)
[[ "$OUT" != *"WARNING:"* ]] \
  && ok "no warning when LUI_ROOT is set" || bad "spurious warning: $OUT"

echo "== 3c. local-apps delegates and passes args through =="
[[ "$(run local-apps)" == *"GEN-CALLED:"* ]] \
  && ok "local-apps delegates to the generator" || bad "local-apps: $(run local-apps)"
[[ "$(run local-apps --remove)" == *"GEN-CALLED: --remove"* ]] \
  && ok "local-apps passes --remove through" || bad "--remove: $(run local-apps --remove)"

echo "== 3d. ai delegates =="
[[ "$(run ai status)" == *"AI-CALLED: status"* ]] \
  && ok "ai delegates to scripts/ai.sh" || bad "ai: $(run ai status)"

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
