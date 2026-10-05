# DRAFT upstream report — drm/amd: Navi31 DMUB cold-boot failure (NOT FILED YET)

File at: https://gitlab.freedesktop.org/drm/amd/-/issues (needs GitLab account).
TODO from maintainer: exact board model (Sapphire/XFX/PowerColor + card name).

## Title

Navi31 (RX 7900 XT, 0x1002:0x744c): SMU no-response + DMUB status=2 storm on
cold boot; warm boots clean (firmware bisection 20250708-good/20260916-bad)

## Hardware

- GPU: AMD RX 7900 XT 20GB, PCI ID 0x1002:0x744c, VBIOS ATOM
  113-D70401-00 (build 00040781, ver 022.001.002.008.000001, 2022/11/08),
  board vendor: TODO
- Board: ASUS TUF GAMING B650E-PLUS WIFI, BIOS 4004 x86_64 (2026-09-16)
- CPU: Ryzen 5 9600X; RAM 32GB DDR5-6000 (EXPO I); 1TB Kingston NVMe
- Firmware set: Above-4G ON, ReBAR ON (also tested OFF), SVM ON, CSM OFF,
  Secure Boot OFF, Fast Boot OFF

## Software

- Bad: linux-firmware[-amdgpu] 20260916-1, kernels 7.2.8-arch1 AND 6.18.55-1-lts
- Good: linux-firmware[-amdgpu] 20250708-1 (same kernels)
- Bootloader: systemd-boot, LUKS root (btrfs), kernel cmdline otherwise plain

## Symptom

Cold boot (shutdown + drain + power on) hangs ~4s into init: SMU no-response
(`msg_reg: 2d`), JPEG/VCN power-gate failures (ret -62), then endless
`Error queueing DMUB command: status=2` + `dc_dmub_srv_log_diagnostic_data`.
Warm reboots initialize DMUB cleanly (version 0x07003300) every time.
Failed boots leave no journal (hang precedes flush); logs transcribed from
screen. Related: drm/amd#4737 (SMU crashes, firmware 20251125), Arch FS#78968.

## Eliminated

- Missing blobs (dcn_3_2_1_dmcub present in both sets)
- `pcie_aspm=off`, `amd_iommu=off`, ReBAR disabled, LTS kernel — all still loop
- `module_blacklist=amdgpu` boots (framebuffer, no accel): recovery path

## Ask

Confirm whether the SMU/DMCUB blobs changed between 20250708 and 20260916
for gfx1100, and whether #4737's fix covers this path or regressed.
