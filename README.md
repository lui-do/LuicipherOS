# LuicipherOS (v0.1 scaffold)

Arch-based, Hyprland-first, keyboard-driven OS-config. Target-tuned for Ryzen 5 9600X + RX 7900 XT, compatible with most Arch-supported laptops/desktops. Inspired by Omarchy and ML4W — borrow patterns, don't fork.

## Big ideas (annotated, see files)

1. **Declarative apps without NixOS** (see `config/`, `scripts/sync.sh`, ADR-0001):
   - `config/packages` (pacman) + `config/packages-arch` (AUR) + `config/flatpaks.list` are source of truth.
   - `luci sync` = install missing only. `luci sync --prune` = + uninstall extras (confirm + `protected-packages` guard).
   - Reboot does nothing by itself; systemd units in `install/` are opt-in.
   - Hyprland/lock/portals/drivers stay pacman-owned (PAM/SUID + GL traps).

2. **Hardware: efficient single-GPU tower, AMD caveats**:
   - 20GB VRAM fits ≤24B Q4 fully, 32B tight. 70B needs second machine.
   - ROCm on Arch works (PyTorch/Ollama/llama.cpp-Vulkan/Blender-HIP) but 10-40% behind CUDA on diffusion.
   - Verify: BIOS+EXPO+ReBAR, 159mm cooler vs 160mm lid, 313mm GPU vs 330mm case, 2x separate 8-pin, refurb report, 2nd SSD soon.

3. **v0.1 scope (to be locked in grill)**:
   - `archinstall` JSON + `bootstrap.sh` + dotfiles (Hyprland Lua, Waybar, fuzzel, kitty, hyprlock/idle).
   - OUT: Quickshell theming, Nix home-manager, custom ISO, NVIDIA hybrid, SecureBoot.

## Layout (v0.1)

```
config/packages config/packages-arch config/flatpaks.list config/protected-packages
scripts/ensure-packages.sh scripts/ensure-flatpaks.sh scripts/sync.sh
install/archinstall-desktop.json install/bootstrap.sh install/preflight.sh
dotfiles/hypr/ CONTEXT.md docs/adr/
```

## Usage

```bash
./scripts/sync.sh                 # add-only
./scripts/sync.sh --prune         # + remove extras (confirm)
./scripts/sync.sh --prune --dry-run  # preview only
chmod +x scripts/*.sh install/*.sh
```

## Roadmap

- v0.1: target-machine installer + dotfiles + sync (2-4 wks)
- v0.2: hardware profiles (laptop-amd/intel, desktop-7900xt), power/HiDPI
- v0.3: optional Nix layer, `luci sync` as binary, CI + VM test matrix

## License

MIT — see `LICENSE`. This covers the original files in this repo (scripts, configs, dotfiles, docs).
Third-party software installed via these lists (Arch packages, AUR, Flatpaks, Hyprland) keeps its own
upstream licenses. LuicipherOS is based on Arch Linux and is not an official Arch product.
