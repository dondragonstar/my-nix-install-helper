# Changelog

Newest first. Every commit that touches a `.nix` file MUST add an entry here
(enforced by `hooks/pre-commit`). One line per change: what and why.

- home.nix, hyprland.nix: force MOZ_ENABLE_WAYLAND=0 (session vars + Hyprland env) — Firefox 153 native-Wayland popups collapse to 10px slivers (GTK layout bug, repro'd on fresh profile; XWayland renders correctly)
- hyprland.nix: import HYPRLAND_INSTANCE_SIGNATURE into systemd user manager — fixes quickshell workspace highlights (quickshell had no IPC socket env, logged "$HYPRLAND_INSTANCE_SIGNATURE is unset")
- flake.nix, configuration.nix: pin Hyprland to v0.56.1 input and override package+xdph — fixes Firefox popup sliver bug (hyprwm/Hyprland#14936, missing from nixpkgs 26.05's 0.55.4)
- home.nix: switch default bar from waybar to quickshell
- hyprland.nix, quickshell.nix: start quickshell via exec-once=systemctl --user start quickshell (graphical-session.target refuses manual start — RefuseManualStart=yes)

## 2026-07-30
- feat: udev rule in storage.nix to expose internal NTFS partitions in file-manager sidebars (UDISKS_SYSTEM=0)
- feat: storage module (modules/system/storage.nix) — NTFS (ntfs3/ntfs-3g) read-only, udisks2 + gvfs for click-to-mount drives and Android MTP phones (libmtp/jmtpfs); fixes phone-over-USB and Windows partitions not appearing in Thunar
- feat: bin/rebuild script — nixos-rebuild switch then auto-commit (via Ollama gen-commit-msg.py) and git push; rebuild alias updated to point at the script
- refactor: split home.nix into 7 focused modules under modules/home/ (hyprland, walker, waybar, theme, git, zsh, apps)
- feat: waybar managed via systemd user service instead of hyprland exec-once (survives rebuilds)
- revert: remove antigravity wrapper, use plain package
- feat: auto garbage collection (weekly, 7d retention) and nix store optimisation via systemd timers
- feat: nix-community cachix substituter for faster binary cache hits
- feat: new shell aliases — gc (garbage collect), bootbuild (safe rebuild on next boot), check (flake check)
- feat: add nix-output-monitor for readable build output
- fix: remove duplicate firefox and ollama from systemPackages (already provided by programs.firefox and services.ollama)
## 2026-07-28
- feat: nixup — curses TUI for selective flake input updating (Catppuccin Mocha theme, multi-select, dry-build, Walker entry, SUPER+U)

## 2026-07-22
- feat: add brave browser to home.packages

## 2026-07-21
- fix: add `hide_quick_activation = true` and `quick_activate = []` to Walker config to suppress F1-F4 top results
- fix: clear Walker `quick_activate` default to stop F1-F4 appearing as search results

## 2026-07-19
- feat: add `update` and `gcsize` shell aliases for flake upgrade + GC size estimate
- refactor: /etc/nixos is now the git repo root; repo/ subdir and sync.sh copy loop retired (zero-drift: the live config IS the repo)
- chore: hardware-configuration.nix is now tracked (flakes only see git-tracked files)
- feat: machine.nix isolates all machine-specific values; flake.nix validates gpu against a closed enum with a clear eval-time error
- feat: modules/hardware/ profiles (hybrid-nvidia, nvidia, amd, intel, vm, generic); configuration.nix is now fully machine-agnostic; ollama-cuda moved into nvidia profiles
- feat: bootstrap.sh — new-machine installer; sysfs-only GPU/CPU detection, numeric vendor IDs, confirm loop, generic fallback, dry-build gate before nixos-install
- feat: AGENTS.md canonical AI protocol; distributed as ~/AGENTS.md + ~/GEMINI.md symlinks via home-manager, CLAUDE.md symlink at repo root, import in ~/.claude/CLAUDE.md
- feat: committed git hooks (core.hooksPath=hooks) — identity check, CHANGELOG gate, hardware-config guard, nix syntax gate; optional Ollama commit messages
- docs: README rewritten for repo-as-truth workflow, bootstrap install, and recovery story
