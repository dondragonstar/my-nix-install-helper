# Changelog

Newest first. Every commit that touches a `.nix` file MUST add an entry here
(enforced by `hooks/pre-commit`). One line per change: what and why.

## 2026-07-19
- refactor: /etc/nixos is now the git repo root; repo/ subdir and sync.sh copy loop retired (zero-drift: the live config IS the repo)
- chore: hardware-configuration.nix is now tracked (flakes only see git-tracked files)
- feat: machine.nix isolates all machine-specific values; flake.nix validates gpu against a closed enum with a clear eval-time error
- feat: modules/hardware/ profiles (hybrid-nvidia, nvidia, amd, intel, vm, generic); configuration.nix is now fully machine-agnostic; ollama-cuda moved into nvidia profiles
- feat: bootstrap.sh — new-machine installer; sysfs-only GPU/CPU detection, numeric vendor IDs, confirm loop, generic fallback, dry-build gate before nixos-install
