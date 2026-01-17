#!/bin/bash

# Choices Plugin - Cleanup Script
# Removes all worktrees and branches, cleans up state

set -euo pipefail

STATE_FILE=".claude/choices.local.md"

# Check for state file
if [[ ! -f "$STATE_FILE" ]]; then
  echo "No active choices session to clean up."
  exit 0
fi

# Parse state file
WORKTREE_BASE=$(grep '^worktree_base:' "$STATE_FILE" | sed 's/worktree_base: *//' | tr -d '"')
NUM_VARIANTS=$(grep '^num_variants:' "$STATE_FILE" | sed 's/num_variants: *//')
BASE_BRANCH=$(grep '^base_branch:' "$STATE_FILE" | sed 's/base_branch: *//' | tr -d '"')

echo "🧹 Cleaning up choices session..."
echo ""

# Kill any running Claude processes for this session
for i in $(seq 1 $NUM_VARIANTS); do
  pkill -f "choices-variant-$i" 2>/dev/null || true
done

# Remove worktrees
for i in $(seq 1 $NUM_VARIANTS); do
  VARIANT_DIR="$WORKTREE_BASE/choices-variant-$i"
  BRANCH_NAME="choices/$BASE_BRANCH/variant-$i"

  if [[ -d "$VARIANT_DIR" ]]; then
    echo "   Removing worktree: choices-variant-$i"
    git worktree remove "$VARIANT_DIR" --force 2>/dev/null || rm -rf "$VARIANT_DIR"
  fi

  # Delete the branch
  git branch -D "$BRANCH_NAME" 2>/dev/null || true
done

# Remove worktree base directory if empty
if [[ -d "$WORKTREE_BASE" ]]; then
  rmdir "$WORKTREE_BASE" 2>/dev/null || rm -rf "$WORKTREE_BASE"
fi

# Remove state file
rm -f "$STATE_FILE"

# Prune worktree references
git worktree prune 2>/dev/null || true

echo ""
echo "✅ Cleanup complete!"
