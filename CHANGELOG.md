# Changelog

Newest first. Every commit that touches a `.nix` file MUST add an entry here
(enforced by `hooks/pre-commit`). One line per change: what and why.

## 2026-07-30
- refactor: split home.nix into 7 focused modules under modules/home/ (hyprland, walker, waybar, theme, git, zsh, apps)
- feat: waybar managed via systemd user service instead of hyprland exec-once (survives rebuilds)
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
