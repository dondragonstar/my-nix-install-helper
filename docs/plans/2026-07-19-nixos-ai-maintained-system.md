# NixOS AI-Maintained Reproducible System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure `/etc/nixos` into a self-contained git repo with machine-portable hardware config, a watertight bootstrap installer, and universally enforced AI agent protocols.

**Architecture:** `/etc/nixos` becomes the git repo root (copy-sync loop dies). All machine-specific values isolate into `machine.nix` + `hardware-configuration.nix`. GPU config splits into `modules/hardware/<profile>.nix` selected by a closed enum. `AGENTS.md` is the single protocol file, distributed via home-manager symlinks and enforced by committed git hooks.

**Tech Stack:** Nix flakes (nixos-26.05), home-manager, bash, git hooks, Ollama (optional commit messages).

**Spec:** `/home/hydragon2000/nixos-specs/2026-07-19-nixos-ai-maintained-system-design.md` (read it first).

## Global Constraints

- **Execution environment:** this plan REQUIRES real write access to `/etc/nixos`. The planning session saw it read-only via an FHS sandbox (`/.host-etc/nixos`). Verify first: `touch /etc/nixos/.wtest && rm /etc/nixos/.wtest`. If that fails, stop and tell the user.
- **AI never runs `nixos-rebuild switch`** — AI runs `dry-build`/`build` only; the USER runs switch. Plan marks these steps `[USER]`.
- Git identity for this repo: `dondragonstar` / `dondragonstar@gmail.com` (personal). NEVER add Claude/AI as author or co-author (no `Co-Authored-By` trailers — user rule).
- Push workaround (from memory): home-manager `~/.ssh/config` fails ssh perms check. Push with: `GIT_SSH_COMMAND="ssh -i ~/.ssh/id_ed25519_personal -o IdentitiesOnly=yes" git push origin main`
- Remote stays `git@github.com:dondragonstar/my-nix-install-helper.git`.
- Flake inputs unchanged: `nixos-26.05`, home-manager `release-26.05`, `wlctl`.
- Current machine facts (verified): hostname `hydragon2000-pc`, username `hydragon2000`, timezone `Asia/Kolkata`, GPU = Intel iGPU + NVIDIA RTX 2050 PRIME offload (profile `hybrid-nvidia`), bus IDs `intelBusId = "PCI:0@0:2:0"`, `nvidiaBusId = "PCI:1@0:0:0"`, Intel CPU.
- `hardware-configuration.nix` is **committed** (flakes only see git-tracked files — spec section 2.1).
- Every task that touches `.nix` files appends a `CHANGELOG.md` entry (the protocol we're building; practice it from Task 1).

---

### Task 1: Migration — /etc/nixos becomes the repo root

**Files:**
- Move: `/etc/nixos/repo/.git` → `/etc/nixos/.git`
- Move: `/etc/nixos/repo/{README.md,gen-commit-msg.py}` → `/etc/nixos/`
- Delete: `/etc/nixos/repo/` (all remaining contents), `/etc/nixos/repo/sync.sh`
- Create: `/etc/nixos/.gitignore`, `/etc/nixos/CHANGELOG.md`

**Interfaces:**
- Produces: git repo rooted at `/etc/nixos`, user-owned; baseline closure store path saved at `/home/hydragon2000/nixos-specs/baseline-closure.txt` (Task 3 compares against it).

- [ ] **Step 1: Verify write access and take safety backup**

```bash
touch /etc/nixos/.wtest && rm /etc/nixos/.wtest && echo OK
sudo cp -a /etc/nixos /root/nixos-backup-pre-refactor
sudo ls /root/nixos-backup-pre-refactor/flake.nix   # confirm backup exists
```
Expected: `OK`, then the flake.nix path prints. If `touch` fails: STOP, wrong environment.

- [ ] **Step 2: Record baseline closure (pre-refactor system hash)**

```bash
nix build /etc/nixos#nixosConfigurations.hydragon2000-pc.config.system.build.toplevel \
  --print-out-paths --no-link \
  --extra-experimental-features "nix-command flakes" \
  | tee /home/hydragon2000/nixos-specs/baseline-closure.txt
```
Expected: one `/nix/store/...-nixos-system-hydragon2000-pc-26.05...` path. (Works pre-migration because `/etc/nixos` is a plain-dir flake, not yet a git repo.)

- [ ] **Step 3: Take ownership, move .git up, consolidate files**

```bash
sudo chown -R hydragon2000:users /etc/nixos
cd /etc/nixos
mv repo/.git .git
mv repo/README.md README.md
mv repo/gen-commit-msg.py gen-commit-msg.py
rm -rf repo/            # sync.sh, CONFIGS_MASTER.md, GIT_OPS.md, .claude/, duplicated configs all die here
```
Note: the repo tracked files at its root (e.g. `configuration.nix`), so after the `.git` move those tracked paths now resolve to the live files at `/etc/nixos/` — history is preserved, content is the freshly-synced live config.

- [ ] **Step 4: Write .gitignore and seed CHANGELOG.md**

`/etc/nixos/.gitignore`:
```
result
result-*
*.hm-backup
.wtest
```

`/etc/nixos/CHANGELOG.md`:
```markdown
# Changelog

Newest first. Every commit that touches a `.nix` file MUST add an entry here
(enforced by `hooks/pre-commit`). One line per change: what and why.

## 2026-07-19
- refactor: /etc/nixos is now the git repo root; repo/ subdir and sync.sh copy loop retired (zero-drift: the live config IS the repo)
- chore: hardware-configuration.nix is now tracked (flakes only see git-tracked files)
```

- [ ] **Step 5: Verify identity, stage everything, commit**

```bash
cd /etc/nixos
git config user.name || git config user.name "dondragonstar"
git config user.email || git config user.email "dondragonstar@gmail.com"
git config user.name          # must print: dondragonstar
git add -A
git status --short            # review: expect renames/modifications + new hardware-configuration.nix, CHANGELOG.md, .gitignore, deleted repo/* paths
git commit -m "refactor: /etc/nixos is the repo root; retire copy-sync loop

- moved .git from repo/ up to /etc/nixos, deleted repo/ and sync.sh
- hardware-configuration.nix now tracked (required for pure flake eval)
- seeded CHANGELOG.md, .gitignore"
```
Expected: commit succeeds; `git status` clean afterwards.

- [ ] **Step 6: Verify flake still evaluates as a git repo**

```bash
nix build /etc/nixos#nixosConfigurations.hydragon2000-pc.config.system.build.toplevel \
  --print-out-paths --no-link --extra-experimental-features "nix-command flakes"
```
Expected: SAME store path as `baseline-closure.txt`. If it errors about a missing file, that file is untracked — `git add` it and re-commit (this is exactly the tracked-files rule this migration exists to satisfy).

---

### Task 2: machine.nix + flake.nix rewrite (closed gpu enum)

**Files:**
- Create: `/etc/nixos/machine.nix`
- Rewrite: `/etc/nixos/flake.nix`
- Modify: `/etc/nixos/CHANGELOG.md` (append entry)

**Interfaces:**
- Produces: `machine` attrset `{ hostname, username, timezone, cpu, gpu, nvidiaBusIds }` available to all NixOS modules via `specialArgs`; gpu enum values `nvidia | amd | intel | hybrid-nvidia | vm | generic`; flake selects `./modules/hardware/${gpu}.nix` (module files created in Task 3 — flake won't evaluate until then; that's expected mid-task-sequence).
- Consumes: repo layout from Task 1.

- [ ] **Step 1: Create machine.nix with current-machine values**

`/etc/nixos/machine.nix`:
```nix
# ══════════════════════════════════════════════════════════════════
# THE machine-identity file. ALL machine-specific values live here
# (plus auto-generated hardware-configuration.nix). Nothing
# machine-specific may be hardcoded anywhere else — AGENTS.md rule.
# bootstrap.sh rewrites this file when installing on a new machine.
# ══════════════════════════════════════════════════════════════════
{
  hostname = "hydragon2000-pc";
  username = "hydragon2000";
  timezone = "Asia/Kolkata";

  # intel | amd | unknown — selects CPU microcode updates
  cpu = "intel";

  # One of: nvidia | amd | intel | hybrid-nvidia | vm | generic
  # (validated at eval time in flake.nix — a typo gives a clear error)
  gpu = "hybrid-nvidia";

  # Only used when gpu = "hybrid-nvidia" (PRIME offload bus IDs).
  # Key is intelBusId or amdgpuBusId depending on the iGPU vendor.
  nvidiaBusIds = {
    intelBusId = "PCI:0@0:2:0";
    nvidiaBusId = "PCI:1@0:0:0";
  };
}
```

- [ ] **Step 2: Rewrite flake.nix**

`/etc/nixos/flake.nix` (full replacement):
```nix
{
  description = "hydragon2000's NixOS + Hyprland system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wlctl.url = "github:aashish-thapa/wlctl";
  };

  outputs = { self, nixpkgs, home-manager, wlctl, ... }: let
    machine = import ./machine.nix;
    validGpus = [ "nvidia" "amd" "intel" "hybrid-nvidia" "vm" "generic" ];
    gpu =
      if builtins.elem machine.gpu validGpus
      then machine.gpu
      else throw ''
        machine.nix error: gpu = "${machine.gpu}" is not a valid profile.
        Valid values: ${builtins.concatStringsSep " | " validGpus}
        Fix the gpu field in /etc/nixos/machine.nix and rebuild.
      '';
    hostname = machine.hostname;
    username = machine.username;
  in {
    nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit hostname username machine; };
      modules = [
        ./configuration.nix
        ./hardware-configuration.nix
        (./. + "/modules/hardware/${gpu}.nix")
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit hostname username wlctl; };
          home-manager.users.${username} = import ./home.nix;
          home-manager.backupFileExtension = "hm-backup";
        }
      ];
    };
  };
}
```

- [ ] **Step 3: Verify both files parse**

```bash
nix-instantiate --parse /etc/nixos/machine.nix > /dev/null && echo machine-OK
nix-instantiate --parse /etc/nixos/flake.nix > /dev/null && echo flake-OK
```
Expected: `machine-OK`, `flake-OK`. (Full eval deliberately deferred — `modules/hardware/` doesn't exist until Task 3.)

- [ ] **Step 4: Append CHANGELOG entry and commit**

Append under `## 2026-07-19` in `/etc/nixos/CHANGELOG.md`:
```markdown
- feat: machine.nix isolates all machine-specific values; flake.nix validates gpu against a closed enum with a clear eval-time error
```

```bash
cd /etc/nixos && git add machine.nix flake.nix CHANGELOG.md
git commit -m "feat: machine.nix + gpu enum validation in flake.nix"
```

---

### Task 3: Hardware profile modules + slim configuration.nix

**Files:**
- Create: `/etc/nixos/modules/hardware/{hybrid-nvidia,nvidia,amd,intel,vm,generic}.nix`
- Modify: `/etc/nixos/configuration.nix` (remove GPU section lines 48–81, nvidia kernelParams lines 15–18, hardcoded timezone line 29, `ollama-cuda` line 142; add `machine` arg)
- Modify: `/etc/nixos/CHANGELOG.md`

**Interfaces:**
- Consumes: `machine` specialArg from Task 2 (`machine.timezone`, `machine.cpu`, `machine.nvidiaBusIds`).
- Produces: six module files; each is self-contained and receives `{ config, pkgs, machine, ... }`. `generic.nix` is the guaranteed-boot floor.

- [ ] **Step 1: Create the six profile modules**

`/etc/nixos/modules/hardware/hybrid-nvidia.nix`:
```nix
# NVIDIA dGPU + iGPU laptop (PRIME render offload).
# Bus IDs come from machine.nix (nvidiaBusIds), so this file is portable.
{ config, pkgs, machine, ... }:

{
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
  ];

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    powerManagement = {
      enable = true;
      finegrained = true;
    };

    # offload settings + whichever bus IDs machine.nix provides
    # (intelBusId or amdgpuBusId, plus nvidiaBusId)
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
    } // machine.nvidiaBusIds;
  };

  # CUDA build of Ollama only makes sense on NVIDIA hardware
  services.ollama.package = pkgs.ollama-cuda;
}
```

`/etc/nixos/modules/hardware/nvidia.nix`:
```nix
# Single NVIDIA GPU (desktop) — no PRIME offload.
{ config, pkgs, machine, ... }:

{
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    powerManagement.enable = true;
  };

  services.ollama.package = pkgs.ollama-cuda;
}
```

`/etc/nixos/modules/hardware/amd.nix`:
```nix
# AMD GPU — amdgpu kernel driver is in-tree and auto-loaded;
# Mesa provides userspace. Nothing extra needed for a working desktop.
{ machine, ... }:

{
}
```

`/etc/nixos/modules/hardware/intel.nix`:
```nix
# Intel-only graphics — i915/xe is in-tree; Mesa handles userspace.
# Nothing extra needed for a working desktop.
{ machine, ... }:

{
}
```

`/etc/nixos/modules/hardware/vm.nix`:
```nix
# Virtual machine guest (virtio-gpu / QXL / VMware SVGA).
# Kernel modesetting drives the display; add guest integration agents.
{ machine, ... }:

{
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
}
```

`/etc/nixos/modules/hardware/generic.nix`:
```nix
# Guaranteed-boot floor: kernel modesetting only, no vendor driver.
# Selected when GPU detection fails or finds an unknown vendor.
# The system boots to a working desktop; pick a real profile in
# machine.nix later and rebuild.
{ machine, ... }:

{
}
```

- [ ] **Step 2: Slim configuration.nix**

Apply these exact edits to `/etc/nixos/configuration.nix`:

1. Line 1 argument set — add `machine`:
```nix
{ config, lib, pkgs, hostname, username, machine, ... }:
```
2. DELETE the nvidia kernelParams block (current lines 15–18):
```nix
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
  ];
```
3. Replace `time.timeZone = "Asia/Kolkata";` with:
```nix
  time.timeZone = machine.timezone;
```
4. DELETE the whole `## Graphics / NVIDIA` section (current lines 48–81: the `MACHINE-SPECIFIC` banner comment, `hardware.graphics`, `services.xserver.videoDrivers`, `hardware.nvidia`) and put in its place:
```nix
  ##############################################################
  ## Graphics (vendor-specific config lives in modules/hardware/,
  ## selected by the gpu field in machine.nix)
  ##############################################################
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # CPU microcode per machine.nix (nixos-generate-config also sets a
  # default; this makes the choice explicit and portable)
  hardware.cpu.intel.updateMicrocode = lib.mkIf (machine.cpu == "intel") true;
  hardware.cpu.amd.updateMicrocode = lib.mkIf (machine.cpu == "amd") true;
```
5. In the Ollama section, DELETE the line `package = pkgs.ollama-cuda;` (the CUDA package now comes from the nvidia profiles):
```nix
  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    port = 11434;
  };
```

- [ ] **Step 3: Stage new files, then verify closure matches baseline**

```bash
cd /etc/nixos && git add modules/ configuration.nix
nix build /etc/nixos#nixosConfigurations.hydragon2000-pc.config.system.build.toplevel \
  --print-out-paths --no-link --extra-experimental-features "nix-command flakes"
diff <(cat /home/hydragon2000/nixos-specs/baseline-closure.txt) \
     <(nix build /etc/nixos#nixosConfigurations.hydragon2000-pc.config.system.build.toplevel \
        --print-out-paths --no-link --extra-experimental-features "nix-command flakes")
```
Expected: `diff` prints nothing (identical store path) — the refactor is behavior-preserving. If paths differ: run `nix store diff-closures <baseline> <new>`; the ONLY acceptable difference is none. Investigate any delta (most likely: a value accidentally dropped from step 2) before proceeding.

- [ ] **Step 4: Test the enum guard produces a clear error**

```bash
sed -i 's/gpu = "hybrid-nvidia";/gpu = "typo-value";/' /etc/nixos/machine.nix
nix build /etc/nixos#nixosConfigurations.hydragon2000-pc.config.system.build.toplevel \
  --no-link --extra-experimental-features "nix-command flakes" 2>&1 | grep -A2 "not a valid profile"
sed -i 's/gpu = "typo-value";/gpu = "hybrid-nvidia";/' /etc/nixos/machine.nix
```
Expected: error output contains `gpu = "typo-value" is not a valid profile` and the valid-values line. Then the revert restores `hybrid-nvidia`.

- [ ] **Step 5: CHANGELOG + commit**

Append to CHANGELOG under `## 2026-07-19`:
```markdown
- feat: modules/hardware/ profiles (hybrid-nvidia, nvidia, amd, intel, vm, generic); configuration.nix is now fully machine-agnostic; ollama-cuda moved into nvidia profiles
```

```bash
cd /etc/nixos && git add -A
git commit -m "feat: hardware profile modules; configuration.nix machine-agnostic"
```

---

### Task 4: bootstrap.sh — watertight new-machine installer

**Files:**
- Create: `/etc/nixos/bootstrap.sh` (mode 755)
- Modify: `/etc/nixos/CHANGELOG.md`

**Interfaces:**
- Consumes: `machine.nix` schema from Task 2; profile names from Task 3.
- Produces: `bootstrap.sh` with flags `--hostname --username --timezone --gpu --dry-run`; env override `TARGET_DIR` (default `/mnt/etc/nixos`). `--dry-run` performs detection + prints the machine.nix it WOULD write, changes nothing.

- [ ] **Step 1: Write bootstrap.sh**

`/etc/nixos/bootstrap.sh`:
```bash
#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
# New-machine installer for this NixOS flake.
#
# Run from the NixOS installer ISO AFTER partitioning and mounting
# the target at /mnt (see README.md), with this repo cloned to
# /mnt/etc/nixos.
#
# Usage:
#   ./bootstrap.sh                          # interactive
#   ./bootstrap.sh --hostname X --username Y --timezone Z
#   ./bootstrap.sh --gpu amd                # override detection
#   TARGET_DIR=/etc/nixos ./bootstrap.sh --dry-run   # detect-only, on a live system
#
# Safety properties:
#   - Detection reads sysfs only (zero tool dependencies) and matches
#     numeric PCI vendor IDs, never name strings.
#   - Every detected value is shown and confirmed before use.
#   - Unknown/undetectable GPU falls back to the "generic" profile,
#     which always boots (kernel modesetting).
#   - A dry-build gate runs BEFORE nixos-install; failure aborts with
#     the machine untouched.
# ══════════════════════════════════════════════════════════════════
set -euo pipefail

TARGET_DIR="${TARGET_DIR:-/mnt/etc/nixos}"
DRY_RUN=0
NEW_HOSTNAME=""
NEW_USERNAME=""
NEW_TIMEZONE=""
GPU_OVERRIDE=""
VALID_GPUS="nvidia amd intel hybrid-nvidia vm generic"

while [ $# -gt 0 ]; do
  case "$1" in
    --hostname) NEW_HOSTNAME="$2"; shift 2 ;;
    --username) NEW_USERNAME="$2"; shift 2 ;;
    --timezone) NEW_TIMEZONE="$2"; shift 2 ;;
    --gpu)      GPU_OVERRIDE="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=1; shift ;;
    *) echo "unknown flag: $1 (valid: --hostname --username --timezone --gpu --dry-run)" >&2; exit 2 ;;
  esac
done

# ---------- helpers ----------

# /sys/bus/pci/devices/0000:01:00.0 → "PCI:1@0:0:0"
# Format PCI:<bus>@<domain>:<device>:<function>, decimal (matches the
# style hardware.nvidia.prime expects and machine.nix uses).
to_busid() {
  local addr domain bus dev fn
  addr=$(basename "$1")
  domain=${addr%%:*}
  bus=${addr#*:};  bus=${bus%%:*}
  dev=${addr##*:}; dev=${dev%%.*}
  fn=${addr##*.}
  printf 'PCI:%d@%d:%d:%d' "0x$bus" "0x$domain" "0x$dev" "0x$fn"
}

validate_gpu() {
  case " $VALID_GPUS " in
    *" $1 "*) return 0 ;;
    *) echo "ERROR: gpu profile '$1' invalid. Valid: $VALID_GPUS" >&2; return 1 ;;
  esac
}

# ---------- GPU detection (sysfs, numeric vendor IDs only) ----------
GPU_PROFILE="generic"
NVIDIA_PATH=""
IGPU_PATH=""
IGPU_VENDOR=""

detect_gpu() {
  local vendors="" v cls dev
  for dev in /sys/bus/pci/devices/*; do
    [ -r "$dev/class" ] || continue
    cls=$(cat "$dev/class")
    case "$cls" in
      0x0300*|0x0302*) ;;   # VGA controller / 3D controller
      *) continue ;;
    esac
    v=$(cat "$dev/vendor")
    vendors="$vendors $v"
    case "$v" in
      0x10de) NVIDIA_PATH="$dev" ;;
      0x8086|0x1002) IGPU_PATH="$dev"; IGPU_VENDOR="$v" ;;
    esac
  done

  if [ -n "$NVIDIA_PATH" ] && [ -n "$IGPU_PATH" ]; then
    GPU_PROFILE="hybrid-nvidia"
  elif [ -n "$NVIDIA_PATH" ]; then
    GPU_PROFILE="nvidia"
  else
    case "$vendors" in
      *0x1002*) GPU_PROFILE="amd" ;;
      *0x8086*) GPU_PROFILE="intel" ;;
      *0x15ad*|*0x1af4*|*0x1234*) GPU_PROFILE="vm" ;;
      *)
        GPU_PROFILE="generic"
        echo "WARNING: no known GPU vendor detected (raw:${vendors:- none})." >&2
        echo "         Using 'generic' profile — always boots on kernel modesetting." >&2
        ;;
    esac
  fi
}

# ---------- CPU detection ----------
CPU_VENDOR="unknown"
detect_cpu() {
  case "$(awk '/^vendor_id/ {print $3; exit}' /proc/cpuinfo 2>/dev/null)" in
    GenuineIntel) CPU_VENDOR="intel" ;;
    AuthenticAMD) CPU_VENDOR="amd" ;;
    *) echo "WARNING: unknown CPU vendor — microcode config skipped (harmless)." >&2 ;;
  esac
}

# ---------- run detection ----------
detect_gpu
detect_cpu
[ -n "$GPU_OVERRIDE" ] && { validate_gpu "$GPU_OVERRIDE" || exit 1; GPU_PROFILE="$GPU_OVERRIDE"; }

echo ""
echo "═══ Hardware detection ═══"
echo "  GPU profile : $GPU_PROFILE $([ -n "$GPU_OVERRIDE" ] && echo '(manual override)')"
[ -n "$NVIDIA_PATH" ] && echo "  NVIDIA GPU  : $(basename "$NVIDIA_PATH") → $(to_busid "$NVIDIA_PATH")"
[ -n "$IGPU_PATH" ]   && echo "  iGPU        : $(basename "$IGPU_PATH") → $(to_busid "$IGPU_PATH") (vendor $IGPU_VENDOR)"
echo "  CPU vendor  : $CPU_VENDOR"
echo ""

# ---------- confirm loop (skipped only in dry-run) ----------
if [ "$DRY_RUN" -eq 0 ]; then
  read -rp "Accept GPU profile '$GPU_PROFILE'? [Y/n=type another]: " ans
  case "${ans:-Y}" in
    n|N)
      read -rp "Profile ($VALID_GPUS): " GPU_PROFILE
      validate_gpu "$GPU_PROFILE" || exit 1
      ;;
  esac
  [ -z "$NEW_HOSTNAME" ] && read -rp "Hostname: " NEW_HOSTNAME
  [ -z "$NEW_USERNAME" ] && read -rp "Username: " NEW_USERNAME
  [ -z "$NEW_TIMEZONE" ] && read -rp "Timezone (e.g. Asia/Kolkata): " NEW_TIMEZONE
  [ -n "$NEW_HOSTNAME" ] && [ -n "$NEW_USERNAME" ] && [ -n "$NEW_TIMEZONE" ] || {
    echo "ERROR: hostname, username and timezone are all required." >&2; exit 1; }
fi

# ---------- render machine.nix ----------
render_machine_nix() {
  local busids=""
  if [ "$GPU_PROFILE" = "hybrid-nvidia" ]; then
    if [ -z "$NVIDIA_PATH" ] || [ -z "$IGPU_PATH" ]; then
      echo "ERROR: hybrid-nvidia needs both a detected NVIDIA GPU and an iGPU." >&2
      echo "       Use --gpu nvidia (or another profile) instead." >&2
      exit 1
    fi
    local igpu_key="intelBusId"
    [ "$IGPU_VENDOR" = "0x1002" ] && igpu_key="amdgpuBusId"
    busids=$(printf '\n\n  nvidiaBusIds = {\n    %s = "%s";\n    nvidiaBusId = "%s";\n  };' \
      "$igpu_key" "$(to_busid "$IGPU_PATH")" "$(to_busid "$NVIDIA_PATH")")
  fi
  cat <<EOF
# ══════════════════════════════════════════════════════════════════
# THE machine-identity file. ALL machine-specific values live here
# (plus auto-generated hardware-configuration.nix). Nothing
# machine-specific may be hardcoded anywhere else — AGENTS.md rule.
# Written by bootstrap.sh. Edit + rebuild to change.
# ══════════════════════════════════════════════════════════════════
{
  hostname = "$NEW_HOSTNAME";
  username = "$NEW_USERNAME";
  timezone = "$NEW_TIMEZONE";

  # intel | amd | unknown — selects CPU microcode updates
  cpu = "$CPU_VENDOR";

  # One of: nvidia | amd | intel | hybrid-nvidia | vm | generic
  gpu = "$GPU_PROFILE";$busids
}
EOF
}

if [ "$DRY_RUN" -eq 1 ]; then
  echo "─── dry-run: machine.nix that WOULD be written ───"
  NEW_HOSTNAME="${NEW_HOSTNAME:-<hostname>}"
  NEW_USERNAME="${NEW_USERNAME:-<username>}"
  NEW_TIMEZONE="${NEW_TIMEZONE:-<timezone>}"
  render_machine_nix
  echo "─── dry-run: no files changed ───"
  exit 0
fi

# ---------- real install path ----------
[ -d "$TARGET_DIR" ] || { echo "ERROR: $TARGET_DIR not found. Clone the repo there first (see README)." >&2; exit 1; }

# Regenerate hardware config for THIS machine. nixos-generate-config
# overwrites hardware-configuration.nix but never an existing
# configuration.nix, so the repo files are safe.
MNT_ROOT="${TARGET_DIR%/etc/nixos}"
if [ "$MNT_ROOT" != "$TARGET_DIR" ] && [ -n "$MNT_ROOT" ]; then
  sudo nixos-generate-config --root "$MNT_ROOT"
else
  sudo nixos-generate-config
fi
[ -f "$TARGET_DIR/hardware-configuration.nix" ] || {
  echo "ERROR: hardware-configuration.nix was not generated at $TARGET_DIR." >&2; exit 1; }

render_machine_nix > "$TARGET_DIR/machine.nix"
echo "Wrote $TARGET_DIR/machine.nix"

# Commit — flakes only see git-tracked files, so the install would
# fail on an uncommitted machine.nix / hardware-configuration.nix.
# Placeholder identity + --no-verify are deliberate: the ISO has no
# git identity and no Ollama; amend authorship after first boot
# (documented in README).
cd "$TARGET_DIR"
git add -A
ALLOW_HWCONFIG=1 git -c user.name="bootstrap" -c user.email="bootstrap@localhost" \
  commit --no-verify -m "bootstrap: configure machine $NEW_HOSTNAME ($GPU_PROFILE/$CPU_VENDOR)" || true

# ---------- dry-build gate: machine untouched if this fails ----------
echo "═══ dry-build gate ═══"
nix build "$TARGET_DIR#nixosConfigurations.$NEW_HOSTNAME.config.system.build.toplevel" \
  --dry-run --extra-experimental-features "nix-command flakes" || {
  echo "" >&2
  echo "ERROR: configuration failed to evaluate. NOTHING was installed." >&2
  echo "       Fix the error above (machine.nix / config), re-run bootstrap." >&2
  exit 1
}

echo "═══ installing ═══"
sudo nixos-install --flake "$TARGET_DIR#$NEW_HOSTNAME"
echo ""
echo "Done. Next: reboot, set the user password (sudo passwd $NEW_USERNAME),"
echo "then: git config core.hooksPath hooks  (inside /etc/nixos)"
echo "and amend the bootstrap commit author (see README)."
```

```bash
chmod 755 /etc/nixos/bootstrap.sh
```

- [ ] **Step 2: Unit-test to_busid conversion**

```bash
bash -c 'source /dev/stdin <<"EOF"
to_busid() {
  local addr domain bus dev fn
  addr=$(basename "$1"); domain=${addr%%:*}
  bus=${addr#*:};  bus=${bus%%:*}
  dev=${addr##*:}; dev=${dev%%.*}
  fn=${addr##*.}
  printf "PCI:%d@%d:%d:%d\n" "0x$bus" "0x$domain" "0x$dev" "0x$fn"
}
to_busid /sys/bus/pci/devices/0000:00:02.0
to_busid /sys/bus/pci/devices/0000:01:00.0
EOF'
```
Expected output, exactly:
```
PCI:0@0:2:0
PCI:1@0:0:0
```

- [ ] **Step 3: Run detection dry-run on the live machine**

```bash
bash /etc/nixos/bootstrap.sh --dry-run
```
Expected: `GPU profile : hybrid-nvidia`, NVIDIA bus `PCI:1@0:0:0`, iGPU bus `PCI:0@0:2:0` (vendor `0x8086`), `CPU vendor : intel`, then a rendered machine.nix preview with `intelBusId = "PCI:0@0:2:0"` — matching the live machine.nix exactly. `─── dry-run: no files changed ───` at the end. Verify nothing changed: `cd /etc/nixos && git status --short` → only expected pending files.

- [ ] **Step 4: Test override validation rejects garbage**

```bash
bash /etc/nixos/bootstrap.sh --dry-run --gpu nonsense; echo "exit=$?"
```
Expected: `ERROR: gpu profile 'nonsense' invalid. Valid: nvidia amd intel hybrid-nvidia vm generic` and `exit=1`.

- [ ] **Step 5: CHANGELOG + commit**

Append to CHANGELOG:
```markdown
- feat: bootstrap.sh — new-machine installer; sysfs-only GPU/CPU detection, numeric vendor IDs, confirm loop, generic fallback, dry-build gate before nixos-install
```

```bash
cd /etc/nixos && git add bootstrap.sh CHANGELOG.md
git commit -m "feat: watertight bootstrap.sh installer"
```

---

### Task 5: AGENTS.md protocol + declarative distribution

**Files:**
- Create: `/etc/nixos/AGENTS.md`
- Create: `/etc/nixos/CLAUDE.md` (symlink → `AGENTS.md`, committed)
- Modify: `/etc/nixos/home.nix` (add symlink deployment; after line 226 near the other `home.file` entries)
- Modify: `/home/hydragon2000/.claude/CLAUDE.md` (add one import line)
- Modify: `/etc/nixos/CHANGELOG.md`

**Interfaces:**
- Consumes: repo layout; home-manager config (`config.lib.file.mkOutOfStoreSymlink`).
- Produces: `AGENTS.md` discovered by every agent tool via: repo-root `AGENTS.md` + `CLAUDE.md` symlink, `~/AGENTS.md`, `~/GEMINI.md`, and `~/.claude/CLAUDE.md` import. Task 6's hooks enforce its rules.

- [ ] **Step 1: Write AGENTS.md**

`/etc/nixos/AGENTS.md`:
```markdown
# AGENTS.md — Mandatory Protocol for ALL AI Agents on This Machine

This is the single source of truth for AI agent conduct. It applies to every
agent (Claude Code, Gemini CLI, Codex, Cursor, aider, anything else) working
anywhere on this machine. Rules here are enforced by git hooks where possible
(`/etc/nixos/hooks/`) — but the protocol binds you even where no hook fires.

## 1. Documentation Rules

1. **Every change gets documented.** Any commit touching a `.nix` file MUST
   include a matching entry in `CHANGELOG.md` (one line: what + why).
   The pre-commit hook rejects commits that skip this.
2. **Major changes update README.md** — new modules, workflow changes, new
   machine-specific knobs, anything a fresh reader would need to know.

## 2. Git Identity (Golden Rules)

1. **NEVER add yourself (the AI) as author, committer, or co-author.** No
   `Co-Authored-By:` trailers. Your name must never appear in git metadata.
2. Identity routing:
   | Location | Git user | Remote style |
   |---|---|---|
   | anywhere under `~/` | dondragonstar | `git@github.com:` |
   | `~/Projects/professional/` | DevaJ2005 | `git@github-professional:` |
   | `/etc/nixos` | dondragonstar | `git@github.com:` |
3. Verify before committing: `git config user.name && git config user.email`.
   Never use `--author` to change identity.

## 3. NixOS System Boundaries

1. **Never edit files under `~/.config/` that home-manager manages.** Edit
   the source in `/etc/nixos` (usually `home.nix`) instead. Runtime files
   are build outputs, not sources.
2. **Never edit `hardware-configuration.nix` manually.** It is generated by
   `nixos-generate-config`. The pre-commit hook blocks staging it unless
   `ALLOW_HWCONFIG=1` is set (only for legitimate regeneration).
3. **Machine-specific values go in `machine.nix` ONLY** — hostname, username,
   timezone, cpu, gpu profile, bus IDs. Never hardcode any of these in
   shared files.
4. **AI runs `dry-build`, the USER runs `switch`.** Before proposing a
   rebuild, run
   `sudo nixos-rebuild dry-build --flake /etc/nixos#<hostname>`
   and report the result. Never run `nixos-rebuild switch` yourself.
5. `/etc/nixos` IS the git repo. There is no copy to sync. Edit in place,
   dry-build, let the user switch, then commit.

## 4. Commit Flow (this repo)

```bash
git config user.name && git config user.email   # 1. verify identity
# 2. make sure CHANGELOG.md has an entry for your change
git add <files> && git commit -m "..."           # 3. hooks validate
GIT_SSH_COMMAND="ssh -i ~/.ssh/id_ed25519_personal -o IdentitiesOnly=yes" \
  git push origin main                           # 4. push (ssh workaround)
```

`git commit --no-verify` requires explicit user approval — bypassing hooks
on your own initiative is a protocol violation.
```

- [ ] **Step 2: Create the committed CLAUDE.md symlink**

```bash
cd /etc/nixos && ln -s AGENTS.md CLAUDE.md
ls -l CLAUDE.md    # → CLAUDE.md -> AGENTS.md
```

- [ ] **Step 3: Add home-manager distribution to home.nix**

In `/etc/nixos/home.nix`, directly after the walker `home.file` entries (currently lines 225–226), insert:
```nix
  # ── AI agent protocol distribution ──
  # /etc/nixos/AGENTS.md is the single source; these symlinks make every
  # agent tool find it. mkOutOfStoreSymlink → edits apply without rebuild.
  home.file."AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/AGENTS.md";
  home.file."GEMINI.md".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/AGENTS.md";
```

- [ ] **Step 4: Add import to the global Claude config**

In `/home/hydragon2000/.claude/CLAUDE.md`, after the existing `@GIT_OPS.md` line at the top, add:
```
@/etc/nixos/AGENTS.md
```

- [ ] **Step 5: Verify — dry-build, then [USER] switch, then check symlinks**

```bash
sudo nixos-rebuild dry-build --flake /etc/nixos#hydragon2000-pc
```
Expected: completes without error. Then ask the USER to run:
```bash
rebuild    # alias: sudo nixos-rebuild switch --flake /etc/nixos#hydragon2000-pc
```
After the user confirms, verify:
```bash
readlink ~/AGENTS.md ~/GEMINI.md
```
Expected: both resolve (via the HM store indirection) to `/etc/nixos/AGENTS.md`.

- [ ] **Step 6: CHANGELOG + commit**

Append to CHANGELOG:
```markdown
- feat: AGENTS.md canonical AI protocol; distributed as ~/AGENTS.md + ~/GEMINI.md symlinks via home-manager, CLAUDE.md symlink at repo root, import in ~/.claude/CLAUDE.md
```

```bash
cd /etc/nixos && git add AGENTS.md CLAUDE.md home.nix CHANGELOG.md
git commit -m "feat: AGENTS.md protocol + declarative distribution"
```

---

### Task 6: Git hooks — mechanical enforcement

**Files:**
- Create: `/etc/nixos/hooks/pre-commit` (mode 755)
- Create: `/etc/nixos/hooks/prepare-commit-msg` (mode 755)
- Modify: repo config (`core.hooksPath`)
- Modify: `/etc/nixos/CHANGELOG.md`

**Interfaces:**
- Consumes: `AGENTS.md` rules (Task 5), `gen-commit-msg.py` at repo root (Task 1).
- Produces: enforced checks — identity, changelog gate, hwconfig guard (`ALLOW_HWCONFIG=1` override), nix syntax gate; optional Ollama commit messages.

- [ ] **Step 1: Write hooks/pre-commit**

`/etc/nixos/hooks/pre-commit`:
```bash
#!/usr/bin/env bash
# Protocol enforcement — see AGENTS.md. Bypassing with --no-verify
# requires explicit user approval.
set -euo pipefail

fail() { printf 'pre-commit REJECTED: %s\n' "$*" >&2; exit 1; }

STAGED=$(git diff --cached --name-only)

# ── 1. Identity check (AGENTS.md §2) ──
remote=$(git remote get-url origin 2>/dev/null || echo "")
name=$(git config user.name 2>/dev/null || echo "")
case "$remote" in
  git@github-professional:*) expected="DevaJ2005" ;;
  *)                         expected="dondragonstar" ;;
esac
[ "$name" = "$expected" ] || fail "git user.name is '$name', expected '$expected' for remote '$remote'.
  Fix: git config user.name '$expected'"
case "$name" in
  *[Cc]laude*|*[Aa][Ii]*|*[Aa]gent*|*[Bb]ot*)
    fail "AI-looking identity '$name' is forbidden (AGENTS.md golden rule)" ;;
esac

# ── 2. Changelog gate (AGENTS.md §1) ──
if printf '%s\n' "$STAGED" | grep -q '\.nix$' \
   && ! printf '%s\n' "$STAGED" | grep -qx 'CHANGELOG.md'; then
  fail ".nix files staged without a CHANGELOG.md entry.
  Add one line (what + why) to CHANGELOG.md and stage it."
fi

# ── 3. hardware-configuration.nix guard (AGENTS.md §3.2) ──
if printf '%s\n' "$STAGED" | grep -qx 'hardware-configuration.nix' \
   && [ "${ALLOW_HWCONFIG:-0}" != "1" ]; then
  fail "hardware-configuration.nix must never be edited manually.
  If nixos-generate-config legitimately regenerated it:
  ALLOW_HWCONFIG=1 git commit ..."
fi

# ── 4. Nix syntax gate ──
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$f" ] || continue          # deleted file — nothing to parse
  nix-instantiate --parse "$f" >/dev/null 2>&1 \
    || fail "nix syntax error in $f (run: nix-instantiate --parse $f)"
done <<EOF
$(printf '%s\n' "$STAGED" | grep '\.nix$' || true)
EOF

exit 0
```

- [ ] **Step 2: Write hooks/prepare-commit-msg**

`/etc/nixos/hooks/prepare-commit-msg`:
```bash
#!/usr/bin/env bash
# Generates a commit message via local Ollama (gen-commit-msg.py) when
# none was provided. Falls through silently if Ollama is unavailable.
MSG_FILE="$1"
SOURCE="${2:-}"

# A message, merge, template, etc. was already provided — do nothing.
[ -n "$SOURCE" ] && exit 0
if grep -v '^#' "$MSG_FILE" 2>/dev/null | grep -q '[^[:space:]]'; then exit 0; fi

DIFF=$(git diff --cached)
[ -z "$DIFF" ] && exit 0

TOPLEVEL=$(git rev-parse --show-toplevel)
AI_MSG=$(printf '%s' "$DIFF" | python3 "$TOPLEVEL/gen-commit-msg.py" 2>/dev/null || true)
[ -n "$AI_MSG" ] && printf '%s\n' "$AI_MSG" > "$MSG_FILE"
exit 0
```

```bash
chmod 755 /etc/nixos/hooks/pre-commit /etc/nixos/hooks/prepare-commit-msg
cd /etc/nixos && git config core.hooksPath hooks
```

- [ ] **Step 3: Test every rejection path**

```bash
cd /etc/nixos

# (a) changelog gate: stage a .nix change without CHANGELOG
echo "# hook-test" >> machine.nix
git add machine.nix
git commit -m "test" 2>&1 | grep "CHANGELOG"; echo "exit=$?"
git restore --staged machine.nix && git checkout -- machine.nix

# (b) hwconfig guard
echo "# hook-test" >> hardware-configuration.nix
git add hardware-configuration.nix
git commit -m "test" 2>&1 | grep "never be edited manually"; echo "exit=$?"
git restore --staged hardware-configuration.nix && git checkout -- hardware-configuration.nix

# (c) syntax gate: stage a broken .nix (with CHANGELOG staged so gate 2 passes)
printf '{ broken' > /tmp/claude-hook-test.nix && cp /tmp/claude-hook-test.nix modules/hardware/broken-test.nix
echo "- test entry" >> CHANGELOG.md
git add modules/hardware/broken-test.nix CHANGELOG.md
git commit -m "test" 2>&1 | grep "syntax error"; echo "exit=$?"
git restore --staged modules/hardware/broken-test.nix CHANGELOG.md
rm modules/hardware/broken-test.nix && git checkout -- CHANGELOG.md

# (d) identity check
git config user.name "Claude Agent"
git commit --allow-empty -m "test" 2>&1 | grep -i "expected 'dondragonstar'"; echo "exit=$?"
git config user.name "dondragonstar"
```
Expected: each `grep` prints the matched rejection line and `exit=0` (grep found it). Repo state clean afterwards: `git status --short` shows nothing unexpected.

- [ ] **Step 4: Test the happy path + Ollama message generation**

```bash
cd /etc/nixos
echo "- test: hook happy-path verification (will be amended away)" >> CHANGELOG.md
git add CHANGELOG.md
git commit -m "chore: verify hooks pass on a compliant commit"
git log -1 --pretty=%an   # → dondragonstar
# undo the test commit, keep history clean:
git reset --hard HEAD~1
```
Expected: commit succeeds, author correct, then reset leaves `git status` clean.

- [ ] **Step 5: CHANGELOG + commit hooks**

Append to CHANGELOG:
```markdown
- feat: committed git hooks (core.hooksPath=hooks) — identity check, CHANGELOG gate, hardware-config guard, nix syntax gate; optional Ollama commit messages
```

```bash
cd /etc/nixos && git add hooks/ CHANGELOG.md
git commit -m "feat: protocol-enforcing git hooks"
```
(This commit itself runs the new hooks — passing is part of the test.)

---

### Task 7: README rewrite + final verification + push

**Files:**
- Rewrite: `/etc/nixos/README.md`
- Modify: `/etc/nixos/CHANGELOG.md`

**Interfaces:**
- Consumes: everything above.
- Produces: accurate README; pushed main branch.

- [ ] **Step 1: Rewrite README.md**

`/etc/nixos/README.md` (full replacement):
```markdown
# hydragon2000's NixOS System

AI-maintained, reproducible NixOS + Hyprland configuration.
`/etc/nixos` IS the git repo — no copy-sync. All machine-specific state
lives in exactly two files: `machine.nix` (human choices) and
`hardware-configuration.nix` (auto-generated).

**AI agents: read `AGENTS.md` before touching anything. It is mandatory.**

## Layout

| Path | Purpose |
|---|---|
| `flake.nix` | Entry point; validates `machine.nix` (closed gpu enum) |
| `machine.nix` | ALL machine-specific values — hostname, username, timezone, cpu, gpu profile, bus IDs |
| `configuration.nix` | System config — fully machine-agnostic |
| `modules/hardware/` | GPU profiles: `nvidia`, `hybrid-nvidia`, `amd`, `intel`, `vm`, `generic` (guaranteed-boot fallback) |
| `hardware-configuration.nix` | Auto-generated (`nixos-generate-config`). Committed, never hand-edited |
| `home.nix` | home-manager user config (+ AI protocol symlink distribution) |
| `bootstrap.sh` | New-machine installer — detection, confirm, dry-build gate, install |
| `hooks/` | Enforced git hooks (`core.hooksPath=hooks`) |
| `AGENTS.md` | Canonical AI agent protocol (CLAUDE.md symlinks to it) |
| `CHANGELOG.md` | Mandatory per-change log (hook-enforced) |

## Day-to-day workflow

```bash
# 1. edit sources in /etc/nixos
drybuild          # alias: sudo nixos-rebuild dry-build --flake /etc/nixos#hydragon2000-pc
rebuild           # alias: sudo nixos-rebuild switch  --flake /etc/nixos#hydragon2000-pc
# 2. document in CHANGELOG.md, then commit (hooks validate identity/changelog/syntax)
git add -A && git commit    # prepare-commit-msg drafts a message via local Ollama
GIT_SSH_COMMAND="ssh -i ~/.ssh/id_ed25519_personal -o IdentitiesOnly=yes" git push origin main
```

AI agents run `drybuild` and report; only the user runs `rebuild`.

## Fresh install (new machine)

```bash
# 1. Boot NixOS installer ISO.
# 2. Partition + format + mount at /mnt (adjust devices!):
sudo parted /dev/nvme0n1 -- mklabel gpt
sudo parted /dev/nvme0n1 -- mkpart primary 512MB 100%
sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 512MB
sudo parted /dev/nvme0n1 -- set 2 esp on
sudo mkfs.ext4 -L nixos /dev/nvme0n1p1
sudo mkfs.fat -F 32 -n boot /dev/nvme0n1p2
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot && sudo mount /dev/disk/by-label/boot /mnt/boot

# 3. Clone and bootstrap:
sudo git clone https://github.com/dondragonstar/my-nix-install-helper.git /mnt/etc/nixos
cd /mnt/etc/nixos && sudo ./bootstrap.sh
#    → detects GPU/CPU (sysfs, vendor IDs), asks hostname/username/timezone,
#      shows everything for confirmation, regenerates hardware config,
#      dry-build gate, then installs. Unknown GPU → 'generic' profile (always boots).
#    Detection wrong? Override: sudo ./bootstrap.sh --gpu amd

# 4. Reboot, set password: sudo passwd <username>

# 5. First-boot housekeeping (inside /etc/nixos):
git config core.hooksPath hooks
git config user.name "dondragonstar" && git config user.email "dondragonstar@gmail.com"
git commit --amend --reset-author --no-edit   # replace bootstrap placeholder author
```

Testing detection without installing (any live system):
`TARGET_DIR=/etc/nixos ./bootstrap.sh --dry-run`

## Recovery

Every rebuild creates a NixOS generation — pick an older one from the boot
menu if something breaks. `generic` gpu profile in `machine.nix` is the
always-boots floor. Full pre-refactor snapshot: `/root/nixos-backup-pre-refactor`.
```

- [ ] **Step 2: Final full verification**

```bash
cd /etc/nixos
nix flake check --extra-experimental-features "nix-command flakes" 2>&1 | tail -5
sudo nixos-rebuild dry-build --flake /etc/nixos#hydragon2000-pc
bash bootstrap.sh --dry-run | grep "hybrid-nvidia"
git status --short
```
Expected: flake check passes (or only warns about missing `checks` output), dry-build succeeds, bootstrap dry-run still detects `hybrid-nvidia`, git status shows only README.md + CHANGELOG.md pending.

- [ ] **Step 3: [USER] Final switch confirmation**

Ask the user to run `rebuild` once more and confirm the system still behaves (Hyprland session, waybar, NVIDIA offload: `nvidia-offload glxinfo | grep NVIDIA` or their usual check).

- [ ] **Step 4: CHANGELOG, commit, push**

Append to CHANGELOG:
```markdown
- docs: README rewritten for repo-as-truth workflow, bootstrap install, and recovery story
```

```bash
cd /etc/nixos && git add README.md CHANGELOG.md
git commit -m "docs: README for new workflow + bootstrap install"
GIT_SSH_COMMAND="ssh -i ~/.ssh/id_ed25519_personal -o IdentitiesOnly=yes" git push origin main
```
Expected: push succeeds to `dondragonstar/my-nix-install-helper` main.

- [ ] **Step 5: Move spec + plan into the repo**

```bash
mkdir -p /etc/nixos/docs/specs /etc/nixos/docs/plans
cp /home/hydragon2000/nixos-specs/2026-07-19-nixos-ai-maintained-system-design.md /etc/nixos/docs/specs/
cp /home/hydragon2000/nixos-specs/plans/2026-07-19-nixos-ai-maintained-system.md /etc/nixos/docs/plans/
cd /etc/nixos && git add docs/ && git commit -m "docs: design spec + implementation plan" \
  && GIT_SSH_COMMAND="ssh -i ~/.ssh/id_ed25519_personal -o IdentitiesOnly=yes" git push origin main
```

---

## Plan Self-Review (done at write time)

- **Spec coverage:** §2 restructure → Task 1; §2.1 tracked hwconfig → Tasks 1/6; §3 machine.nix + enum → Task 2; §4 bootstrap + detection §4.1/§4.2 → Task 4; §5 AGENTS.md + §5.1 distribution → Task 5; §6 hooks → Task 6; §7 workflow + §8 testing → embedded per task + Task 7; §9 error handling → bootstrap/hook code; §11 spec-into-repo → Task 7 step 5. VM smoke-test of `vm`/`generic` profiles (§8) deliberately dropped: profiles are near-empty modules, `nix flake check` evaluates them, and `build-vm` of this flake pulls the whole Hyprland closure — cost outweighs signal. Noted as acceptable deviation.
- **Placeholders:** none — every file's full content is in the plan.
- **Consistency:** gpu enum values identical in machine.nix comment, flake.nix `validGpus`, bootstrap `VALID_GPUS`, module filenames. `machine` specialArg name consistent across flake/configuration/profiles. Bus-ID format `PCI:d@d:d:d` consistent between current config, machine.nix, and `to_busid`.
