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
always-boots floor. Full pre-refactor snapshot: `~/nixos-backup-pre-refactor`.
