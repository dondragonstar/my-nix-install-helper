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

The rebuild engine is `nh` (Nix Helper) — `programs.nh` in configuration.nix,
`nvd` prints package diffs on every switch, `nom` shows the build tree. nh
escalates to root internally, so **never prefix it with sudo**. GC is
nh-managed (`nh clean` after every switch, `--keep-since 4d --keep 3`; the old
weekly `nix.gc` timer was removed).

```bash
# 1. edit sources in /etc/nixos
drybuild          # alias: nh os build           build next generation, no switch
rebuild           # alias: nh os switch          nvd diff + nom tree; auto-commit + push via bin/rebuild
update            # alias: nh os switch --update lock update + rebuild + switch, one shot
gc                # alias: nh clean all          GC (also runs automatically after every switch)
# 2. document in CHANGELOG.md, then commit (hooks validate identity/changelog/syntax)
git add -A && git commit    # prepare-commit-msg drafts a message via local Ollama
GIT_SSH_COMMAND="ssh -i ~/.ssh/id_ed25519_personal -o IdentitiesOnly=yes" git push origin main
```

AI agents run `drybuild` (or `nix build --dry-run ...toplevel`) and report;
only the user runs `rebuild`.

## Boot — silent + Plymouth

Silent until `greetd`/`ReGreet`; failures still report (`systemd.show_status=auto`).

| Param | Effect |
|---|---|
| `quiet` `splash` | suppress kernel/initrd scroll |
| `loglevel=3` + `boot.consoleLogLevel 0` / `boot.initrd.verbose false` | errors only |
| `systemd.show_status=auto` / `rd.systemd.show_status=auto` | show only failed units |
| `rd.udev.log_level=3` | quiet udev in initrd |

Plymouth `hydra` (`modules/system/plymouth.nix`, `boot.initrd.systemd.enable` holds framebuffer till greeter) from repo-tracked `assets/branding/screensaver.txt` (JetBrainsMono Nerd Font via explicit `pkgs.nerd-fonts.jetbrains-mono` file + `FONTCONFIG_FILE` boundary; KMS `nvidia-drm.modeset=1` already in `hybrid-nvidia`).

| Helper | What |
|---|---|
| `hydra-branding-preview [bg] [fg] [src] [out]` | `convert label@` → `/tmp/preview.png` |
| `hydra-branding-sync` | `cp ~/.config/branding/screensaver.txt → assets/branding/screensaver.txt` |

```bash
# edit → preview → sync → diff → build
vim ~/.config/branding/screensaver.txt
hydra-branding-preview && xdg-open /tmp/preview.png
hydra-branding-sync
git -C /etc/nixos diff assets/branding/screensaver.txt
nh os build   # real build — dry-run is: nix build --dry-run /etc/nixos#nixosConfigurations.hydragon2000-pc.config.system.build.toplevel
```

Verification — Esc during boot exposes log (check, not promise); rollback is `boot.plymouth.enable = false` or remove `quiet`/`splash` in `configuration.nix`, not unverified `plymouth.enable=0`:

```bash
grep -q quiet /proc/cmdline && echo PASS
plymouth-set-default-theme --list | grep -q hydra && echo PASS
systemctl --failed --no-pager; journalctl -b -p warning --no-pager | head -n 20
bootctl list | grep nixos-generation; ls /boot/loader/entries/*.conf | head
nix flake check /etc/nixos --no-build   # AI-safe preview (no switch)
```

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
