# GIT OPS — Mandatory for AI Agents

## Golden Rule

**NEVER add yourself (the AI / Claude) as a contributor, author, co-author, or committer to any git commit.** Your name must never appear in `git log`, commit messages, or any git metadata.

## Pre-Commit Identity Check

Before ANY commit or push, verify the correct git author:

```bash
# For repos under ~/ (personal)
git config user.name   # must be: dondragonstar
git config user.email  # must be: dondragonstar@gmail.com

# For repos under ~/Projects/professional/
git config user.name   # must be: DevaJ2005
git config user.email  # must be: devajb01@gmail.com
```

If identity is wrong, **do NOT commit**. Stop and investigate.

## Identity Routing

| Location | SSH Key | Git User | GitHub Account |
|---|---|---|---|
| `~/` (any repo) | `id_ed25519_personal` | dondragonstar | dondragonstar |
| `~/Projects/professional/` | `id_ed25519_professional` (via `github-professional` SSH host) | DevaJ2005 | vencorhq org |

This is enforced by `~/.config/git/config`:
- `[includeIf "gitdir:~/"]` loads `~/.gitconfig-personal`
- `[includeIf "gitdir:~/Projects/professional/"]` loads `~/.gitconfig-professional` (overrides)

## Commit Flow

```bash
# 1. Verify identity first
git config user.name && git config user.email

# 2. Commit (NEVER use --author to set an AI name)
git add -A && git commit -m "..."

# 3. Push (uses correct SSH key automatically per the remote URL)
git push
```

## Remote URL Rules

- **Personal repos**: remote must use `git@github.com:` (uses personal SSH key)
- **Professional repos**: remote must use `git@github-professional:` (uses professional SSH key)

If a professional repo's remote shows `git@github.com:`, the identity will be wrong. Fix it:
```bash
# Only for professional repos that still use git@github.com:
git remote set-url origin git@github-professional:vencorehq/vencore-platform.git
```

## Troubleshooting

If you see the wrong user after `git config user.name`:
- Check `~/.config/git/config` order: `gitdir:~/` must come BEFORE `gitdir:~/Projects/professional/`
- If the file is a broken symlink to `/nix/store/...`, replace it with a plain file (see the working version below)
- Re-run `git config --list | grep user` to see all values and their processing order

## Source of Truth

Edit `/etc/nixos/home.nix` for permanent git config changes (under `programs.git` block).  
Then run `/etc/nixos/repo/sync.sh` to push changes.  
Runtime file `~/.config/git/config` is NOT managed by Nix (replaced with plain file to avoid Nix store read-only issue).
