---
description: "Select a winning variant and apply its changes"
argument-hint: "N"
allowed-tools:
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/pick-choice.sh:*)
  - Read(.claude/choices.local.md)
---

# Choices Pick - Select Winner

Select a winning variant and apply its changes to the current branch.

## Instructions

1. If no variant number is provided, remind the user to specify one:
   - Run `/choices-review` first to see all variants
   - Then `/choices-pick N` where N is the variant number

2. If a variant number is provided, run the pick script:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/pick-choice.sh" $ARGUMENTS
```

3. After the script completes:
   - Confirm which changes were applied
   - Remind user to review with `git diff`
   - Suggest committing the changes

## What Happens

1. Validates the variant exists and is completed
2. Copies all changed files from the variant to the current directory
3. Cleans up all worktrees and branches
4. Removes the choices session state

## Usage

- `/choices-pick 1` - Select variant 1
- `/choices-pick 2` - Select variant 2
- `/choices-pick 3` - Select variant 3
