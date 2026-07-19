# NixOS AI-Maintained Reproducible System — Design Spec

**Date:** 2026-07-19
**Status:** Approved by user (brainstorming session)
**Scope:** Restructure `/etc/nixos` for hardware portability, universal AI agent protocol enforcement, and zero-drift git workflow.

## 1. Vision & Goals

The system is maintained by AI agents and must be reproducible on any machine. NixOS is the substrate: declarative config means AI edits text rather than mutating state; generations give rollback; `nixos-rebuild dry-build` gives a verification gate.

Goals:

1. **Hardware portability** — clone + bootstrap works on any machine. All machine-specific state isolated to exactly two files.
2. **Universal AI protocol** — one canonical protocol file every AI agent tool discovers, plus mechanical enforcement that blocks violations.
3. **Zero drift** — the git repo IS the live config. No copy-based sync loop.

Constraints (from user):

- Fleet shape: one machine at a time (current PC + future replacements). No multi-host flake outputs needed.
- Enforcement level: docs + mechanical checks (git hooks). Not docs-only; full dry-build-on-every-commit gate not required.
- Partitioning stays manual (no disko / nixos-anywhere).
- AI never runs `nixos-rebuild switch` — user runs it.

## 2. Repo Restructure — `/etc/nixos` Becomes the Repo

Current state: `/etc/nixos/` (live config) + `/etc/nixos/repo/` (git mirror), held together by `sync.sh` copying files and generating Ollama commit messages. Two copies = drift risk.

Target state:

```
/etc/nixos/                     ← git repo root
├── flake.nix                   ← reads machine.nix; no hardcoded hostname/username
├── machine.nix                 ← ALL machine-specific knobs (committed; describes current machine)
├── configuration.nix           ← GPU section removed; imports modules/hardware/<gpu>.nix
├── modules/
│   └── hardware/
│       ├── nvidia.nix          ← current NVIDIA config, bus IDs read from machine.nix
│       ├── hybrid-nvidia.nix   ← PRIME offload (iGPU + NVIDIA dGPU)
│       ├── amd.nix
│       ├── intel.nix
│       ├── vm.nix              ← virtio/QXL/VMware guest graphics
│       └── generic.nix         ← kernel modesetting only; guaranteed-boot floor
├── hardware-configuration.nix  ← COMMITTED (see 2.1); regenerated per machine by nixos-generate-config
├── home.nix                    ← unchanged role; gains AGENTS.md symlink deployment
├── theme.nix, keybinds.nix, waybar-config.jsonc, alacritty.toml, walker-*  ← unchanged
├── bootstrap.sh                ← new-machine installer (section 4)
├── hooks/
│   ├── pre-commit              ← protocol enforcement (section 6)
│   └── prepare-commit-msg      ← optional Ollama commit-msg generation (gen-commit-msg.py survives here)
├── AGENTS.md                   ← canonical AI protocol (section 5)
├── CHANGELOG.md                ← append-only change log (AI must update per change)
├── README.md                   ← rewritten for new flow
└── .gitignore                  ← result symlinks, backups (NOT hardware-configuration.nix, see 2.1)
```

### 2.1 Amendment: hardware-configuration.nix is committed, not gitignored

Nix flakes only see **git-tracked** files during pure evaluation. Once `/etc/nixos` is the repo root, a gitignored `hardware-configuration.nix` would be invisible to `nix build` / `nixos-rebuild --flake` and every build breaks. Therefore it is **committed**. This is also better for the chosen fleet shape (one machine at a time): the repo fully describes the current machine, giving true disaster recovery. On a new machine, `bootstrap.sh` regenerates and recommits it. The pre-commit guard (section 6) changes from "reject if staged" to "reject **manual** edits — staging it requires `ALLOW_HWCONFIG=1`", which bootstrap sets when committing a legitimately regenerated file.

Migration steps:

1. Preserve history: move `/etc/nixos/repo/.git` to `/etc/nixos/.git`; commit the restructure on top.
2. Delete `/etc/nixos/repo/` after migration.
3. `chown -R hydragon2000 /etc/nixos` — user-owned so AI agents and git work without sudo. Only `nixos-rebuild` needs root.
4. `flake.lock` stays committed (reproducibility). `hardware-configuration.nix` is committed (see 2.1).
5. `CONFIGS_MASTER.md` and `GIT_OPS.md` content folds into `AGENTS.md` + `README.md`; standalone files retired from repo root sync.
6. Remote unchanged: `git@github.com:dondragonstar/my-nix-install-helper.git` (personal identity: dondragonstar).

## 3. machine.nix — Single Machine-Identity File

All human-meaningful machine-specific choices in one committed file:

```nix
{
  hostname = "hydragon2000-pc";
  username = "hydragon2000";
  timezone = "Asia/Kolkata";          # current value read from configuration.nix at migration
  gpu = "nvidia";                     # closed enum, see below
  # Only required when gpu = "nvidia" or "hybrid-nvidia":
  nvidiaBusIds = {
    nvidiaBusId = "PCI:1@0:0:0";
    # intelBusId / amdgpuBusId added by bootstrap when hybrid
  };
}
```

Rules:

- `gpu` is a **closed enum**: `nvidia | amd | intel | hybrid-nvidia | vm | generic`. `flake.nix` asserts membership with a clear error message listing valid values — a typo produces an eval error naming the problem, never a mystery boot failure.
- `flake.nix` imports `machine.nix` and passes values via `specialArgs` (replacing today's hardcoded `let` block).
- `configuration.nix` imports `modules/hardware/${machine.gpu}.nix`.
- Committed (unlike `hardware-configuration.nix`) because it documents the current machine and is human-readable; bootstrap rewrites it on a new machine.

## 4. Bootstrap — Watertight New-Machine Install

`bootstrap.sh`, run from the NixOS installer ISO after manual partitioning (README documents partitioning, as today).

Flow:

1. Prompt hostname, username, timezone (flags `--hostname`, `--username`, `--timezone` for non-interactive use).
2. Run `nixos-generate-config --root /mnt`.
3. Detect GPU and CPU (below).
4. Show detection results + chosen profile; **user confirms or overrides**. Never silently applied.
5. Write `machine.nix`.
6. `nixos-rebuild dry-build --flake` — mandatory gate. Failure stops before touching the machine; still inside installer ISO.
7. `nixos-install --flake /mnt/etc/nixos#<hostname>`.

### 4.1 Hardware detection — layered, never trusted, never bricks

**Principle: detection is a suggestion; `generic` profile is the floor.** The system boots even when detection fails completely.

GPU detection:

- **Primary source: sysfs, not lspci.** Read `/sys/bus/pci/devices/*/class` (values `0x0300xx` and `0x0302xx` = display controllers) and the corresponding `/sys/bus/pci/devices/*/vendor`. Pure kernel filesystem — zero tool dependencies, works on every Linux. `lspci` used only as a cross-check when present.
- **Numeric vendor IDs, never name-string parsing:**
  - `0x10de` → NVIDIA
  - `0x1002` → AMD
  - `0x8086` → Intel
  - `0x15ad` (VMware), `0x1af4` (virtio), `0x1234` (QXL) → `vm` profile
- **Multi-GPU:** two vendors present (Intel+NVIDIA or AMD+NVIDIA) → `hybrid-nvidia`; bus IDs extracted from the sysfs PCI paths (needed for PRIME offload).
- **Nothing detected / unknown vendor →** `generic` profile (kernel modesetting, no vendor driver). Prints a warning, not an error.
- **Manual override at every branch:** `bootstrap.sh --gpu amd` etc. bypasses detection.

CPU detection:

- `vendor_id` from `/proc/cpuinfo`: `GenuineIntel` → `hardware.cpu.intel.updateMicrocode = true`; `AuthenticAMD` → `hardware.cpu.amd.updateMicrocode = true`. Unknown vendor → skip microcode (harmless).

Failure-mode guarantee: worst case at every branch is the `generic` profile — machine boots to a working desktop on modesetting; user flips one word in `machine.nix` later and rebuilds. Nothing bricks.

### 4.2 Validation gates (belt + suspenders)

- Closed-enum assert in `flake.nix` (section 3).
- Mandatory `dry-build` before `nixos-install`.
- Pre-commit hook parses changed `.nix` files (section 6), so syntax errors never reach git history either.

## 5. AGENTS.md — Universal AI Protocol

One canonical file at repo root. `AGENTS.md` is the cross-tool standard (Codex, Gemini CLI, Cursor, aider read it; Claude reads it via symlink).

Content (merged from existing docs + user's rules):

1. **Always document changes** — every change gets a `CHANGELOG.md` entry (enforced by hook, section 6).
2. **Update README.md for major changes** — new modules, workflow changes, new machine-specific knobs.
3. **Git identity routing** (from `GIT_OPS.md`): personal repos → `git@github.com:` + dondragonstar; professional repos → `git@github-professional:` + DevaJ2005. Verify `git config user.name`/`user.email` before commit. Never use `--author` to set an AI name.
4. **NixOS boundaries:**
   - Never edit `~/.config/` files that home-manager manages — edit `/etc/nixos` sources.
   - Never edit `hardware-configuration.nix` (enforced by hook).
   - Always run `nixos-rebuild dry-build` and report the result before suggesting a rebuild.
   - AI never runs `nixos-rebuild switch` — the user runs it.
5. **Machine-specific changes go in `machine.nix` only** — never hardcode hostname/username/GPU into shared files.

### 5.1 Distribution — declarative, via home-manager

`home.nix` deploys the one file everywhere agents look:

- Repo root: `CLAUDE.md` → symlink to `AGENTS.md` (committed symlink in git).
- Home: `~/.claude/CLAUDE.md` gains `@/etc/nixos/AGENTS.md`-style import (or symlink), `~/AGENTS.md` and `~/GEMINI.md` symlinked via `home.file`.

Edit once, every agent on the machine sees it. A new machine gets the full protocol automatically on first rebuild — protocol propagation is itself reproducible.

## 6. Mechanical Enforcement — Git Hooks

Hooks live in `hooks/` (committed), activated via `git config core.hooksPath hooks` (set by bootstrap and documented in README).

`pre-commit` checks, in order:

1. **Identity check:** `user.name`/`user.email` match the expected identity for this repo's remote (GIT_OPS rules). Mismatch → reject with fix command.
2. **Changelog gate:** commit touches any `*.nix` file but `CHANGELOG.md` is not in the staged diff → reject with message "document the change in CHANGELOG.md".
3. **Hardware config guard:** `hardware-configuration.nix` staged without `ALLOW_HWCONFIG=1` in the environment → reject. Blocks manual edits; bootstrap (and deliberate regeneration) sets the variable.
4. **Nix syntax gate:** every staged `.nix` file passes `nix-instantiate --parse` (fast, no eval). Parse error → reject.

`prepare-commit-msg` (optional, kept from current setup): `gen-commit-msg.py` generates message via local Ollama (`qwen2.5-coder:3b`) when no message given.

Claude Code hook (`settings.json` PreToolUse) blocking `nixos-rebuild switch` execution by AI: nice-to-have, out of scope for this spec's first implementation.

## 7. Daily Workflow (sync.sh retired)

```
edit /etc/nixos sources
  → nixos-rebuild dry-build --flake /etc/nixos   (AI runs, reports)
  → sudo nixos-rebuild switch --flake /etc/nixos  (USER runs)
  → git add + commit                              (hooks validate)
  → git push
```

`sync.sh` is deleted — no copies to sync. The `rebuild`/`drybuild` zsh aliases update to point at the new flake path (unchanged path, same aliases likely work as-is; verify at implementation).

## 8. Testing Strategy

- **Restructure correctness:** after migration, `nixos-rebuild dry-build` must produce the same closure as pre-migration (`nixos-rebuild build` + compare `result` derivation) — proves the refactor is behavior-preserving.
- **Enum + assert:** deliberately set `gpu = "typo"` and confirm the eval error message is clear.
- **Hardware profiles:** `nix flake check` evaluates all six profiles; `nixos-rebuild build-vm` smoke-tests the `vm` and `generic` profiles bootably.
- **Bootstrap:** run detection portion (`--dry-run` flag: detect + print, change nothing) on the current machine — must detect NVIDIA and print current bus IDs. Full install path tested in a QEMU VM when feasible.
- **Hooks:** unit-test each rejection case (wrong identity, missing changelog, staged hardware config, bad nix syntax) with throwaway commits.

## 9. Error Handling Summary

| Failure | Behavior |
|---|---|
| GPU detection finds nothing/unknown | `generic` profile, warning, system boots |
| Wrong `gpu` value in machine.nix | Clear flake eval error listing valid values |
| Dry-build fails during bootstrap | Install aborted, machine untouched, still in ISO |
| Commit violates protocol | Hook rejects with actionable message |
| Ollama unavailable for commit msg | prepare-commit-msg falls through to manual message |

## 10. Out of Scope

- Multi-host flake outputs (one machine at a time per user decision).
- disko / nixos-anywhere declarative partitioning.
- Secrets management (agenix/sops-nix) — no secrets currently in repo; revisit if that changes.
- Claude Code PreToolUse hook blocking `nixos-rebuild switch` (future enhancement).

## 11. Implementation Note

This spec was written from a sandboxed session where `/etc/nixos` is mounted read-only (visible at `/.host-etc/nixos`). Implementation must run in a session with real write access to `/etc/nixos`. First implementation step: move this spec into the repo (`docs/specs/`) and commit it.
