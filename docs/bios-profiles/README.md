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

## OPTIMISEDDEFAULTS_* - 2026-11-18

Exported right after `F5` Load Optimized Defaults in setup, during the
warm-reboot investigation (Step 2 of `docs/warm-reboot-action-plan.md`).

Diff against `BEFOREMCR_*` - only **two** meaningful changes:

| Setting | BEFOREMCR (baseline) | Optimised defaults |
|---|---|---|
| `Fast Boot` | Disabled | **Enabled** |
| `Integrated Graphics` | Disabled | **Auto** |

Everything else that matters is unchanged: `Power On By RTC` Disabled,
`ErP Ready` Disabled, `Above 4G Decoding` Enabled, `Resize BAR Support`
Enabled, `IOMMU` Auto, `Memory Context Restore` Auto, `Restore AC Power
Loss` Power Off, `XHCI Hand-off` Enabled, `Launch CSM` Disabled, `Ai
Overclock Tuner` Auto (EXPO off).

Two notes:

- `Power On By RTC` is **Disabled in both**, yet `rtcwake -m off -s 60`
  successfully woke the machine on 2026-11-18. So that setting is not the
  gate for the RTC wake on this firmware - correct an earlier assumption
  that it was.
- `Memory Context Restore` is Auto here and in `BEFOREMCR_*`; the MCR
  experiment value (Disabled) lives only in `AFTERMCR_*`. Loading defaults
  therefore reverted the MCR experiment, which is harmless (MCR off was
  proven ineffective on 2026-11-15).
