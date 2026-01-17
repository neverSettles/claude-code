#!/bin/bash

# Choices Plugin - Pick Script
# Selects a winning variant and merges it to the main branch

set -euo pipefail

STATE_FILE=".claude/choices.local.md"
VARIANT_NUM="${1:-}"

# Check for active session
if [[ ! -f "$STATE_FILE" ]]; then
  echo "❌ No active choices session found" >&2
  exit 1
fi

# Parse state file
WORKTREE_BASE=$(grep '^worktree_base:' "$STATE_FILE" | sed 's/worktree_base: *//' | tr -d '"')
NUM_VARIANTS=$(grep '^num_variants:' "$STATE_FILE" | sed 's/num_variants: *//')
BASE_BRANCH=$(grep '^base_branch:' "$STATE_FILE" | sed 's/base_branch: *//' | tr -d '"')
BASE_COMMIT=$(grep '^base_commit:' "$STATE_FILE" | sed 's/base_commit: *//' | tr -d '"')

# Validate variant number
if [[ -z "$VARIANT_NUM" ]]; then
  echo "❌ Error: Please specify which variant to pick" >&2
  echo "" >&2
  echo "Usage: /choices-pick N" >&2
  echo "" >&2
  echo "Where N is the variant number (1-$NUM_VARIANTS)" >&2
  echo "" >&2
  echo "Run /choices-review to see all variants first." >&2
  exit 1
fi

if ! [[ "$VARIANT_NUM" =~ ^[0-9]+$ ]] || [[ "$VARIANT_NUM" -lt 1 ]] || [[ "$VARIANT_NUM" -gt "$NUM_VARIANTS" ]]; then
  echo "❌ Error: Invalid variant number '$VARIANT_NUM'" >&2
  echo "" >&2
  echo "Please choose a number between 1 and $NUM_VARIANTS" >&2
  exit 1
fi

VARIANT_DIR="$WORKTREE_BASE/choices-variant-$VARIANT_NUM"
BRANCH_NAME="choices/$BASE_BRANCH/variant-$VARIANT_NUM"

# Check variant exists and is completed
if [[ ! -d "$VARIANT_DIR" ]]; then
  echo "❌ Error: Variant $VARIANT_NUM worktree not found" >&2
  exit 1
fi

STATUS_FILE="$VARIANT_DIR/.choices-output/status"
if [[ ! -f "$STATUS_FILE" ]] || ! grep -q "COMPLETED" "$STATUS_FILE" 2>/dev/null; then
  echo "❌ Error: Variant $VARIANT_NUM is not completed yet" >&2
  echo "" >&2
  echo "Run /choices-review to check status." >&2
  exit 1
fi

echo "═══════════════════════════════════════════════════════════"
echo "🏆 Picking Variant $VARIANT_NUM as the winner!"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Show what will be merged
echo "📋 Changes to be applied:"
echo ""
cd "$VARIANT_DIR"
git diff --stat "$BASE_COMMIT" HEAD
cd - > /dev/null
echo ""

# Get the commit from the variant
VARIANT_COMMIT=$(cd "$VARIANT_DIR" && git rev-parse HEAD)

# Cherry-pick the changes or copy files
echo "🔄 Applying changes from variant $VARIANT_NUM..."
echo ""

# Option 1: Cherry-pick (preserves commit)
# git cherry-pick "$VARIANT_COMMIT"

# Option 2: Copy changed files (simpler, avoids merge conflicts)
cd "$VARIANT_DIR"
# Get both committed changes AND new untracked files (excluding .choices-output)
CHANGED_FILES=$(git diff --name-only "$BASE_COMMIT" HEAD 2>/dev/null || true)
UNTRACKED_FILES=$(git ls-files --others --exclude-standard | grep -v "^\.choices-output" || true)
ALL_FILES=$(echo -e "$CHANGED_FILES\n$UNTRACKED_FILES" | sort -u | grep -v "^$" || true)
cd - > /dev/null

REPO_ROOT=$(git rev-parse --show-toplevel)

if [[ -z "$ALL_FILES" ]]; then
  echo "   (No files to copy)"
else
  for file in $ALL_FILES; do
    SOURCE="$VARIANT_DIR/$file"
    DEST="$REPO_ROOT/$file"

    if [[ -f "$SOURCE" ]]; then
      # Create directory if needed
      mkdir -p "$(dirname "$DEST")"
      cp "$SOURCE" "$DEST"
      echo "   ✓ Copied: $file"
    elif [[ ! -f "$SOURCE" ]] && [[ -f "$DEST" ]]; then
      # File was deleted in variant
      rm "$DEST"
      echo "   ✓ Deleted: $file"
    fi
  done
fi

echo ""
echo "✅ Changes applied successfully!"
echo ""

# Cleanup
echo "🧹 Cleaning up worktrees..."
"${BASH_SOURCE%/*}/cleanup-choices.sh"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "🎉 Done! Variant $VARIANT_NUM has been applied."
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "   git diff              - Review the changes"
echo "   git add -A && git commit -m 'message'  - Commit the changes"
echo ""
