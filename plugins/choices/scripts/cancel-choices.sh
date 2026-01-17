#!/bin/bash

# Choices Plugin - Cancel Script
# Cancels an active choices session and cleans up

set -euo pipefail

STATE_FILE=".claude/choices.local.md"

# Check for active session
if [[ ! -f "$STATE_FILE" ]]; then
  echo "❌ No active choices session to cancel" >&2
  echo "" >&2
  echo "Start a new session with: /choices \"Your prompt\"" >&2
  exit 1
fi

# Parse some info for the message
NUM_VARIANTS=$(grep '^num_variants:' "$STATE_FILE" | sed 's/num_variants: *//')
STARTED_AT=$(grep '^started_at:' "$STATE_FILE" | sed 's/started_at: *//' | tr -d '"')

echo "═══════════════════════════════════════════════════════════"
echo "❌ Cancelling Choices Session"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Session started: $STARTED_AT"
echo "Variants: $NUM_VARIANTS"
echo ""

# Run cleanup
"${BASH_SOURCE%/*}/cleanup-choices.sh"

echo ""
echo "Session cancelled. Start a new one with /choices \"prompt\""
