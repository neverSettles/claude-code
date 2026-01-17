#!/usr/bin/env bash

# Choices Plugin - Stream Monitor
# Reads streaming output from multiple Claude instances and interleaves them
# Compatible with bash 3.x (macOS default)

set -uo pipefail

WORKTREE_BASE="$1"
NUM_VARIANTS="$2"

# Colors for different variants
COLOR_1='\033[0;36m'  # Cyan
COLOR_2='\033[0;33m'  # Yellow
COLOR_3='\033[0;35m'  # Magenta
COLOR_4='\033[0;32m'  # Green
COLOR_5='\033[0;34m'  # Blue
COLOR_6='\033[0;31m'  # Red
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Function to get color for variant
get_color() {
  case $1 in
    1) echo "$COLOR_1" ;;
    2) echo "$COLOR_2" ;;
    3) echo "$COLOR_3" ;;
    4) echo "$COLOR_4" ;;
    5) echo "$COLOR_5" ;;
    6) echo "$COLOR_6" ;;
    *) echo "$RESET" ;;
  esac
}

# Print header
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}📊 Live Streaming Output - $NUM_VARIANTS Variants${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo ""

# Legend
echo -e "Legend:"
for i in $(seq 1 "$NUM_VARIANTS"); do
  color=$(get_color "$i")
  echo -e "  ${color}[V$i]${RESET} Variant $i"
done
echo ""
echo -e "${BOLD}─────────────────────────────────────────────────────────────${RESET}"
echo ""

# Start monitoring each variant's stream in background
MONITOR_PIDS=""

for i in $(seq 1 "$NUM_VARIANTS"); do
  VARIANT_DIR="$WORKTREE_BASE/choices-variant-$i"
  STREAM_FILE="$VARIANT_DIR/.choices-output/stream.jsonl"
  LOG_FILE="$VARIANT_DIR/.choices-output/claude.log"
  COLOR=$(get_color "$i")

  # Background process to monitor this variant's stream
  (
    # Wait for stream file to exist (with timeout)
    WAIT_COUNT=0
    while [[ ! -f "$STREAM_FILE" ]] && [[ ! -f "$LOG_FILE" ]] && [[ $WAIT_COUNT -lt 60 ]]; do
      sleep 0.5
      WAIT_COUNT=$((WAIT_COUNT + 1))
    done

    # Prefer stream file, fall back to log file
    TARGET_FILE="$STREAM_FILE"
    if [[ ! -f "$STREAM_FILE" ]] && [[ -f "$LOG_FILE" ]]; then
      TARGET_FILE="$LOG_FILE"
    fi

    if [[ ! -f "$TARGET_FILE" ]]; then
      echo -e "${COLOR}[V$i]${RESET} ⚠️  No output file found"
      exit 1
    fi

    # Tail the file and process output
    tail -f "$TARGET_FILE" 2>/dev/null | while IFS= read -r line; do
      # Skip empty lines
      [[ -z "$line" ]] && continue

      # Check if it's JSON (streaming format) or plain text
      if [[ "$line" == "{"* ]]; then
        # JSON format - parse based on type
        msg_type=$(echo "$line" | sed -n 's/.*"type":"\([^"]*\)".*/\1/p' | head -1)

        case "$msg_type" in
          "system")
            echo -e "${COLOR}[V$i]${RESET} 🚀 Starting..."
            ;;
          "assistant")
            # Check if it has text content
            if echo "$line" | grep -q '"type":"text"'; then
              # Extract text from content array
              text=$(echo "$line" | sed -n 's/.*"text":"\([^"]*\)".*/\1/p' | tail -1)
              if [[ -n "$text" ]]; then
                # Unescape common JSON escapes
                text=$(echo "$text" | sed 's/\\n/\n/g; s/\\t/\t/g; s/\\"/'\''/g')
                echo -e "${COLOR}[V$i]${RESET} $text"
              fi
            fi
            # Check if it's a tool use
            if echo "$line" | grep -q '"type":"tool_use"'; then
              tool_name=$(echo "$line" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p' | head -1)
              if [[ -n "$tool_name" ]]; then
                echo -e "${COLOR}[V$i]${RESET} ${DIM}🔧 Using tool: $tool_name${RESET}"
              fi
            fi
            ;;
          "result")
            # Extract final result text
            result_text=$(echo "$line" | sed -n 's/.*"result":"\([^"]*\)".*/\1/p' | head -1)
            if [[ -n "$result_text" ]]; then
              result_text=$(echo "$result_text" | sed 's/\\n/\n/g; s/\\t/\t/g; s/\\"/'\''/g')
              echo -e "${COLOR}[V$i]${RESET} ${BOLD}✅ $result_text${RESET}"
            else
              echo -e "${COLOR}[V$i]${RESET} ${BOLD}✅ Completed${RESET}"
            fi
            ;;
        esac
      else
        # Plain text - just output with prefix
        echo -e "${COLOR}[V$i]${RESET} $line"
      fi
    done
  ) &

  MONITOR_PIDS="$MONITOR_PIDS $!"
done

# Wait for all variants to complete by checking status files
COMPLETED_COUNT=0
TIMEOUT=300  # 5 minute timeout
ELAPSED=0

while [[ $COMPLETED_COUNT -lt $NUM_VARIANTS ]] && [[ $ELAPSED -lt $TIMEOUT ]]; do
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  COMPLETED_COUNT=0

  for i in $(seq 1 "$NUM_VARIANTS"); do
    STATUS_FILE="$WORKTREE_BASE/choices-variant-$i/.choices-output/status"
    if [[ -f "$STATUS_FILE" ]] && grep -q "COMPLETED" "$STATUS_FILE" 2>/dev/null; then
      COMPLETED_COUNT=$((COMPLETED_COUNT + 1))
    fi
  done
done

# Give a moment for final output to flush
sleep 2

# Kill monitor processes
for pid in $MONITOR_PIDS; do
  kill "$pid" 2>/dev/null || true
done

# Print completion summary
echo ""
echo -e "${BOLD}─────────────────────────────────────────────────────────────${RESET}"
echo ""

if [[ $ELAPSED -ge $TIMEOUT ]]; then
  echo -e "${BOLD}⚠️  Timeout reached. Some variants may not have completed.${RESET}"
else
  echo -e "${BOLD}🎉 All $NUM_VARIANTS variants complete!${RESET}"
fi

echo ""
echo "Next steps:"
echo "  /choices-review    - Compare all implementations"
echo "  /choices-pick N    - Select variant N as winner"
echo "  /choices-cancel    - Discard all variants"
echo ""
