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
