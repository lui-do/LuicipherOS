# HyprCapture trial (reversible experiment — defaults untouched)

Goal: decide grim+slurp->Gradia (current) vs HyprCapture, by feel.
No AUR package exists; install is via hyprpm (builds the plugin locally).
ABI-sensitive: must match the running Hyprland (0.56.x here).

## Try (all reversible)

```bash
sudo pacman -S --needed --noconfirm cmake cpio   # hyprpm build deps
```

Add to `lua/` config (temporarily — remove after the trial):

```lua
hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")
```

```bash
hyprpm update
hyprpm add https://github.com/gfhdhytghd/HyprCapture
hyprpm enable hyprcapture
hyprpm reload
```

Temporarily rebind Print to the overlay (restore our bind after):

```lua
-- hl.bind("Print", hl.dsp.exec_cmd("hyprctl dispatch hyprcapture:open"))
```

## Judge on

1. Does it build on our exact Hyprland? (commit_pins may lag behind.)
2. Overlay feel: region / window / fullscreen selection vs slurp.
3. Gradia handoff: can a capture still open in Gradia for beautify?
4. Recording: region/window/fullscreen quality (gpu-screen-recorder backend).
5. Stability across a day (it's 4 months old).

## Revert (either verdict)

```bash
hyprpm remove hyprcapture   # exact command per hyprpm docs at trial time
```

Restore the Print bind, remove the permission line. If it WINS, the
follow-up is: pin packaging (hyprpm in lists? docs?), rewire binds,
keep Gradia as the editor. If it LOSES, delete this file.

## Standing decisions (not up for trial)

- Screen RECORDERS are never default (OpenScreen Recorder self-installed
  later; anti-bloat). Only the screenshot side is being judged here.
