# Warm reboot hangs UEFI POST — investigation (Nov 2026)

Symptom: `sudo reboot` results in no ASUS logo, no boot menu, no keyboard (Caps Lock dead)
= UEFI POST never completes. Cold boot (poweroff → power button) always works.

This is a **separate issue** from the DMUB cold-boot storm
(see `docs/dmub-coldboot-casefile.md`) and from the spontaneous `0x00800800` resets.

## Verified facts (2026-11-16)

### Boot entries on the ESP

| Entry | Origin | Options (root part) | GPU params |
|---|---|---|---|
| `2026-10-04_17-11-07_linux.conf` ("Arch Linux (linux)") | archinstall-generated | `cryptdevice=PARTUUID=3eea…:root root=/dev/mapper/root zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs` | `amdgpu.runpm=0` |
| `arch-lateload.conf` | hand-written | **identical root params** | + `amdgpu.ppfeaturemask=0xffff7fff modprobe.blacklist=amdgpu` (+ `reboot=c` since 2026-11-15) |
| `arch-lts.conf` | hand-written | same root params | none |

`loader.conf`: `default arch-lateload.conf`, `timeout 3`.

### Initramfs state

- `initramfs-linux.img` built **2026-11-15 13:55:20** (kernel 7.3.4-arch1-2 install).
- Contains the unlock tooling: `hooks/encrypt`, `usr/bin/cryptsetup` (3 cryptsetup entries).
- `pacman.log`: no `command failed to execute` in any recent transaction → the build succeeded.
- `/etc/mkinitcpio.conf`: `HOOKS=(base udev autodetect microcode modconf kms keyboard keymap
  consolefont block encrypt filesystems fsck)` — busybox `encrypt` hook, **not** `sd-encrypt`.
  Therefore `cryptdevice=` is the correct syntax on this system.
- ESP: 133 M used of 1022 M (890 M free).

### Kernel/mkinitcpio versions

`linux 7.3.4-arch1-2`, `mkinitcpio 42.2-1`, `cryptsetup 2.8.8-2`, `systemd 262.2-1`.

### LUKS panic (three occurrences, 2026-11-16 22:24 / 22:26 / 22:42)

```
VFS: Cannot open root device "/dev/mapper/root" or unknown-block(0,0): error -19
Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)
```

- Happens at ~1.6–2.5 s, i.e. before any GPU driver (amdgpu first prints at ~179 s).
- `error -19` = ENODEV: the mapper device was never created.
- Occurred while `arch-lateload.conf` carried the Phase-2 experiment params
  (`amdgpu.tmz=0 amdgpu.sg_display=0 amdgpu.dcdebugmask=0x10 iommu=soft`) — and only on that
  entry; the archinstall entry booted with the **same** initramfs and **same** root params.
- The panic report's log begins at ~0.49 s (front-truncated), so absence of a passphrase prompt
  in the capture does NOT prove the prompt never appeared.

### Disproved hypotheses

1. **Wrong LUKS hook family** — false. `HOOKS` uses busybox `encrypt`; `cryptdevice=` is correct.
2. **Broken/stale initramfs** — false. Built successfully 13:55, contains `cryptsetup`,
   no failed package hooks.
3. **Different initrd per entry** — false. All non-LTS entries use `/initramfs-linux.img`.
4. **Entry differs in root/LUKS params** — false. Root params are byte-identical between
   the archinstall entry and `arch-lateload.conf`.

### Leading suspect for the panic

`iommu=soft` is the only Phase-2 param that can affect early userspace (it changes IOMMU
handling for all DMA, before LUKS unlock). Unverified. It stays out of the boot line.

## Warm-reboot evidence so far

| When | From which entry | Result |
|---|---|---|
| 2026-11-12 | (pre-unload-unit era) | POST fine |
| 2026-11-15 | `arch-lateload` + unload unit + MCR off | hung |
| 2026-11-15 | `arch-lateload` + unload unit + MCR off + `reboot=c` (from reboot=c kernel) | hung |
| 2026-11-16 | `Arch Linux (linux)` (archinstall entry) | **POST fine, logo + menu appeared** |
| 2026-11-17 | archinstall entry, unload unit **enabled** | hung (no logo, no menu) |
| 2026-11-17 | archinstall entry, unload unit **disabled** | hung (no logo, no menu) — **unit exonerated** |

Note: from 2026-11-17 the hang has been observed from **both** entries, so the boot entry is
not the variable — the failure is at POST/firmware level, before any loader entry is read.
The 2026-11-16 success is therefore best treated as intermittent, not as evidence about a
specific entry.

### Hypothesis: the unload unit causes the hang

`amdgpu-unload-on-shutdown.service` removes the module at shutdown. That skips
`amdgpu_pci_shutdown()` — the driver's own quiesce + device reset. Left unfired, the GPU may be
handed to UEFI in a state that breaks GOP init on a warm reset. A cold boot works because the
PSU cycle resets the card in hardware.

Supporting: warm reboots were fine before the unit existed; every warm reboot with it enabled
hung; the one recent success came from a path that had not previously been tested with it.

Status: **hypothesis, unverified** — one controlled test decides it.

**Result 2026-11-17: DISPROVED.** With the unit disabled (driver left loaded, so
`amdgpu_pci_shutdown()` runs normally) the warm reboot still hung. Driver unload timing is
therefore not the trigger. Everything on the software side of the shutdown path is now cleared:
both entries hang, with and without the unload unit, with and without the GPU loaded at reset.

## Note on the late-load design

`/etc/modprobe.d/amdgpu-coldboot.conf` already contains `blacklist amdgpu`, so amdgpu never
autoloads on **any** entry; `amdgpu-late.service` is what loads it ~150 s after boot. The
`modprobe.blacklist=amdgpu` kernel parameter is therefore redundant, and a hand-written entry
duplicates what the archinstall entry + modprobe.d + unit already do. Planned simplification
(after the tests): move `ppfeaturemask`/`runpm` into modprobe.d options and let one entry exist.

## Test plan (one variable at a time)

1. Default the boot entry to the known-good archinstall entry.
2. Boot it, then warm reboot with the unload unit **enabled** → record result.
3. `systemctl disable amdgpu-unload-on-shutdown`, warm reboot again → record result.
4. If step 3 fixes it: retire the unit (or keep it disabled) and document.
   If not: next levers are BIOS `PCIEX16(G5) Link Mode → Gen4`, then `IOMMU → Disabled`.

Record for every attempt: logo yes/no, Caps Lock alive yes/no, and afterwards
`journalctl -b -1 | grep amdgpu-unload` and
`journalctl -k -b | grep 'Previous system reset'`.
