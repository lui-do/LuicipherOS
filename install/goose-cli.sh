#!/usr/bin/env bash
# install/goose-cli.sh — install the Goose CLI from the same upstream release
# as goose-desktop-bin, so Desktop and CLI share one config/session tree.
#
# WHY THIS IS ONLY A FALLBACK: newer goose-desktop-bin builds bundle the CLI at
# /usr/bin/goose. Prefer that packaged binary (same release as Desktop); use this
# installer only if the package does not ship one. Keep VERSION/B2SUM in sync
# with config/packages-arch (goose-desktop-bin).
#
# Idempotent. Needs sudo; run it unprivileged (bootstrap does).
# BUMP TOGETHER: keep VERSION/B2SUM in sync with config/packages-arch
# (goose-desktop-bin) and re-check the release assets.
set -euo pipefail

VERSION="1.60.2"
B2SUM="879c6eb6783650226541ebd20226fc0c3d82292213ffcbaeac12e0559f747f1667cd665b7515d979e74251f819884827a57e459f67b5270dd4585ac1daa353d4"
URL="https://github.com/aaif-goose/goose/releases/download/v${VERSION}/goose-x86_64-unknown-linux-gnu-vulkan.tar.bz2"
DEST="/usr/local/lib/goose"
BIN="/usr/local/bin/goose"

log() { echo "==> goose-cli: $1"; }
die() { echo "goose-cli: $1" >&2; exit 1; }

command -v curl >/dev/null || die "curl missing"
command -v b2sum >/dev/null || die "b2sum missing (coreutils)"
command -v tar >/dev/null || die "tar missing"

if [[ -x "$BIN" ]] && "$BIN" --version 2>/dev/null | grep -q "$VERSION"; then
  log "already installed ($VERSION)"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

log "downloading $VERSION"
curl -fL --retry 3 -o "$TMP/goose.tar.bz2" "$URL"
( cd "$TMP" && printf '%s  %s\n' "$B2SUM" "goose.tar.bz2" | b2sum -c - ) \
  || die "checksum mismatch"
tar -xjf "$TMP/goose.tar.bz2" -C "$TMP"
[[ -f "$TMP/goose" ]] || die "tarball did not contain goose"

sudo install -d -m755 "$DEST"
sudo install -m755 "$TMP/goose" "$DEST/goose"
sudo ln -sfn "$DEST/goose" "$BIN"
log "installed $BIN ($VERSION)"