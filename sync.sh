#!/run/current-system/sw/bin/bash
set -e

REPO_DIR="/etc/nixos/repo"
NIXOS_DIR="/etc/nixos"
CONFIGS_MASTER="$HOME/CONFIGS_MASTER.md"
GIT_OPS="$HOME/GIT_OPS.md"
CLAUDE_CONFIG="$HOME/.claude/CLAUDE.md"

FILES=(
  configuration.nix
  flake.nix
  flake.lock
  home.nix
  theme.nix
  waybar-config.jsonc
  alacritty.toml
  walker-style.css
  walker-layout.xml
  keybinds.nix
)

echo "=== Syncing NixOS configs to repo ==="

for f in "${FILES[@]}"; do
  if [ -f "$NIXOS_DIR/$f" ]; then
    cp "$NIXOS_DIR/$f" "$REPO_DIR/$f"
    echo "  copied $f"
  fi
done

# Sync home-root instruction files so they're backed up in the repo
for f in "$CONFIGS_MASTER" "$GIT_OPS"; do
  dest="$REPO_DIR/$(basename "$f")"
  if [ -f "$f" ]; then
    cp "$f" "$dest"
    echo "  copied $(basename "$f")"
  fi
done

# Sync CLAUDE.md (AI global instructions)
if [ -f "$CLAUDE_CONFIG" ]; then
  mkdir -p "$REPO_DIR/.claude"
  cp "$CLAUDE_CONFIG" "$REPO_DIR/.claude/CLAUDE.md"
  echo "  copied .claude/CLAUDE.md"
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
