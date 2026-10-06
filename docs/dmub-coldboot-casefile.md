# DMUB cold-boot case file (RX 7900 XT + B650E, Oct 2026) — research handoff

## Machine (from `desktop/Detailed_PC_Report_Without_Submetrics.txt` + session)

- Board: ASUS TUF GAMING B650E-PLUS WIFI, BIOS 4004 x86_64 (2026-09-16)
- CPU: Ryzen 5 9600X (Raphael iGPU present, 0e:00.0)
- RAM: 32 GB (2x16) Apacer DDR5, EXPO I 6000 CL38-48-48-96 1.35V
- GPU: RX 7900 XT 20 GB, PCI 0x1002:0x744c @ 0000:03:00.0,
  VBIOS ATOM 113-D70401-00 (2022/11/08), board vendor: UNKNOWN (need!)
- SSD: Kingston SNV3S1000G 1 TB (931.5 GB), LUKS + btrfs (@,@home,@log,@pkg,@snapshots)
- Monitor: Philips PHL 276E8V 4K, HDMI on GPU port
- PSU: UNKNOWN — photo label still needed (cold-rail suspect, never ruled out)
- OS: Arch, kernels 7.2.8-arch1 + 6.18.55-1-lts, systemd-boot, two loader entries

## BIOS (as set)

EXPO I, Above-4G ON (40-bit MMIO), ReBAR ON (32G BAR verified mapped),
SVM ON, CSM OFF, Secure Boot Other-OS, Fast Boot OFF, primary PCIE,
Bluetooth re-enabled (hci0 healthy), BT controller was briefly disabled.

## Symptom

Cold boot (shutdown + drain) hangs ~4s into init: `SMU: No response`
(msg_reg 2d), JPEG/VCN power-gate failures (ret -62), then endless
`Error queueing DMUB command: status=2` + DMCUB diagnostics. Also
xhci post-resume error + i2c-designware timeout (chipset bus 03:08.x).
Warm reboots boot clean. Failed boots leave NO journal (hang pre-flush).

## Elimination table (all on true-cold unless noted)

| Test | Result |
|---|---|
| Missing firmware blobs | Ruled out (dcn_3_2_1_dmcub present) |
| `pcie_aspm=off` | Still loops |
| `amd_iommu=off` | Still loops |
| ReBAR disabled | Still loops |
| LTS 6.18.55 vs main 7.2.8 | Both loop |
| Firmware 20260916 vs 20250708 | Loops on both (one clean boot on 50708, likely fluke) |
| `module_blacklist=amdgpu` (cmdline) | Boots (framebuffer, no accel) |
| Soft blacklist + late `modprobe` (minutes after boot) | Initialized clean twice (DMUB 0x07002F00/0x07003300) |
| Soft blacklist + `amdgpu-late.service` before greetd, true-cold | STORMED once (under investigation: unit vs early load unclear) |

## Current workarounds (all in repo main)

- `install/amdgpu-late.service` + modprobe.d soft blacklist (bootstrap-gated
  on AMD `[1002:]` PCI, SIGPIPE-proofed), unit currently DISABLED pending test
- `IgnorePkg = linux-firmware linux-firmware-amdgpu` on target (precaution)
- Recovery: boot-menu `module_blacklist=amdgpu`, or TTY2/hard power if spammed

## Open questions for elsewhere

1. PSU model/wattage (cold 12V rail marginality never checked).
2. Exact AIB board model + VBIOS updates.
3. Whether storm on the unit-boot came from early load (initramfs gap) or the
   unit itself — `systemctl disable amdgpu-late` test was next, unrun.
4. Soak-duration theory (minutes-powered vs boot-phase) untested.
5. Upstream draft: `docs/upstream-drm-amd-coldboot-dmub.md` (needs 1+2).
6. Related: drm/amd#4737 (SMU crashes, fw 20251125), Arch FS#78968 (status=2).
