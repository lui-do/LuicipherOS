#!/usr/bin/env bash
# install/preflight.sh — target-machine checks before bootstrap (v0.1 stub, to flesh in grill)
# IDEA: fail fast on known tight tolerances: BIOS age, EXPO, ReBAR, GPU clearance, firmware present.
set -euo pipefail
echo "==> preflight (stub): check amdgpu, firmware, networkmanager, yay, ReBAR"
lspci | grep -i -E 'vga|3d|display' || true
ls /usr/share/linux-firmware/amdgpu 2>/dev/null | head || echo "WARN: linux-firmware-amdgpu missing?"
command -v yay || command -v paru || echo "NEED: yay-bin (bootstrap will install)"
cat /proc/cmdline || true
