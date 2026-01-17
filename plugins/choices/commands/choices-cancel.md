---
description: "Cancel active choices session and cleanup all worktrees"
allowed-tools:
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/cancel-choices.sh)
  - Read(.claude/choices.local.md)
---

# Choices Cancel - Abort Session

Cancel the active choices session and clean up all worktrees.

## Instructions

1. Run the cancel script:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/cancel-choices.sh"
```

2. Confirm to the user that:
   - All variant worktrees have been removed
   - All variant branches have been deleted
   - The session state has been cleared
   - They can start a new session with `/choices "prompt"`

## What Gets Cleaned Up

- All git worktrees in `.choices-worktrees/`
- All `choices/*/variant-*` branches
- The `.claude/choices.local.md` state file
- Any running Claude processes for the session

## When to Use

- User wants to abandon current variants and start fresh
- Something went wrong during execution
- User changed their mind about the task
