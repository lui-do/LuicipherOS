# iso/ — LuicipherOS netinstall image (archiso profile)

Builds a small bootable ISO that fetches this repo over the network and
runs the unattended install flow (`luicipheros-install`). Packages are
NEVER baked in — every install gets current packages (rolling-release
correctness; a full offline image with Tabby + ROCm would be gigabytes
and stale within weeks).

## Build (on Arch with mkarchiso)

```bash
sudo pacman -S --needed archiso
cp /etc/pacman.conf iso/pacman.conf   # host mirror pool, not shipped (rots)
sudo mkarchiso -v -w /tmp/luici-iso-tmp -o out/ iso/
# artifact: out/luicipheros-netinstall-*.iso — flash with dd/Etcher/Ventoy
```

## Test (same bar as the manual smoke)

Boot the artifact in the QEMU/OVMF VM (4G RAM, 60G disk, UEFI), then:

```bash
luicipheros-install --vm
```

Expect: preflight PASS -> EDIT-ME pointers -> archinstall runs the JSON.
First ISO boot that reaches `archinstall` = ISO smoke PASS.

## Layout

```
iso/profiledef.sh              archiso profile (releng-based, UEFI+BIOS boot)
iso/packages.x86_64            live-env only: archinstall, git, network, disk tools
iso/airootfs/usr/local/bin/luicipheros-install   live entry point (preflight -> repo -> archinstall)
iso/airootfs/etc/motd          points at the installer
```

## Status

UNTESTED artifact (no mkarchiso in this container; first build happens on
the target-side Arch host). Do not publish under Releases until one VM
boot of the built ISO reaches archinstall.
