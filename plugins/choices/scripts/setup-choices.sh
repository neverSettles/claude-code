#!/bin/bash

# Choices Plugin - Setup Script
# Creates git worktrees and spawns parallel Claude instances

set -euo pipefail

# Default configuration
DEFAULT_VARIANTS=3
STREAM_MODE=false
VARIATION_HINTS=(
  "Focus on clean, simple, readable code. Prefer straightforward solutions over clever ones."
  "Focus on efficiency and performance. Optimize for speed and resource usage."
  "Focus on flexibility and extensibility. Design for easy future modifications."
)

# Parse arguments
PROMPT=""
NUM_VARIANTS=$DEFAULT_VARIANTS

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Choices - Parallel exploration with git worktrees

USAGE:
  /choices "PROMPT" [OPTIONS]

ARGUMENTS:
  PROMPT         The task for Claude to implement (required)

OPTIONS:
  --variants N   Number of parallel variants (default: 3, max: 10)
  --stream       Show live streaming output from all variants
  -h, --help     Show this help message

DESCRIPTION:
  Creates N git worktrees, spawns Claude in each with slightly different
  focus hints, and lets you compare all implementations side-by-side.

EXAMPLES:
  /choices "Add user authentication with JWT"
  /choices "Refactor the cache layer" --variants 5
  /choices "Implement the REST API endpoint" --variants 2

VARIATION HINTS:
  Each variant gets a different focus:
  1. Simplicity - Clean, readable code
  2. Performance - Efficient, optimized code
  3. Extensibility - Flexible, future-proof code

WORKFLOW:
  1. /choices "prompt"     - Start parallel exploration
  2. /choices-review       - Compare all implementations
  3. /choices-pick N       - Select variant N as winner
  4. /choices-cancel       - Cancel and cleanup

HELP_EOF
      exit 0
      ;;
    --variants)
      if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "❌ Error: --variants requires a number (1-10)" >&2
        exit 1
      fi
      if [[ "$2" -lt 1 ]] || [[ "$2" -gt 10 ]]; then
        echo "❌ Error: --variants must be between 1 and 10" >&2
        exit 1
      fi
      NUM_VARIANTS="$2"
      shift 2
      ;;
    --stream)
      STREAM_MODE=true
      shift
      ;;
    *)
      if [[ -z "$PROMPT" ]]; then
        PROMPT="$1"
      else
        PROMPT="$PROMPT $1"
      fi
      shift
      ;;
  esac
done

# Validate prompt
if [[ -z "$PROMPT" ]]; then
  echo "❌ Error: No prompt provided" >&2
  echo "" >&2
  echo "Usage: /choices \"Your task description\" [--variants N]" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  /choices \"Add user authentication\"" >&2
  echo "  /choices \"Refactor the API\" --variants 5" >&2
  exit 1
fi

# Check if git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "❌ Error: Not in a git repository" >&2
  echo "" >&2
  echo "Choices requires git worktrees, which need a git repository." >&2
  exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  echo "⚠️  Warning: You have uncommitted changes" >&2
  echo "" >&2
  echo "It's recommended to commit or stash changes before running /choices" >&2
  echo "to ensure each variant starts from the same state." >&2
  echo "" >&2
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Check for existing choices session
if [[ -f ".claude/choices.local.md" ]]; then
  echo "❌ Error: A choices session is already active" >&2
  echo "" >&2
  echo "Use /choices-review to see current variants" >&2
  echo "Use /choices-pick N to select a winner" >&2
  echo "Use /choices-cancel to cancel and start fresh" >&2
  exit 1
fi

# Get current branch and commit
CURRENT_BRANCH=$(git branch --show-current)
CURRENT_COMMIT=$(git rev-parse HEAD)
REPO_ROOT=$(git rev-parse --show-toplevel)
WORKTREE_BASE="$REPO_ROOT/.choices-worktrees"

echo "🎯 Starting parallel exploration with $NUM_VARIANTS variants"
echo ""
echo "📝 Prompt: $PROMPT"
echo "🌿 Base branch: $CURRENT_BRANCH"
echo "📍 Base commit: ${CURRENT_COMMIT:0:8}"
echo ""

# Create worktree directory
mkdir -p "$WORKTREE_BASE"

# Create state file
mkdir -p .claude
cat > .claude/choices.local.md << EOF
---
active: true
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
num_variants: $NUM_VARIANTS
base_branch: "$CURRENT_BRANCH"
base_commit: "$CURRENT_COMMIT"
worktree_base: "$WORKTREE_BASE"
variants: []
---

# Choices Session

**Prompt:** $PROMPT

## Variants

EOF

# Create worktrees and spawn Claude instances
PIDS=()
for i in $(seq 1 $NUM_VARIANTS); do
  VARIANT_NAME="choices-variant-$i"
  VARIANT_DIR="$WORKTREE_BASE/$VARIANT_NAME"
  BRANCH_NAME="choices/$CURRENT_BRANCH/variant-$i"

  # Get variation hint (cycle through if more variants than hints)
  HINT_INDEX=$(( (i - 1) % ${#VARIATION_HINTS[@]} ))
  HINT="${VARIATION_HINTS[$HINT_INDEX]}"

  echo "🔧 Creating variant $i..."

  # Create branch and worktree
  git branch -D "$BRANCH_NAME" 2>/dev/null || true
  git worktree remove "$VARIANT_DIR" --force 2>/dev/null || true
  git worktree add -b "$BRANCH_NAME" "$VARIANT_DIR" "$CURRENT_COMMIT"

  # Create output directory for this variant
  mkdir -p "$VARIANT_DIR/.choices-output"

  # Build the full prompt with variation hint
  FULL_PROMPT="$PROMPT

---
Implementation guidance: $HINT
---

When you're done, create a file called .choices-output/DONE.md with a brief summary of your implementation approach."

  # Spawn Claude in background
  # Write prompt to file to avoid shell escaping issues
  echo "$FULL_PROMPT" > "$VARIANT_DIR/.choices-output/prompt.txt"

  # Find the correct claude binary (prefer local install over npm/volta)
  CLAUDE_BIN="${CLAUDE_BIN:-}"
  if [[ -z "$CLAUDE_BIN" ]]; then
    if [[ -x "$HOME/.claude/local/claude" ]]; then
      CLAUDE_BIN="$HOME/.claude/local/claude"
    else
      CLAUDE_BIN="claude"
    fi
  fi

  (
    cd "$VARIANT_DIR"
    # Use --print with --dangerously-skip-permissions to avoid interactive prompts
    # Read prompt from file to handle special characters safely
    if [[ "$STREAM_MODE" == "true" ]]; then
      # Stream mode: output JSON stream for real-time monitoring
      # Note: --verbose is required with --output-format stream-json
      "$CLAUDE_BIN" --print --dangerously-skip-permissions --verbose --output-format stream-json \
        "$(cat .choices-output/prompt.txt)" 2>&1 | tee ".choices-output/stream.jsonl" > ".choices-output/claude.log"
    else
      # Normal mode: just capture output
      "$CLAUDE_BIN" --print --dangerously-skip-permissions "$(cat .choices-output/prompt.txt)" > ".choices-output/claude.log" 2>&1
    fi
    echo "COMPLETED" > ".choices-output/status"
  ) &

  PID=$!
  PIDS+=($PID)

  # Update state file
  cat >> .claude/choices.local.md << EOF
### Variant $i
- **Branch:** $BRANCH_NAME
- **Directory:** $VARIANT_DIR
- **Focus:** ${HINT:0:50}...
- **PID:** $PID
- **Status:** running

EOF

  echo "   ✓ Variant $i started (PID: $PID)"
done

# Save PIDs to state file for monitoring
echo "" >> .claude/choices.local.md
echo "## Process IDs" >> .claude/choices.local.md
echo "pids: [${PIDS[*]}]" >> .claude/choices.local.md

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "🚀 All $NUM_VARIANTS variants are now running in parallel!"
echo "═══════════════════════════════════════════════════════════"

if [[ "$STREAM_MODE" == "true" ]]; then
  # Run the stream monitor in foreground
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  "$SCRIPT_DIR/monitor-streams.sh" "$WORKTREE_BASE" "$NUM_VARIANTS"
else
  echo ""
  echo "📊 Monitor progress:"
  echo "   /choices-review    - Check status and compare implementations"
  echo ""
  echo "🎯 When complete:"
  echo "   /choices-pick N    - Select variant N as the winner"
  echo ""
  echo "❌ To cancel:"
  echo "   /choices-cancel    - Stop all variants and cleanup"
  echo ""
  echo "📁 Worktrees created at: $WORKTREE_BASE"
  echo ""
fi
