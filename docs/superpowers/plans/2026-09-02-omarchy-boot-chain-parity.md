# Omarchy Boot Chain Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close remaining Omarchy delta without breaking current silent-boot+hydra stack — add Plymouth PasswordCallback/message handling, fix ReGreet white-flash, optionally wire uwsm, align session env import to Omarchy's systemd user flow.

**Architecture:** Keep systemd-boot + initrd.systemd + Hydra Plymouth (extend script for future LUKS). Keep greetd+ReGreet as default, fix dark handoff; SDDM remains opt-in branch. Add programs.hyprland.withUWSM behind flag. Reuse assets/branding/screensaver.txt as single branding source.

**Tech Stack:** NixOS 26.05, systemd-boot, boot.plymouth script plugin, greetd+ReGreet+cage, optional sddm+catppuccin-sddm, hyprland 0.56.1 Lua, uwsm, quickshell-lock, gvfs+udisks2

**Spec:** Omarchy boot-to-desktop research (Limine→Plymouth→SDDM→Hyprland via uwsm, Plymouth script PasswordCallback, SDDM QML theme, uwsm Exec=uwsm start Hyprland) + prior plans 2026-09-01-silent-boot-plymouth-branding.md and 2026-09-01-fix-hyprland-plymouth-flash.md

## Global Constraints

- machine.nix only for machine values — AGENTS.md:3.3
- Never edit HM ~/.config outputs — edit /etc/nixos source — AGENTS.md:3.1
- Never edit hardware-configuration.nix — AGENTS.md:3.2
- AI preview only via nix flake check --no-build + nix build --dry-run ...toplevel; nh os build is real — human runs rebuild — AGENTS.md:3.4
- Every .nix commit needs CHANGELOG.md line — AGENTS.md:1.1
- No AI co-author trailers — AGENTS.md:2
- /etc/nixos is repo, HTTPS push — AGENTS.md:5
- No LUKS on this machine (lsblk shows ext4 root, vfat /boot, no crypt) — Plymouth PasswordCallback is future-proofing, not active path
- boot.consoleLogLevel=0 + boot.initrd.verbose=false + quiet splash loglevel=3 systemd.show_status=auto remain

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| modules/system/plymouth.nix:30-47 | Modify | Add PasswordCallback + message handling to hydra.script (lock icon/bullets future-proof) |
| configuration.nix:169-218 | Modify | Fix ReGreet flash (dark wallpaper filter) + optional SDDM branch |
| modules/home/hyprland.nix:94-118 | Modify | Optional withUWSM + env import alignment with Omarchy autostart.lua |
| modules/system/storage.nix | Verify | gvfs+udisks2 already replaces udiskie — no change |
| assets/branding/screensaver.txt | Read-only | Single branding source |
| CHANGELOG.md | Modify | Per-commit line |

---

## Current vs Omarchy Delta (audit)

| Stage | Omarchy | Your System | Verdict |
|---|---|---|---|
| Bootloader | Limine Tokyo Night + logo | systemd-boot (no theme) | Keep — systemd-boot is correct for dual-boot; Limine out-of-scope |
| Kernel quiet splash | quiet splash | quiet splash loglevel=3 systemd.show_status=auto | Done (2026-09-01) |
| Plymouth theme | script theme: logo + progress + PasswordCallback lock/bullets | Hydra script: logo + box/bar + SetBootProgressFunction | Done; missing PasswordCallback only matters if LUKS added |
| LUKS | Full-disk LUKS → Plymouth password UI | No LUKS (ext4 root) | No action unless you encrypt |
| Display Manager | SDDM Wayland + omarchy QML (logo/lock/entry images) | greetd+ReGreet Catppuccin Mocha (cage) | Keep ReGreet; SDDM is opt-in — ReGreet flash fix is P1 |
| Session launch | uwsm start Hyprland hyprland.desktop | Hyprland direct via ReGreet session (Exec=start-hyprland) | Optional uwsm via withUWSM flag |
| Autostart | autostart.lua: import env, udiskie, omarchy-launch-shell | hyprland.lua: import WAYLAND_DISPLAY etc + quickshell+walker+tumblerd; gvfs+udisks2+polkit replaces udiskie | Done — equivalent, no omarchy-shell needed |
| Lock | hyprlock/swaylock + PAM | quickshell-lock + hydra-lock PAM + screensaver-only mode | Done — Omarchy-aligned |
| Branding | Omarchy logo Tokyo Night | Hydra ascii (screensaver.txt) #1d2021/#ebdbb2 | Done |

---

### Task 1: Plymouth — add PasswordCallback + message handling (future-proof)

**Files:**
- Modify: /etc/nixos/modules/system/plymouth.nix:30-47
- Test: plymouth theme builds, script contains PasswordCallback

**Interfaces:**
- Consumes: hydraTheme derivation (logo.png/box.png/bar.png already in initrd)
- Produces: hydra.script that handles LUKS prompt if encryption ever added — no behavior change on current unencrypted boot

- [ ] **Step 1: Verify current hydra.script lacks password UI**

```bash
cat /etc/nixos/modules/system/plymouth.nix | grep -c "PasswordCallback\|message_callback"
# expect 0 — confirms gap
ls /nix/store/*plymouth-hydra-theme*/share/plymouth/themes/hydra/hydra.script | head -1 | xargs cat | head -n 50
```

- [ ] **Step 2: Extend hydra.script with Omarchy-style callbacks**

Add to hydra.script after progress_callback (keep existing Window/logo/box/bar):

```js
message.text = "";
message.sprite = Sprite();
message.sprite.SetPosition(Window.GetWidth()/2, Window.GetHeight() * 0.78, 10001);
fun message_callback(text) {
  message.text = text;
}
Plymouth.SetMessageFunction(message_callback);
fun password_callback() {
  box.sprite.SetOpacity(0);
  bar.sprite.SetOpacity(0);
}
Plymouth.SetPasswordFunction(password_callback);
```

Exact Nix edit — append inside the <<'SCRIPT' heredoc before `SCRIPT` delimiter. Keep Window.SetBackground #1d2021 (0.11,0.12,0.13) to match.

- [ ] **Step 3: Dry preview**

```bash
nix flake check /etc/nixos --no-build
nix build --dry-run /etc/nixos#nixosConfigurations.hydragon2000-pc.config.system.build.toplevel
```

Expected: PASS — script API valid (Plymouth.SetPasswordFunction exists in plymouth script plugin).

- [ ] **Step 4: After user rebuild, verify theme in initrd**

```bash
ls /nix/store/*plymouth-hydra-theme*/share/plymouth/themes/hydra/hydra.script | head -1 | xargs grep -q PasswordCallback && echo PASS
ls /nix/store/*plymouth-initrd-themes*/hydra/hydra.script 2>/dev/null | head -1 | xargs grep -q PasswordCallback && echo PASS
```

- [ ] **Step 5: Commit**

```bash
git -C /etc/nixos add modules/system/plymouth.nix CHANGELOG.md
git -C /etc/nixos commit -m "feat: plymouth hydra add PasswordCallback+message — future-proof LUKS prompt"
```

---

### Task 2: ReGreet flash — constrain wallpaper to dark (keep ReGreet, minimal risk)

**Files:**
- Modify: /etc/nixos/configuration.nix:187-218 (regreet-wallpaper service)
- Test: Reboot flash dark→dark instead of dark→light

**Interfaces:**
- Consumes: boot.plymouth #1d2021 background, ReGreet background path /var/lib/regreet/background.png
- Produces: Dark handoff Plymouth #1d2021 → ReGreet dark — eliminates white flashbang without switching DM

Root cause: regreet-wallpaper picks random >100k image from ~/Pictures/wallpapers_flat/* — can be light. Plymouth is dark #1d2021, cage -s -d clears to black, then light wallpaper = flash. Fix: prefer dark images or fallback to dark solid if no dark candidate.

- [ ] **Step 1: Inspect wallpaper pool**

```bash
find ~/Pictures/wallpapers_flat -maxdepth 1 -type f -size +100k | head -n 10
# note light vs dark filenames
cat /etc/nixos/configuration.nix | grep -A2 "regreet-wallpaper"
```

- [ ] **Step 2: Patch regreet-wallpaper to prefer dark**

Option A (minimal): filter candidates by brightness via imagemagick identify -format "%[mean]" or by filename heuristic (dark/night/mocha prefix), fallback to copying a dark default from assets/branding if none. Simplest robust: add `dark` filename filter + fallback to /etc/nixos/assets/branding dark solid:

Add before `pick=` in the ExecStart script:

```bash
# Prefer dark wallpapers (filename contains dark/night/mocha/black) to match Plymouth #1d2021
dark_candidates=()
for f in "''${candidates[@]}"; do [[ "$f" == *dark* || "$f" == *night* || "$f" == *mocha* || "$f" == *black* ]] && dark_candidates+=("$f"); done
if [ ''${#dark_candidates[@]} -gt 0 ]; then candidates=("''${dark_candidates[@]}"); fi
```

If no dark images exist in pool, keep random but document that user should add dark wallpapers to the folder.

Option B (if Task 3 SDDM chosen, skip this).

- [ ] **Step 3: Dry preview**

```bash
nix flake check /etc/nixos --no-build
nix build --dry-run /etc/nixos#nixosConfigurations.hydragon2000-pc.config.system.build.toplevel
```

- [ ] **Step 4: Commit**

```bash
git -C /etc/nixos add configuration.nix CHANGELOG.md
git -C /etc/nixos commit -m "fix: regreet-wallpaper prefer dark to match Plymouth — eliminate white flash"
```

---

### Task 3: SDDM branch (OPT-IN, not default — only if user wants Omarchy login)

**Files:**
- Modify: /etc/nixos/configuration.nix:127-175 (replace programs.regreet with services.displayManager.sddm)
- Test: sddm catppuccin-mocha theme loads, SessionDir correct

**Interfaces:**
- Consumes: hydra Plymouth #1d2021, hyprland session
- Produces: SDDM Wayland greeter with catppuccin-mocha matching Plymouth — alternative to Task 2

Only do this if user explicitly chooses SDDM over ReGreet. Keep as commented alternative if not chosen.

- [ ] **Step 1: Document choice — ask user**

Do not auto-switch. Present both: ReGreet dark fix (Task 2) vs SDDM catppuccin. SDDM code was validated in prior plan (desktops/share/wayland-sessions, extraPackages not systemPackages):

```nix
services.displayManager.sddm = {
  enable = true;
  wayland.enable = true;
  theme = "catppuccin-mocha";
  extraPackages = with pkgs; [ catppuccin-sddm ];
  settings.Theme.FacesDir = "/run/current-system/sw/share/sddm/faces";
  autoNumlock = true;
};
services.displayManager.defaultSession = "hyprland";
# remove programs.regreet + users.greeter + regreet-wallpaper when switching
```

Verify: catppuccin-sddm provides share/sddm/themes/catppuccin-mocha/theme.conf; SessionDir is desktops/share/wayland-sessions via sessionPackages.

- [ ] **Step 2: If chosen, dry preview + verify desktops path**

```bash
nix flake check /etc/nixos --no-build
nix build --dry-run /etc/nixos#nixosConfigurations.hydragon2000-pc.config.system.build.toplevel
# after build: cat /nix/store/...sddm.conf | grep SessionDir # should be desktops/...
```

- [ ] **Step 3: Commit if SDDM chosen**

```bash
git -C /etc/nixos add configuration.nix CHANGELOG.md
git -C /etc/nixos commit -m "feat: switch ReGreet to SDDM catppuccin-mocha — Omarchy login parity"
```

---

### Task 4: uwsm session wrapper (OPT-IN, low priority)

**Files:**
- Modify: /etc/nixos/configuration.nix:93-104 or modules/home/hyprland.nix
- Test: hyprland with uwsm still launches via greetd

**Interfaces:**
- Consumes: programs.hyprland.enable
- Produces: programs.hyprland.withUWSM = true — Omarchy's `uwsm start Hyprland` equivalent

Omarchy: Exec=uwsm start -g -1 -e -D Hyprland. NixOS equivalent is `programs.hyprland.withUWSM = true` which wraps the session. Not required — current direct launch works; uwsm mainly helps env import for systemd user. Your hyprland.lua already does `systemctl --user import-environment WAYLAND_DISPLAY...` so parity is close.

- [ ] **Step 1: Add withUWSM behind flag (default off)**

```nix
programs.hyprland.withUWSM = false; # flip to true if testing Omarchy session flow
```

Or wire via machine.nix bool if you want per-machine.

- [ ] **Step 2: Dry preview**

```bash
nix flake check /etc/nixos --no-build
nix build --dry-run /etc/nixos#nixosConfigurations.hydragon2000-pc.config.system.build.toplevel
```

- [ ] **Step 3: Commit if enabled**

```bash
git -C /etc/nixos add configuration.nix CHANGELOG.md
git -C /etc/nixos commit -m "feat: add withUWSM flag — Omarchy session parity opt-in"
```

---

### Task 5: Verify autostart parity (no code change, just confirm)

Checklist — no Nix edits, just verify current matches Omarchy's autostart.lua intent:

- [ ] **Step 1: Confirm gvfs+udisks2 covers udiskie**

```bash
systemctl status udisks2 | head
systemctl --user status | grep -i gvfs || echo "gvfs is system service, not user — ok"
# Thunar automount via gvfs+udisks2 already enabled in configuration.nix:254-255 — better than udiskie
```

- [ ] **Step 2: Confirm env import covers omarchy's import-environment**

```bash
grep -r "import-environment" /etc/nixos/modules/home/hyprland.nix
# should show WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE MOZ_ENABLE_WAYLAND
```

- [ ] **Step 3: Confirm quickshell bar + lock cover omarchy-launch-shell**

```bash
systemctl --user status quickshell hydra-lock-shell | head -n 30
```

No commit — verification only.

---

### Task 6: Final rebuild + validation

- [ ] **Step 1: User rebuild (TTY, not from Hyprland)**

```bash
rebuild
reboot
grep -q quiet /proc/cmdline && echo PASS
systemctl --failed | head
journalctl -b -p warning | head -n 20
# Plymouth still shows hydra logo + bar filling 0→100%
# ReGreet shows dark wallpaper, no white flash
# Hyprland no scroll, immediate desktop
```

- [ ] **Step 2: Commit docs**

```bash
git -C /etc/nixos add docs/superpowers/plans/2026-09-02-omarchy-boot-chain-parity.md CHANGELOG.md
git -C /etc/nixos commit -m "docs: omarchy boot chain parity plan — plymouth callbacks, regreet dark, uwsm opt-in"
```

