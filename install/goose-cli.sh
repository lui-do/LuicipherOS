#!/usr/bin/env bash
# install/goose-cli.sh — install the Goose CLI from the same upstream release
# as goose-desktop-bin, so Desktop and CLI share one config/session tree.
#
# WHY NOT the AUR CLI: goose-cli-bin conflicts with goose-desktop (and
# goose-desktop-bin deliberately removes /usr/bin/goose). Keeping the Desktop
# package and installing the matching CLI tarball is the only combination that
# gives both without conflicting packages.
#
# Idempotent. Needs sudo; run it unprivileged (bootstrap does).
# BUMP TOGETHER: keep VERSION/B2SUM in sync with config/packages-arch
# (goose-desktop-bin) and re-check the release assets.
set -euo pipefail

VERSION="1.60.1"
B2SUM="8a38d9830c82e0ad515735c94ab73be7970ddad0445fb918e54e09bfe2b7f71dfaae463d6bbd4191963dc197adc27a6943ba3082638cc7b76d19de6ff7914b2d"
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