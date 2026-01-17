#!/bin/bash

# Choices Plugin - Review Script
# Shows status and comparison of all variants

set -euo pipefail

STATE_FILE=".claude/choices.local.md"

# Check for active session
if [[ ! -f "$STATE_FILE" ]]; then
  echo "❌ No active choices session found" >&2
  echo "" >&2
  echo "Start a new session with: /choices \"Your prompt\"" >&2
  exit 1
fi

# Parse state file
WORKTREE_BASE=$(grep '^worktree_base:' "$STATE_FILE" | sed 's/worktree_base: *//' | tr -d '"')
NUM_VARIANTS=$(grep '^num_variants:' "$STATE_FILE" | sed 's/num_variants: *//')
BASE_BRANCH=$(grep '^base_branch:' "$STATE_FILE" | sed 's/base_branch: *//' | tr -d '"')
BASE_COMMIT=$(grep '^base_commit:' "$STATE_FILE" | sed 's/base_commit: *//' | tr -d '"')

echo "═══════════════════════════════════════════════════════════"
echo "📊 Choices Review - $NUM_VARIANTS Variants"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "🌿 Base: $BASE_BRANCH @ ${BASE_COMMIT:0:8}"
echo ""

# Check status of each variant
COMPLETED=0
RUNNING=0
FAILED=0

for i in $(seq 1 $NUM_VARIANTS); do
  VARIANT_DIR="$WORKTREE_BASE/choices-variant-$i"
  STATUS_FILE="$VARIANT_DIR/.choices-output/status"
  DONE_FILE="$VARIANT_DIR/.choices-output/DONE.md"
  LOG_FILE="$VARIANT_DIR/.choices-output/claude.log"

  echo "┌─────────────────────────────────────────────────────────"
  echo "│ Variant $i"
  echo "├─────────────────────────────────────────────────────────"

  if [[ -f "$STATUS_FILE" ]] && grep -q "COMPLETED" "$STATUS_FILE" 2>/dev/null; then
    echo "│ Status: ✅ Completed"
    ((COMPLETED++))

    # Show summary if available
    if [[ -f "$DONE_FILE" ]]; then
      echo "│"
      echo "│ Summary:"
      sed 's/^/│   /' "$DONE_FILE" | head -20
    fi

    # Show diff stats
    echo "│"
    echo "│ Changes:"
    cd "$VARIANT_DIR"
    DIFF_STATS=$(git diff --stat "$BASE_COMMIT" HEAD 2>/dev/null | tail -1 || echo "No changes")
    echo "│   $DIFF_STATS"
    cd - > /dev/null

  elif [[ -d "$VARIANT_DIR" ]]; then
    # Check if process is still running
    if pgrep -f "choices-variant-$i" > /dev/null 2>&1; then
      echo "│ Status: 🔄 Running..."
      ((RUNNING++))

      # Show last few lines of log
      if [[ -f "$LOG_FILE" ]]; then
        echo "│"
        echo "│ Recent activity:"
        tail -3 "$LOG_FILE" 2>/dev/null | sed 's/^/│   /' || true
      fi
    else
      echo "│ Status: ❌ Failed or stopped"
      ((FAILED++))

      # Show error from log if available
      if [[ -f "$LOG_FILE" ]]; then
        echo "│"
        echo "│ Last output:"
        tail -5 "$LOG_FILE" 2>/dev/null | sed 's/^/│   /' || true
      fi
    fi
  else
    echo "│ Status: ❓ Worktree not found"
    ((FAILED++))
  fi

  echo "└─────────────────────────────────────────────────────────"
  echo ""
done

# Summary
echo "═══════════════════════════════════════════════════════════"
echo "📈 Summary: $COMPLETED completed, $RUNNING running, $FAILED failed"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [[ $RUNNING -gt 0 ]]; then
  echo "⏳ Some variants are still running. Check back later with /choices-review"
  echo ""
elif [[ $COMPLETED -gt 0 ]]; then
  echo "🎯 Ready to pick a winner!"
  echo ""
  echo "   /choices-pick N     - Select variant N"
  echo "   /choices-diff N     - See detailed diff for variant N"
  echo "   /choices-cancel     - Discard all and cleanup"
  echo ""
fi

# Generate comparison data for Claude to analyze
if [[ $COMPLETED -gt 0 ]]; then
  echo "═══════════════════════════════════════════════════════════"
  echo "📋 Detailed Comparison"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  for i in $(seq 1 $NUM_VARIANTS); do
    VARIANT_DIR="$WORKTREE_BASE/choices-variant-$i"
    STATUS_FILE="$VARIANT_DIR/.choices-output/status"

    if [[ -f "$STATUS_FILE" ]] && grep -q "COMPLETED" "$STATUS_FILE" 2>/dev/null; then
      echo "### Variant $i - Full Diff"
      echo ""
      echo '```diff'
      cd "$VARIANT_DIR"
      git diff "$BASE_COMMIT" HEAD 2>/dev/null || echo "No diff available"
      cd - > /dev/null
      echo '```'
      echo ""
    fi
  done
fi
