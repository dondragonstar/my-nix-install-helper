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

  # Generate commit message using local AI (qwen2.5-coder via Ollama)
  DIFF_CONTENT=$(git diff --cached)
  COMMIT_MSG=$(echo "$DIFF_CONTENT" | python3 "$REPO_DIR/gen-commit-msg.py" 2>/dev/null || true)

  # Fallback if AI fails
  if [ -z "$COMMIT_MSG" ]; then
    CHANGED=$(git diff --cached --name-only | tr '\n' ' ')
    STAT=$(git diff --cached --stat | tail -1)
    COMMIT_MSG="config: update ${CHANGED}(${STAT})"
    echo "  (AI unavailable, using auto-generated message)"
  fi

  git commit -m "$COMMIT_MSG"
  echo "  Committed: $COMMIT_MSG"

  echo "  Pushing to origin..."
  git push origin main
  echo "  Push done."
fi

echo "=== Sync complete ==="
