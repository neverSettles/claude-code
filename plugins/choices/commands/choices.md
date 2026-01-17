---
description: "Start parallel exploration - create multiple implementation variants using git worktrees"
argument-hint: '"PROMPT" [--variants N]'
allowed-tools:
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-choices.sh:*)
  - Read(.claude/choices.local.md)
---

# Choices - Parallel Implementation Exploration

Start parallel exploration by running the setup script with the user's prompt.

## Instructions

1. Execute the setup script with the provided arguments:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-choices.sh" $ARGUMENTS
```

2. After the script completes, inform the user:
   - How many variants were started
   - That they can use `/choices-review` to check progress
   - That they can use `/choices-pick N` to select a winner when done

## Usage Examples

- `/choices "Add user authentication"` - Start 3 variants (default)
- `/choices "Refactor the cache" --variants 5` - Start 5 variants
- `/choices "Implement REST endpoint" --variants 2` - Start 2 variants

## What Happens

1. Creates git worktrees for each variant
2. Spawns parallel Claude Code instances
3. Each variant gets a different focus hint:
   - Variant 1: Simplicity focus
   - Variant 2: Performance focus
   - Variant 3: Extensibility focus
4. Variants work independently in their own directories
5. User reviews all implementations and picks the best one
