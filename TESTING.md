# TESTING.md — LuicipherOS v0.1 matrix (started for issue #1)

Scope: target machine (Ryzen 5 9600X + ASUS B650E-PLUS WIFI + RX 7900 XT) +
VM smoke. Compat claim stays limited until target + AMD laptop + Intel
laptop + VM all pass (ADR-0001 consequences).

## 0. Static checks (any machine, no Arch needed)

```bash
bash -n scripts/*.sh install/*.sh && echo STATIC-OK
python3 -m json.tool install/archinstall-desktop.json > /dev/null && echo JSON-OK
python3 -m json.tool install/archinstall-desktop.creds.example.json > /dev/null && echo CREDS-EXAMPLE-OK
./scripts/sync.sh --prune --dry-run   # previews extras, changes nothing
```

## 1. VM smoke (fresh Arch ISO in QEMU/VirtualBox, 4G RAM, 60G disk)

```bash
./install/preflight.sh --vm        # expect PASS (GPU/ReBAR skipped)
# EDIT-ME: install/archinstall-desktop.json -> "device": "/dev/vda", hostname, timezone
cp install/archinstall-desktop.creds.example.json /tmp/creds.json
# fill /tmp/creds.json hashes: openssl passwd -6 'pw'
archinstall --config install/archinstall-desktop.json --creds /tmp/creds.json
# reboot into installed VM, clone repo, then:
./install/bootstrap.sh --preflight-mode=vm --no-flatpak
./scripts/sync.sh --prune --dry-run
```

PASS = reboot reaches Hyprland (uwsm), SUPER+Return opens Tabby,
SUPER+Space opens Vicinae (or fuzzel fallback), Quickshell bar + swaync visible.

## 2. Target machine (Ryzen 9600X + B650E-PLUS WIFI + RX 7900 XT)

Pre-install (Alza checklist — manual, see preflight.sh):

- [ ] BIOS >= mid-2024 AGESA, EXPO enabled, Above-4G + ReBAR enabled
- [ ] 159mm cooler vs 160mm lid, 313mm GPU vs 330mm case, 2x separate 8-pin
- [ ] 2nd SSD planned; refurb report kept

Install:

```bash
./install/preflight.sh --target     # expect PASS; fix FAILs before proceeding
# EDIT-ME: device /dev/nvme0n1, hostname luicipheros, timezone Europe/Prague
archinstall --config install/archinstall-desktop.json --creds /tmp/creds.json
./install/bootstrap.sh --preflight-mode=target
./scripts/sync.sh                   # add-only reconcile
```

Verify (ROCm stack):

```bash
rocminfo | head                    # agents present
python3 -c "import torch; print(torch.cuda.is_available())"  # expect True (ROCm)
blender --background --python-expr "import bpy; print(bpy.context.preferences.addons['cycles'].preferences.compute_device_type)"  # HIP
ollama run llama3.2:3b "1+1"       # ROCm backend serves
hyprctl version                    # >= 0.55 (native Lua config)
vicinae --version || vicinae toggle
quickshell                         # bar renders, no QML errors
gradia --help                      # editor installed (Extra)
Print key -> region -> Gradia opens with the capture
tabby --version && ssh <host>      # no terminfo errors on remote
tabby -e nmtui                     # VERIFY: -e exec flag (fuzzel/swaync rely on it)
```

## 3. sync.sh contract (regression — full TDD suite lands in step 2 of #1)

- `./scripts/sync.sh` installs missing only (deps via `-Qqd` never touched)
- `--prune --dry-run` previews pacman + flatpak-system + flatpak-user extras
- `--prune` asks confirm (unless `--yes`), honors `config/protected-packages`
- system/user flatpak scopes prune independently

## Out of scope (v0.2+)

Quickshell/hyprpanel, Nix layer, custom ISO, NVIDIA hybrid, SecureBoot.
