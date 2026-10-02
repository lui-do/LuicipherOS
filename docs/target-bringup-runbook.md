# Target bring-up runbook — Ryzen 5 9600X + ASUS B650E-PLUS WIFI + RX 7900 XT

From cables to running LuicipherOS. Assumes the install USB holds our
netinstall ISO (see `iso/README.md`) and the repo is pushed.

## 0. Physical (before first power-on)

- [ ] Inventory vs Alza list; photo RAM + PSU labels.
- [ ] GPU: 2x SEPARATE PCIe 8-pin cables (no daisy-chain pigtail).
- [ ] Clearances: GPU <= 330 mm, cooler <= 160 mm, 2nd SSD mounted if present.
- [ ] Monitor -> GPU's own port (HDMI ok for install; DP cable later for
      high refresh). NOT the motherboard HDMI (weak iGPU).
- [ ] Keyboard, mouse, install USB inserted.

## 1. BIOS (Del on boot, F7 Advanced Mode)

Report first: BIOS version+date (>= mid-2024 AGESA?), CPU string, RAM
capacity/speed as detected.

| Path | Setting |
|---|---|
| Ai Tweaker → Ai Overclock Tuner | EXPO I (not Tweaked) |
| Advanced → PCI Subsystem Settings | Above 4G Decoding: Enabled, then Re-Size BAR: Enabled |
| Advanced → CPU Configuration | SVM Mode: Enabled (VM dev future) |
| Boot → CSM | Disabled (pure UEFI) |
| Boot → Secure Boot | Disabled / Other OS (systemd-boot unsigned) |
| Boot → Fast Boot | Disabled (keeps USB boot visible) |
| Boot Option #1 | Install USB |

Leave: fTPM default, PBO/curve (weeks later), fan curves (default).
F10 Save & Exit.

## 2. Live boot + preflight

```bash
ls /sys/firmware/efi && echo EFI-OK
git clone https://github.com/lui-do/LuicipherOS.git ~/LuicipherOS && cd ~/LuicipherOS
git pull
cp iso/airootfs/usr/local/bin/luicipheros-install /usr/local/bin/luicipheros-install
./install/preflight.sh --target   # must PASS; fix FAILs first
```

## 3. Disks (READ before writing — 2 SSDs likely)

```bash
lsblk -d -o NAME,SIZE,MODEL
```

- System disk is usually `/dev/nvme0n1`; with two SSDs, match by SIZE.
  Script defaults to nvme0n1 — speak up if yours differs. Wrong disk =
  wiped data disk. No guessing.
- btrfs size (manual until issue #2): set JSON value to (disk GiB - 2).

## 4. Install

```bash
luicipheros-install   # no --vm. creds prompt, keyring ensure automatic
```

~5-10 min on NVMe. Reboot into the disk (fix boot order), log in as luci.

## 5. Bootstrap (FULL: Flatpaks included on real hardware)

```bash
git clone https://github.com/lui-do/LuicipherOS.git && cd LuicipherOS
sudo -v; while true; do sudo -n true 2>/dev/null || break; sleep 45; done &
./install/bootstrap.sh
kill %1 2>/dev/null
```

Snapshot hint (ADR-0001): snapper/timeshift checkpoint before first sync.

## 6. Verify

Desktop five: bar renders, SUPER+T Tabby, SUPER+Space Vicinae,
SUPER+N swaync, Print region -> Gradia editor.
ROCm: `rocminfo`, `python3 -c "import torch; print(torch.cuda.is_available())"`
expect True, Blender HIP device, `ollama run llama3.2:3b "1+1"`.
Office: `lpstat -p`, LibreOffice opens a .docx.
Portals (Flatpak file upload): from a Flatpak app (e.g. Slack), attach a
file — the GTK file dialog MUST open. If not: `XDG_CURRENT_DESKTOP`
should be `Hyprland`, and `systemctl --user status xdg-desktop-portal*`
must show the hyprland + gtk backends. (yazi can NOT serve upload
dialogs — portal picker only; yazi stays the keyboard file manager.)
Fonts: `yay -Ss ttf-ms-fonts ttf-aptos` -> add winners to lists.

Green across = close issue #1.

## 7. If stuck

- No EFI -> firmware row back to UEFI (VM lesson, same on hardware).
- archinstall JSON errors -> AGENTS.md field notes (sector_size, units,
  esp flag) + `python3 -m json.tool` validation.
- Mirror flakes -> rewrite `/etc/pacman.d/mirrorlist` with geo +
  `pacman -Syy`; keyring trouble -> SigLevel-Never rescue (see wiki 04).
- AUR build stalls -> yay v13 `--answer* None` flags are in
  `scripts/ensure-packages.sh`; source builds OOM small machines
  (prefer *-bin).
