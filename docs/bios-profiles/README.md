# BIOS profile snapshots - 2026-11-15

Exported by ASUS UEFI (Save as TXT + CMOS profiles) around the
Memory Context Restore experiment:

- `BEFOREMCR_*`: stock baseline (all Auto except notes)
- `AFTERMCR_*`: only change = Memory Context Restore Auto -> Disabled

Key extracted values (identical in both): Launch CSM Disabled, Fast Boot
Disabled, Ai Overclock Tuner Auto (EXPO off, DDR5-4800), Curve Optimizer
Auto, Power Supply Idle Control Auto, Above 4G Decoding Enabled,
PCIEX16(G5) Link Mode Auto, Native ASPM Auto, ErP Disabled.

_Kept as warranty evidence + rollback reference. Profile restore: Tool ->
Load Profile (CMO file)._
