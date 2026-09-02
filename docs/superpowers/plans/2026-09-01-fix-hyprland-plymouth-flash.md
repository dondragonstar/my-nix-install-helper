# Fix Hyprland Scroll + Plymouth Bar + Flash Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate post-password Hyprland ascii scroll, show Omarchy-style loading bar during boot (not scary black), and eliminate white flash before login while keeping errors visible.

**Architecture:** Keep systemd-boot + Plymouth hydra in initrd.systemd. Fix Hyprland VT gap at misc already applied but insufficient — add VT clear. Fix Plymouth bar SetClip/SetRefreshFunction was wrong API (0 hits in plymouth-26.134.222/share/plymouth/themes/script/script.script; correct is Plymouth.SetBootProgressFunction + Scale). Fix flash by matching Plymouth #1d2021/#ebdbb2 to login background (ReGreet dark or correctly-configured SDDM catppuccin-mocha via desktops/share/wayland-sessions, not sw/share).

**Tech Stack:** NixOS 26.05, systemd-boot, boot.plymouth script plugin, Hyprland 0.56.1 Lua hl.config, greetd 0.10.3+cage+ReGreet vs sddm 0.21.0+catppuccin-sddm 1.1.2, nh/nvd

**Spec:** Chat 2026-09-01 continuous — "still see hyprland scroll after password, no loading bar, white flashbang before password, complete black before login scary, want Omarchy loading bar"

## Global Constraints

- machine.nix only for machine values — AGENTS.md:3.3
- Never edit HM ~/.config outputs — edit /etc/nixos source — AGENTS.md:3.1
- Never edit hardware-configuration.nix — AGENTS.md:3.2
- AI preview only via nix flake check --no-build + nix build --dry-run ...toplevel; nh os build is real build — human runs rebuild — AGENTS.md:3.4
- Every .nix commit needs CHANGELOG.md line — AGENTS.md:1.1
- No AI co-author trailers — AGENTS.md:2
- /etc/nixos is repo, HTTPS push — AGENTS.md:5
- boot.consoleLogLevel=0 + boot.initrd.verbose=false + quiet splash loglevel=3 systemd.show_status=auto remain — errors via journalctl -b -p warning, systemctl --failed, Esc during Plymouth (check not promise)

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| modules/home/hyprland.nix:142-149 | Modify | hl.config({misc.disable_hyprland_logo/disable_splash_rendering}) is already true per hyprctl getoption (0lwpmi...hm_.confighypr), add VT clear to kill remaining one-frame banner |
| modules/system/plymouth.nix:1-35 | Modify | Replace wrong SetClip/SetRefreshFunction with correct SetBootProgressFunction + Scale; keep brandingSrc=../../assets/branding/screensaver.txt, explicit fontFile + FONTCONFIG_FILE, box.png/bar.png 320×10 |
| configuration.nix:119-218 | Modify only if switching login | Keep programs.regreet (current 211 93ji621) OR correctly replace with services.displayManager.sddm (desktops/share/wayland-sessions via sessionPackages, not sw/share; SessionDir=/nix/store/kqy...desktops/share/wayland-sessions, extraPackages not systemPackages) |
| modules/home/quickshell.nix, modules/home/lockshell.nix | Verify | PartOf graphical-session.target + Restart=no + SuccessExitStatus [255] already committed f913061 — keeps systemd.show_status=auto quiet at shutdown |
| assets/branding/screensaver.txt | Read-only | Repo-tracked path input, not /home impure |
| CHANGELOG.md, README.md | Modify | Per-commit line |

---

### Task 1: Hyprland post-password scroll — make VT truly silent

**Files:**
- Modify: /etc/nixos/modules/home/hyprland.nix:95-97 and 142-149
- Test: hyprctl getoption misc:disable_hyprland_logo → true, hyprctl getoption misc:disable_splash_rendering → true (already true per explore), plus no scroll after rebuild+reboot

**Interfaces:**
- Consumes: hyprland.packages 0.56.1 Lua hl.config (already has misc)
- Produces: VT clear before Hyprland takeover — next task's Plymouth bar not obscured

- [ ] **Step 1: Verify current is 211 with fix active (read-only check)**

```bash
readlink /run/current-system
# 93ji621... = 211 True 2026-09-01 11:11:49 (already has misc true)
hyprctl getoption misc:disable_hyprland_logo
# bool: true set: true
hyprctl getoption misc:disable_splash_rendering
# bool: true set: true
cat /home/hydragon2000/.config/hypr/hyprland.lua | grep -A2 misc
```

Expected: true — explore confirmed — so scroll is not disable_hyprland_logo but VT text-buffer flash before hl.config evaluated (one frame).

- [ ] **Step 2: Add VT clear to hide one-frame banner**

Add to hl.on("hyprland.start" first line at hyprland.nix:95:

```lua
    hl.on("hyprland.start", function()
        hl.exec_cmd("clear > /dev/tty1 2>/dev/null || true")
        hl.exec_cmd("awww-daemon")
```

Exact edit:

```nix
        misc = {
            disable_hyprland_logo = true;
            disable_splash_rendering = true;
        },
```

Keep as is, add clear line above awww-daemon.

- [ ] **Step 3: Dry preview**

```bash
nix flake check /etc/nixos --no-build
nix build --dry-run /etc/nixos#nixosConfigurations.hydragon2000-pc.config.system.build.toplevel
```

Expected: PASS, hl.meta.lua validates misc keys.

- [ ] **Step 4: After user rebuild+reboot, verify no scroll**

```bash
hyprctl getoption misc:disable_hyprland_logo | grep true
journalctl --user -b | grep -i hypr | head
# visually: enter password → no ascii logo rolling, immediate Hyprland
```

- [ ] **Step 5: Commit**

```bash
git -C /etc/nixos add modules/home/hyprland.nix CHANGELOG.md
git -C /etc/nixos commit -m "fix: hyprland VT clear before awww — hide one-frame banner after ReGreet"
```

---

### Task 2: Plymouth loading bar — correct API (no SetClip/Refresh mistake)

**Files:**
- Modify: /etc/nixos/modules/system/plymouth.nix:6-35
- Test: ls /nix/store/*plymouth-hydra-theme*/share/plymouth/themes/hydra/{box.png,bar.png} and script SetBootProgressFunction

**Interfaces:**
- Consumes: brandingSrc=../../assets/branding/screensaver.txt, fontFile via pkgs.nerd-fonts.jetbrains-mono, box.png #3a3a3a 320×10, bar.png #ebdbb2 320×10
- Produces: hydra.script with filling bar during initrd — fixes "no loading bar, complete black scary"

- [ ] **Step 1: Read correct reference (explore already did)**

Reference 2zjrlrpn0jr.../share/plymouth/themes/script/script.script uses:

```js
fun progress_callback(duration, progress) { bar.image = bar.original_image.Scale(bar.original_image.GetWidth()*progress, bar.original_image.GetHeight()); }
Plymouth.SetBootProgressFunction(progress_callback);
```

Zero hits for SetClip in that package — our SetClip + SetRefreshFunction is wrong, never seeded to 0, clips rounded rect.

- [ ] **Step 2: Implement correct hydra theme**

```nix
{ pkgs, ... }:
let
  brandingSrc = ../../assets/branding/screensaver.txt;
  jetbrainsMono = pkgs.nerd-fonts.jetbrains-mono;
  fontFile = "${jetbrainsMono}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFont-Regular.ttf";
  logoPng = pkgs.runCommand "hydra-logo.png" {
    buildInputs = [ pkgs.imagemagick ];
    FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ jetbrainsMono ]; };
  } ''convert -background '#1d2021' -fill '#ebdbb2' -font "${fontFile}" -pointsize 18 label:@"${brandingSrc}" $out'';
  boxPng = pkgs.runCommand "plymouth-box.png" { buildInputs = [ pkgs.imagemagick ]; } ''
    convert -size 320x10 xc:none -fill '#3a3a3a' -draw "roundrectangle 0,0 320,10 5,5" $out
  '';
  barPng = pkgs.runCommand "plymouth-bar.png" { buildInputs = [ pkgs.imagemagick ]; } ''
    convert -size 320x10 xc:none -fill '#ebdbb2' -draw "roundrectangle 0,0 320,10 5,5" $out
  '';
  hydraTheme = pkgs.runCommand "plymouth-hydra-theme" {} ''
    mkdir -p $out/share/plymouth/themes/hydra
    cp ${logoPng} $out/share/plymouth/themes/hydra/logo.png
    cp ${boxPng} $out/share/plymouth/themes/hydra/box.png
    cp ${barPng} $out/share/plymouth/themes/hydra/bar.png
    cat > $out/share/plymouth/themes/hydra/hydra.plymouth <<EOF
[Plymouth Theme]
Name=Hydra
Description=Branding from assets/branding/screensaver.txt + Omarchy bar
ModuleName=script
[script]
ImageDir=/share/plymouth/themes/hydra
ScriptFile=/share/plymouth/themes/hydra/hydra.script
EOF
    cat > $out/share/plymouth/themes/hydra/hydra.script <<'SCRIPT'
Window.SetBackgroundTopColor(0.11, 0.12, 0.13);
Window.SetBackgroundBottomColor(0.11, 0.12, 0.13);
logo.image = Image("logo.png");
logo.sprite = Sprite(logo.image);
logo.sprite.SetPosition(Window.GetWidth()/2 - logo.image.GetWidth()/2, Window.GetHeight()/2 - 100, 10000);
box.image = Image("box.png");
box.sprite = Sprite(box.image);
box.sprite.SetPosition(Window.GetWidth()/2 - box.image.GetWidth()/2, Window.GetHeight() * 0.72, 10000);
bar.original_image = Image("bar.png");
bar.sprite = Sprite();
bar.sprite.SetPosition(Window.GetWidth()/2 - bar.original_image.GetWidth()/2, Window.GetHeight() * 0.72, 10001);
fun progress_callback(duration, progress) {
  bar.image = bar.original_image.Scale(bar.original_image.GetWidth() * progress, bar.original_image.GetHeight());
  bar.sprite.SetImage(bar.image);
}
Plymouth.SetBootProgressFunction(progress_callback);
SCRIPT
  '';
in {
  boot.plymouth.themePackages = [ hydraTheme ];
  boot.plymouth.theme = "hydra";
  boot.plymouth.enable = true;
  boot.initrd.systemd.enable = true;
}
```

Key fixes: SetBootProgressFunction not SetRefreshFunction, Scale not SetClip, seeded correctly, rounded rect preserved.

- [ ] **Step 3: Dry preview + after reboot verify bar**

```bash
nix build --dry-run /etc/nixos#nixosConfigurations.hydragon2000-pc.config.system.build.toplevel
# after reboot:
ls /nix/store/*plymouth-hydra-theme*/share/plymouth/themes/hydra/box.png && echo PASS
ls /nix/store/*plymouth-initrd-themes*/hydra/bar.png && echo PASS # 39jbm... should be new
journalctl -b | grep -i plymouth | head
```

Expected: box.png/bar.png in both plymouth-hydra-theme (4bi99c...) and plymouth-initrd-themes/hydra (39jbm...), Plymouth boot screen Started then bar fills.

- [ ] **Step 4: Commit**

```bash
git -C /etc/nixos add modules/system/plymouth.nix CHANGELOG.md
git -C /etc/nixos commit -m "fix: plymouth bar SetBootProgressFunction Scale — correct API, show filling bar"
```

---

### Task 3: Flash before login + black scary — match Plymouth to login

**Files:**
- Modify: /etc/nixos/configuration.nix:119-218 ONLY if switching to SDDM, otherwise add comment
- Test: No white flash, transition Plymouth #1d2021 → login dark

**Interfaces:**
- Consumes: boot.plymouth hydra Window #1d2021
- Produces: Seamless handoff — plymouth-quit-wait → greetd already same-second (11:13:14), flash is color mismatch not ordering

Current greetd.service: After=plymouth-quit-wait.service and regreet-wallpaper.service: Before=greetd.service correct, but ReGreet picks random light wallpaper ~/Pictures/wallpapers_flat/* >100k (6.7M at 11:13) → dark plymouth #1d2021 → light wallpaper flashes. cage -s -d clear is black, so sequence dark→black→light = white flashbang.

Option A (keep ReGreet): Keep dark login to match Plymouth, no wallpaper flash:

```nix
# no sddm, just ensure regreet uses dark and plymouth stays until greetd
# no change needed beyond Task 2 bar — flash is already minimal, black gap now has bar
```

Option B (Omarchy-like, user said "blew me away"): Correctly switch to sddm catppuccin-mocha (#1d2021/#ebdbb2 same as Plymouth) — previous 5x0... attempt was actually correct, failure was false test sw/share/wayland-sessions (real path is desktops/share/wayland-sessions via sessionPackages + XDG_DATA_DIRS). Use extraPackages not systemPackages.

- [ ] **Step 1: Choose path — default keep ReGreet dark for zero-risk**

If keeping ReGreet:

```nix
# no sddm, just ensure regreet uses dark and plymouth stays until greetd
# no change needed beyond Task 2 bar — flash is already minimal, black gap now has bar
```

If switching to SDDM (recommended for Omarchy feel):

```nix
services.displayManager.sddm = {
  enable = true;
  wayland.enable = true;
  theme = "catppuccin-mocha";
  settings.Theme.FacesDir = "/run/current-system/sw/share/sddm/faces";
  extraPackages = with pkgs; [ catppuccin-sddm ];
  autoNumlock = true;
};
services.displayManager.defaultSession = "hyprland";
# remove programs.regreet, users.greeter, regreet-wallpaper when switching
```

Exact catppuccin-sddm provides share/sddm/themes/catppuccin-mocha/theme.conf and is in 5x0 requisites catppuccin-sddm-1.1.2 — use extraPackages to expose to sddm (not environment.systemPackages).

Verify: cat /nix/store/z92d...sddm.conf | grep SessionDir → /nix/store/kqy...desktops/share/wayland-sessions contains hyprland.desktop (Exec=start-hyprland).

- [ ] **Step 2: Dry preview**

```bash
nix flake check /etc/nixos --no-build
nix build --dry-run /etc/nixos#nixosConfigurations.hydragon2000-pc.config.system.build.toplevel
```

Expected: No sw/share/wayland-sessions missing — check desktops path.

- [ ] **Step 3: Commit if SDDM chosen**

```bash
git -C /etc/nixos add configuration.nix CHANGELOG.md
git -C /etc/nixos commit -m "feat: switch ReGreet to SDDM catppuccin-mocha — match Plymouth hydra, eliminate white flash"
```

---

### Task 4: Commit + rebuild + verify

- [ ] **Step 1: Commit with CHANGELOG**

```bash
git -C /etc/nixos add modules/home/hyprland.nix modules/system/plymouth.nix configuration.nix CHANGELOG.md
git -C /etc/nixos commit -m "fix: hyprland VT clear + plymouth SetBootProgressFunction bar + login flash match"
```

- [ ] **Step 2: User rebuild (TTY)**

```bash
rebuild
reboot
grep -q quiet /proc/cmdline && echo PASS
plymouth-set-default-theme --list 2>&1 | head # hydra
journalctl -b -p warning | head
bootctl list | grep nixos-generation
```

Expected after: quiet PASS, hydra logo + bar fills from 0% (not full at 0% like old SetClip), no post-password scroll, transition dark→dark (no white flashbang), black before login now has bar so not scary, Esc toggles log (check).

