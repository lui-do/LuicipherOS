#!/usr/bin/env bash
# install/preflight.sh — LuicipherOS v0.1 pre-bootstrap checks (fail fast).
# Run from Arch ISO or fresh Arch install BEFORE install/bootstrap.sh.
# Checks: UEFI, network, disk space, CPU/GPU (target: Ryzen 9600X + RX 7900 XT),
# firmware (amdgpu), ReBAR hint, RAM, archinstall present. Non-target machines
# get WARN (not FAIL) except for UEFI/network/disk — v0.1 is tuned for target,
# tested elsewhere (see TESTING.md).
# USAGE: ./install/preflight.sh [--target] [--vm]
#   --target = enforce target-machine expectations (CPU/GPU) as FAIL
#   --vm     = relax GPU/ReBAR checks for VM smoke test
set -euo pipefail

MODE="any"
for a in "$@"; do
  case "$a" in
    --target) MODE="target" ;;
    --vm) MODE="vm" ;;
    -h|--help)
      echo "Usage: $0 [--target] [--vm]"
      echo "  --target  fail unless Ryzen 9600X-class CPU + AMD gfx1100 GPU found"
      echo "  --vm      skip GPU/ReBAR/clearance checks (VM smoke)"
      exit 0
      ;;
  esac
done

PASS=0; WARN=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  [OK]   $1"; }
warn() { WARN=$((WARN+1)); echo "  [WARN] $1"; }
fail() { FAIL=$((FAIL+1)); echo "  [FAIL] $1"; }

echo "==> LuicipherOS preflight (mode=$MODE)"

echo "--- boot / system ---"
if [[ -d /sys/firmware/efi ]]; then
  pass "UEFI boot detected"
else
  fail "legacy BIOS boot — archinstall JSON expects UEFI + systemd-boot"
fi

echo "--- network ---"
if ping -c1 -W3 archlinux.org &>/dev/null || ping -c1 -W3 1.1.1.1 &>/dev/null; then
  pass "network reachable"
else
  fail "no network — archinstall + bootstrap need internet"
fi

echo "--- disk ---"
ROOT_AVAIL_KB=$(df -k / 2>/dev/null | awk 'NR==2{print $4}')
if [[ "${ROOT_AVAIL_KB:-0}" -ge 20971520 ]]; then
  pass "live root has >=20G working space (${ROOT_AVAIL_KB}k)"
else
  warn "live root <20G (${ROOT_AVAIL_KB:-?}k) — target install needs >=60G disk; check lsblk"
fi
lsblk -d -o NAME,SIZE,MODEL 2>/dev/null || true

echo "--- cpu / mem ---"
grep -m1 "model name" /proc/cpuinfo 2>/dev/null || true
MEM_GB=$(free -g 2>/dev/null | awk '/^Mem:/{print $2}')
echo "  mem: ${MEM_GB:-?}G"
if grep -qi "ryzen\|9600x\|amd" /proc/cpuinfo 2>/dev/null; then
  pass "AMD CPU detected"
else
  warn "non-AMD CPU — v0.1 tuned for Ryzen 9600X, will still install (see profiles/ in v0.2)"
fi
if [[ "$MODE" == "target" ]]; then
  grep -qi "9600X" /proc/cpuinfo 2>/dev/null && pass "target CPU Ryzen 5 9600X" \
    || fail "--target: expected Ryzen 5 9600X"
fi

echo "--- gpu (target: RX 7900 XT gfx1100 Navi31) ---"
if [[ "$MODE" == "vm" ]]; then
  warn "VM mode: skipping discrete-GPU expectations (virtio/llvmpipe OK for smoke)"
  lspci 2>/dev/null | grep -i -E 'vga|3d|display' || echo "  (no lspci GPU listed — OK in VM)"
else
  if lspci 2>/dev/null | grep -i -E 'vga|3d|display'; then
    pass "GPU PCI device listed (see above)"
  else
    warn "no VGA/3D PCI device listed"
  fi
  if lspci -nn 2>/dev/null | grep -qi "744c\|7900"; then
    pass "RX 7900 XT (744c) PCI ID detected"
  else
    MSG="not RX 7900 XT PCI ID — OK on non-target, FAIL with --target"
    if [[ "$MODE" == "target" ]]; then fail "$MSG"; else warn "$MSG"; fi
  fi
fi

echo "--- firmware ---"
if ls /usr/share/linux-firmware/amdgpu/navi31* &>/dev/null || ls /usr/lib/firmware/amdgpu/navi31* &>/dev/null; then
  pass "amdgpu navi31 firmware present"
else
  warn "navi31 firmware not found on ISO — fresh install pulls linux-firmware + linux-firmware-amdgpu (see config/packages)"
fi

echo "--- ReBAR hint (target: enable Above-4G + ReBAR in BIOS) ---"
if [[ "$MODE" == "vm" ]]; then
  warn "VM mode: ReBAR N/A"
elif ls /sys/bus/pci/devices/*/resizable_bar &>/dev/null; then
  pass "resizable_bar sysfs node present (check: cat /sys/bus/pci/devices/*/resizable_bar)"
  cat /sys/bus/pci/devices/*/resizable_bar 2>/dev/null || true
else
  warn "no resizable_bar node — enable Above-4G Decoding + ReBAR in BIOS (ASUS B650E-PLUS WIFI), then re-check; ROCm/DDIR benefit"
fi

echo "--- BIOS / EXPO checklist (manual, cannot auto-detect reliably) ---"
echo "  [ ] ASUS B650E-PLUS WIFI BIOS >= mid-2024 AGESA (ComboAM5 PI)"
echo "  [ ] EXPO enabled for RAM kit (verify: dmidecode -t memory | grep -i mt/s)"
echo "  [ ] Above-4G Decoding + ReBAR enabled"
echo "  [ ] 2x separate PCIe 8-pin cables to GPU (no daisy-chain pigtail)"
echo "  [ ] Clearance: GPU 313mm <= case 330mm; cooler 159mm <= lid 160mm"
echo "  [ ] 2nd SSD planned (separate /home later)"

echo "--- tooling ---"
command -v archinstall &>/dev/null && pass "archinstall present ($(archinstall --version 2>/dev/null || echo yes))" \
  || warn "archinstall missing on this ISO (install: pacman -S archinstall)"
command -v git &>/dev/null && pass "git present" || warn "git missing (archinstall JSON installs it)"
command -v python3 &>/dev/null && pass "python3 present" || warn "python3 missing"
PREFLIGHT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if python3 -m json.tool "$PREFLIGHT_ROOT/archinstall-desktop.json" &>/dev/null; then
  pass "archinstall-desktop.json is valid JSON"
else
  fail "archinstall-desktop.json invalid — run: python3 -m json.tool install/archinstall-desktop.json"
fi

echo ""
echo "==> preflight: $PASS ok, $WARN warnings, $FAIL failures"
if [[ "$FAIL" -gt 0 ]]; then
  echo "RESULT: FAIL — fix failures above before bootstrap."
  exit 1
fi
echo "RESULT: PASS (warnings OK for non-target / VM — see TESTING.md)"
