#!/bin/bash
# Read-only boot report for the warm-reboot / blank-display investigations.
#
#   ./scripts/boot-report.sh        # current boot + 3 previous
#   ./scripts/boot-report.sh 8      # current boot + 8 previous
#
# Changes nothing, needs no root (journalctl is readable by users in the
# systemd-journal group). Answers, per boot:
#   * how the machine got here - reset reason `0x00080800` (CF9 hard reset)
#     vs `0x00200800` (came from a power-on)
#   * which mechanism the kernel would use for the next reset
#   * when the framebuffer console appeared and when amdgpu loaded
#   * whether the DMUB / power-gate storm is present (0 = clean)
#
# See docs/warm-reboot-post-hang.md for what the numbers mean.

set -uo pipefail

N="${1:-3}"

hdr() { printf '\n=== %s ===\n' "$1"; }

hdr "current boot"
printf 'cmdline:      %s\n' "$(cat /proc/cmdline)"
printf 'reboot type:  %s\n' "$(cat /sys/kernel/reboot/type 2>/dev/null || echo '?')"
printf 'framebuffer:  %s\n' "$(tr '\n' ' ' < /proc/fb 2>/dev/null || echo '?')"
printf 'reset reason: %s\n' "$(journalctl -k -b 0 --no-pager 2>/dev/null \
  | grep -m1 -oE 'reason \[0x[0-9a-f]+\]: .*' | sed 's/^reason //' || true)"
printf 'DMUB/power-gate errors: %s\n' "$(journalctl -k -b 0 --no-pager 2>/dev/null \
  | grep -ciE 'Error queueing DMUB|Failed to power gate')"

hdr "units"
for u in amdgpu-late amdgpu-unload-on-shutdown; do
  printf '%-30s enabled=%-10s active=%s\n' "$u" \
    "$(systemctl is-enabled "$u" 2>&1)" "$(systemctl is-active "$u" 2>&1)"
done

hdr "/etc/modprobe.d/amdgpu-coldboot.conf"
cat /etc/modprobe.d/amdgpu-coldboot.conf 2>/dev/null || echo "(root-only, use sudo)"

hdr "boot history"
journalctl --list-boots --no-pager 2>/dev/null | tail -"$((N + 1))"

hdr "per-boot summary: reset reason | console switch | amdgpu load | DMUB errors"
for i in $(seq 0 "$N"); do
  b="$i"; [ "$i" -gt 0 ] && b="-$i"
  reason=$(journalctl -k -b "$b" --no-pager 2>/dev/null \
    | grep -m1 -oE 'reason \[0x[0-9a-f]+\]: .*' | sed 's/^reason //')
  cons=$(journalctl -k -b "$b" -o short-monotonic --no-pager 2>/dev/null \
    | grep -m1 'Console: switching' | sed 's/^\[ *//; s/\].*//')
  gpu=$(journalctl -k -b "$b" -o short-monotonic --no-pager 2>/dev/null \
    | grep -m1 'amdgpu 0000:03:00.0: enabling' | sed 's/^\[ *//; s/\].*//')
  err=$(journalctl -k -b "$b" --no-pager 2>/dev/null \
    | grep -ciE 'Error queueing DMUB|Failed to power gate')
  printf 'boot %-4s | %-44s | console %-10s | gpu %-10s | DMUB %s\n' \
    "$b" "${reason:-(none)}" "${cons:-?}" "${gpu:-?}" "$err"
done

printf '\nReminder: 0x00200800 where you pressed *reboot* means that reboot failed and the\n'
printf 'machine was power-cycled. 0x00080800 means a CF9 hard reset was delivered.\n'
