# Silent Boot Plymouth Branding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Silent boot till greetd/ReGreet password UI, errors remain reportable, Omarchy-style Plymouth branding from screensaver.txt.

**Architecture:** Keep systemd-boot (UEFI dual-Windows, `configuration.nix:11`). Silent params `quiet loglevel=3 systemd.show_status=auto rd.udev.log_level=3` + `boot.plymouth` in `initrd.systemd` holds framebuffer till greetd/cage paints (fixes D7 flash). Theme built as Nix derivation from repo-tracked `assets/branding/screensaver.txt` with explicit font file — no impure /home eval.

**Tech Stack:** NixOS 26.05, systemd-boot, boot.plymouth script plugin, boot.initrd.systemd, pkgs.imagemagick, pkgs.nerd-fonts.jetbrains-mono, nh, nix build --dry-run

**Spec:** Chat 2026-09-01 + Omarchy branding (preview/set/reset, `~/.config/branding/screensaver.txt` 9-line ascii)

## Global Constraints

- `machine.nix` only for machine values — AGENTS.md:3.3
- Never edit HM `~/.config` outputs — edit `/etc/nixos` source — AGENTS.md:3.1
- Never edit `hardware-configuration.nix` — AGENTS.md:3.2
- AI preview only via `nix flake check --no-build` + `nix build --dry-run ...toplevel`; `nh os build` is real build, not dry-run — human runs `rebuild` — AGENTS.md:3.4
- Every `.nix` commit needs `CHANGELOG.md` line — AGENTS.md:1.1
- No AI co-author trailers — AGENTS.md:2
- `/etc/nixos` is repo, HTTPS push — AGENTS.md:5

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `configuration.nix:9-15` | Modify | `boot.consoleLogLevel`, `boot.initrd.verbose`, `boot.kernelParams` |
| `modules/system/plymouth.nix` | Create | System Plymouth only — `boot.plymouth` + initrd ordering |
| `modules/home/branding.nix` | Create | HM helpers `hydra-branding-preview` / `hydra-branding-sync` |
| `assets/branding/screensaver.txt` | Create (copy of `~/.config/branding/screensaver.txt`) | Reproducible Nix path input |
| `modules/hardware/hybrid-nvidia.nix:6-9` | Verify | `nvidia-drm.modeset=1` KMS |
| `CHANGELOG.md`, `README.md` | Modify | Docs per commit |

---

### Task 1: Silent kernel params

**Files:**
- Modify: `/etc/nixos/configuration.nix:9-15`
- Test: `nix flake check` + `nix build --dry-run` + post-reboot `/proc/cmdline`

**Interfaces:**
- Consumes: `boot.loader.systemd-boot.enable` (true)
- Produces: `boot.kernelParams` quiet set; `boot.consoleLogLevel = 0` for Task 2

- [ ] **Step 1: Record baseline acceptance (pre-reboot)**

```bash
cat /proc/cmdline
# expect loglevel=4 without quiet — baseline
grep -q "quiet" /proc/cmdline && echo "quiet present" || echo "quiet missing — expected before change"
```

- [ ] **Step 2: Implement silent params in configuration.nix**

```nix
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "splash"
    "loglevel=3"
    "systemd.show_status=auto"
    "rd.udev.log_level=3"
    "rd.systemd.show_status=auto"
  ];
```

Insert at `configuration.nix:14` after `configurationLimit = 3;`.

- [ ] **Step 3: Verify eval preview (no switch)**

```bash
nix flake check /etc/nixos --no-build
nix build --dry-run /etc/nixos#nixosConfigurations.hydragon2000-pc.config.system.build.toplevel
```

Expected: PASS, no eval error. `nh os build` is a real build — not equivalent to dry-run.

- [ ] **Step 4: Post-reboot acceptance (after user runs rebuild + reboot)**

```bash
grep -q "quiet" /proc/cmdline && echo "PASS quiet"
grep -q "loglevel=3" /proc/cmdline && echo "PASS loglevel"
grep -q "systemd.show_status=auto" /proc/cmdline && echo "PASS show_status"
```

`systemd.show_status=auto` suppresses routine output while retaining failure reporting (not "only failures").

- [ ] **Step 5: Commit**

```bash
git -C /etc/nixos add configuration.nix CHANGELOG.md
git -C /etc/nixos commit -m "feat: silent boot kernel params quiet splash loglevel 3 — hide scroll but retain failure reporting"
```

---

### Task 2: Plymouth enable + handoff ordering (static bgrt first)

**Files:**
- Create: `/etc/nixos/modules/system/plymouth.nix`
- Modify: `/etc/nixos/configuration.nix:1-6` (add import) or `flake.nix` modules list
- Test: `systemctl cat` + `systemd-analyze` ordering inspection

**Interfaces:**
- Consumes: `boot.kernelParams` from Task 1
- Produces: `boot.plymouth = { enable=true; theme="bgrt"; themePackages=[]; }` for Task 3 to replace

- [ ] **Step 1: Create modules/system/plymouth.nix**

```nix
{ ... }: {
  boot.plymouth = {
    enable = true;
    theme = "bgrt";
    themePackages = [];
  };
  boot.initrd.systemd.enable = true;
}
```

- [ ] **Step 2: Wire import**

```nix
# in configuration.nix imports, or via flake.nix modules list
imports = [
  ./modules/system/plymouth.nix
];
```

Verify `hybrid-nvidia.nix:6-9` already sets `nvidia-drm.modeset=1` for KMS.

- [ ] **Step 3: Dry preview**

```bash
nix flake check /etc/nixos --no-build
nix build --dry-run /etc/nixos#nixosConfigurations.hydragon2000-pc.config.system.build.toplevel
```

- [ ] **Step 4: After user build+reboot, inspect ordering — do not assume**

```bash
systemctl cat greetd.service
systemctl cat plymouth-quit.service
systemd-analyze critical-chain greetd.service
# ensure plymouth-quit → greetd handoff, no blind wants= added
systemctl status plymouth-start.service
journalctl -b | grep -i plymouth
```

- [ ] **Step 5: Desktop smoke test only (not initrd proof)**

```bash
sudo plymouthd --debug --debug-file=/tmp/plymouth.log
sudo plymouth --show-splash; sleep 3; sudo plymouth --quit
```

Label as runtime sanity — real proof is reboot → newly built generation boots and previous systemd-boot generation remains selectable (`bootctl list | grep nixos-generation`, `ls /boot/loader/entries/*.conf`).

- [ ] **Step 6: Commit**

```bash
git -C /etc/nixos add configuration.nix modules/system/plymouth.nix CHANGELOG.md
git -C /etc/nixos commit -m "feat: add plymouth bgrt with initrd systemd — hold framebuffer till greetd, fix flash"
```

---

### Task 3: Custom theme — explicit source + font boundary

**Files:**
- Modify: `/etc/nixos/modules/system/plymouth.nix`
- Create: `/etc/nixos/assets/branding/screensaver.txt` (copy of `~/.config/branding/screensaver.txt`)
- Test: `plymouth-set-default-theme --list | grep hydra`

**Interfaces:**
- Consumes: `assets/branding/screensaver.txt` Nix path input, `pkgs.nerd-fonts.jetbrains-mono` font file
- Produces: `boot.plymouth.theme = "hydra"` + `themePackages = [ hydraTheme ]`

- [ ] **Step 1: Copy branding source into repo (reproducible boundary)**

```bash
mkdir -p /etc/nixos/assets/branding
cp /home/hydragon2000/.config/branding/screensaver.txt /etc/nixos/assets/branding/screensaver.txt
git -C /etc/nixos add assets/branding/screensaver.txt
```

- [ ] **Step 2: Pre-check font availability**

```bash
fc-list | grep -i "JetBrains" || echo "runtime font check"
ls /run/current-system/sw/share/fonts 2>&1 | head
nix build --dry-run /etc/nixos#nixosConfigurations.hydragon2000-pc.config.system.build.toplevel 2>&1 | head
```

- [ ] **Step 3: Implement hydra theme with explicit font file**

```nix
{ pkgs, ... }:
let
  brandingSrc = ../assets/branding/screensaver.txt;
  jetbrainsMono = pkgs.nerd-fonts.jetbrains-mono;
  fontFile = "${jetbrainsMono}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFont-Regular.ttf";
  logoPng = pkgs.runCommand "hydra-logo.png" {
    buildInputs = [ pkgs.imagemagick ];
    FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ jetbrainsMono ]; };
  } ''convert -background '#1d2021' -fill '#ebdbb2' -font "${fontFile}" -pointsize 18 label:@"${brandingSrc}" $out'';
  hydraTheme = pkgs.runCommand "plymouth-hydra-theme" {} ''
    mkdir -p $out/share/plymouth/themes/hydra
    cp ${logoPng} $out/share/plymouth/themes/hydra/logo.png
    cat > $out/share/plymouth/themes/hydra/hydra.plymouth <<EOF
[Plymouth Theme]
Name=Hydra
Description=Branding from assets/branding/screensaver.txt
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
SCRIPT
  '';
in {
  boot.plymouth.themePackages = [ hydraTheme ];
  boot.plymouth.theme = "hydra";
  boot.plymouth.enable = true;
  boot.initrd.systemd.enable = true;
}
```

No `Image.Circle` — static splash first. Animation only after verifying script API on installed Plymouth. Consistent Nix path input (not `builtins.readFile` mix).

- [ ] **Step 4: Dry preview + after reboot verify**

```bash
nix flake check /etc/nixos --no-build
nix build --dry-run /etc/nixos#nixosConfigurations.hydragon2000-pc.config.system.build.toplevel
# after reboot:
plymouth-set-default-theme --list | grep -q hydra && echo PASS
ls /run/current-system/sw/share/plymouth/themes/hydra/logo.png && echo PASS
```

- [ ] **Step 5: Commit**

```bash
git -C /etc/nixos add assets/branding/screensaver.txt modules/system/plymouth.nix CHANGELOG.md
git -C /etc/nixos commit -m "feat: custom plymouth hydra theme from assets/branding/screensaver.txt — catppuccin omarchy-style"
```

---

### Task 4: Error visibility + rollback guarantees

**Files:**
- Modify: `/etc/nixos/modules/system/plymouth.nix` (no new params — verification only)
- Create: `/etc/nixos/docs/specs/silent-boot-verification.md` (optional checklist)

**Interfaces:**
- Consumes: `boot.kernelParams` + `boot.plymouth` from Tasks 1-3
- Produces: verified rollback story without unverified `plymouth.enable=0` param

- [ ] **Step 1: Visual behavior — manual verification (not guarantee)**

```bash
# Reboot, observe: Plymouth quits when greeter ready (kernel → initrd.plymouth → greetd/ReGreet), not after auth
# Verify Esc exposes status/log on this config — treat as check, not promise
```

- [ ] **Step 2: Failed units — separate from visual**

```bash
systemctl --failed --no-pager || echo "no failed units"
```

- [ ] **Step 3: Journal persistence — consistent level**

```bash
journalctl -b -p warning --no-pager | head -n 20
# use -p warning everywhere (not mixed -p 3)
```

- [ ] **Step 4: Rollback verification**

```bash
bootctl list | grep nixos-generation
ls /boot/loader/entries/*.conf | head
# verify previous systemd-boot generation remains selectable
# robust rollback: disable via Nix boot.plymouth.enable=false or remove quiet/splash — don't rely on unverified plymouth.enable=0 kernel param
```

- [ ] **Step 5: Commit docs if created**

```bash
git -C /etc/nixos add docs/specs/silent-boot-verification.md CHANGELOG.md
git -C /etc/nixos commit -m "docs: silent boot verification — visual, failed units, journal, rollback"
```

---

### Task 5: HM branding helpers (moved out of system module)

**Files:**
- Create: `/etc/nixos/modules/home/branding.nix`
- Modify: `/etc/nixos/home.nix:7-21` (add import)
- Test: `hydra-branding-preview` produces `/tmp/preview.png`

**Interfaces:**
- Consumes: `assets/branding/screensaver.txt` repo path, `pkgs.nerd-fonts.jetbrains-mono`
- Produces: `home.file.".local/bin/hydra-branding-preview"` + `hydra-branding-sync`

- [ ] **Step 1: Create modules/home/branding.nix**

```nix
{ pkgs, ... }: {
  home.file.".local/bin/hydra-branding-preview" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      bg=''${1:-'#1d2021'}; fg=''${2:-'#ebdbb2'}; src=''${3:-$HOME/.config/branding/screensaver.txt}
      out=''${4:-/tmp/preview.png}
      font="${pkgs.nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFont-Regular.ttf"
      convert -background "$bg" -fill "$fg" -font "$font" -pointsize 18 label:@"$src" "$out" && echo "preview $out"
    '';
  };
  home.file.".local/bin/hydra-branding-sync" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      cp "$HOME/.config/branding/screensaver.txt" /etc/nixos/assets/branding/screensaver.txt
      echo "synced → review git diff → build (nh os build)"
    '';
  };
}
```

- [ ] **Step 2: Wire import in home.nix**

```nix
imports = [
  ./modules/home/branding.nix
];
```

- [ ] **Step 3: Dry preview + manual preview test (after rebuild)**

```bash
nix flake check /etc/nixos --no-build
nix build --dry-run /etc/nixos#nixosConfigurations.hydragon2000-pc.config.system.build.toplevel
# after rebuild:
hydra-branding-preview '#1d2021' '#ebdbb2' ~/.config/branding/screensaver.txt /tmp/preview.png && ls -lh /tmp/preview.png
```

- [ ] **Step 4: Commit**

```bash
git -C /etc/nixos add home.nix modules/home/branding.nix CHANGELOG.md
git -C /etc/nixos commit -m "feat: add hydra branding helpers — preview and sync to repo asset"
```

---

### Task 6: Docs + commits batching

**Files:**
- Modify: `CHANGELOG.md`, `README.md`

- [ ] **Step 1: Update README boot section with params, theme path, sync→diff→build workflow, Esc verification note, dry-run vs nh os build distinction**
- [ ] **Step 2: Commit batched docs (avoid noisy per-task changelog if already covered)**

```bash
git -C /etc/nixos add README.md CHANGELOG.md
git -C /etc/nixos commit -m "docs: update README boot section — silent boot + plymouth branding workflow"
```

---

### Task 7: Bootloader rice (explicit out-of-scope)

Keep systemd-boot. Future separate plan for `boot.loader.grub` with `theme = ./assets/grub-theme` or `boot.loader.limine` — separate because it changes boot entry path.
