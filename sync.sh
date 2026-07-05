#!/run/current-system/sw/bin/bash
set -e

REPO_DIR="/etc/nixos/repo"
NIXOS_DIR="/etc/nixos"
CONFIGS_MASTER="$HOME/CONFIGS_MASTER.md"

FILES=(
  configuration.nix
  flake.nix
  flake.lock
  home.nix
  theme.nix
  waybar-config.jsonc
  alacritty.toml
)

echo "=== Syncing NixOS configs to repo ==="

for f in "${FILES[@]}"; do
  if [ -f "$NIXOS_DIR/$f" ]; then
    cp "$NIXOS_DIR/$f" "$REPO_DIR/$f"
    echo "  copied $f"
  fi
done

# Also sync CONFIGS_MASTER.md so changes to it are tracked in the repo
if [ -f "$CONFIGS_MASTER" ]; then
  cp "$CONFIGS_MASTER" "$REPO_DIR/CONFIGS_MASTER.md"
  echo "  copied CONFIGS_MASTER.md"
fi

cd "$REPO_DIR"

if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
  echo "  No changes to commit."
else
  git add -A

  # Build meaningful commit message from actual diffs
  CHANGED_FILES=$(git diff --cached --name-only | tr '\n' ' ')
  STAT_LINE=$(git diff --cached --stat | tail -1)
  COMMIT_MSG="config: ${CHANGED_FILES}(${STAT_LINE})"

  git commit -m "$COMMIT_MSG" -m "$(git diff --cached --stat)"
  echo "  Committed: $COMMIT_MSG"

  echo "  Pushing to origin..."
  git push origin main
  echo "  Push done."
fi

echo "=== Sync complete ==="
