# Choices Plugin

Parallel exploration using git worktrees - spawn multiple Claude instances to implement the same task with different approaches, then pick the best one.

## Overview

The Choices plugin enables **parallel implementation exploration**. Instead of getting one implementation from Claude, you get multiple variants with different focuses (simplicity, performance, extensibility) and can compare them side-by-side before choosing the best one.

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    /choices "Add auth"                       │
└─────────────────────────────────────────────────────────────┘
                           │
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │ Variant 1│    │ Variant 2│    │ Variant 3│
    │ Simplicity│   │Performance│   │Extensible│
    │ worktree │    │ worktree │    │ worktree │
    └──────────┘    └──────────┘    └──────────┘
           │               │               │
           └───────────────┼───────────────┘
                           ▼
                  /choices-review
                  (compare all)
                           │
                           ▼
                  /choices-pick 2
                  (select winner)
```

1. **Start**: `/choices "Your task"` creates git worktrees and spawns Claude instances
2. **Work**: Each variant implements the task with a different focus
3. **Review**: `/choices-review` shows status and compares implementations
4. **Pick**: `/choices-pick N` selects the winner and applies changes
5. **Done**: Other variants are cleaned up automatically

## Commands

### `/choices "PROMPT" [--variants N]`

Start parallel exploration.

```bash
/choices "Add user authentication with JWT"
/choices "Refactor the cache layer" --variants 5
/choices "Implement REST endpoint" --variants 2
```

**Options:**
- `--variants N` - Number of parallel variants (default: 3, max: 10)

### `/choices-review`

Check status and compare all implementations.

Shows:
- Completion status of each variant
- Summary from each implementation
- Git diff statistics
- Full diffs for comparison

### `/choices-pick N`

Select variant N as the winner.

```bash
/choices-pick 1  # Select variant 1
/choices-pick 2  # Select variant 2
```

This will:
1. Copy changed files to your working directory
2. Clean up all worktrees and branches
3. Leave you ready to commit

### `/choices-cancel`

Cancel the session and clean up all worktrees.

## Variation Hints

Each variant receives a different implementation focus:

| Variant | Focus | Hint |
|---------|-------|------|
| 1 | Simplicity | Clean, readable code. Straightforward solutions. |
| 2 | Performance | Efficient, optimized code. Speed and resource usage. |
| 3 | Extensibility | Flexible, future-proof code. Easy modifications. |

For more than 3 variants, hints cycle through the list.

## Requirements

- **Git repository**: The plugin uses git worktrees
- **Clean working tree**: Recommended (warns if uncommitted changes)
- **Claude Code CLI**: Uses `claude --print` for each variant

## File Locations

- **Worktrees**: `.choices-worktrees/choices-variant-N/`
- **State file**: `.claude/choices.local.md`
- **Variant output**: `.choices-worktrees/choices-variant-N/.choices-output/`

## Example Workflow

```bash
# Start exploration with 3 variants
/choices "Add a user profile page with avatar upload"

# Wait for completion, then review
/choices-review

# Compare the implementations, pick the best one
/choices-pick 2

# Review and commit
git diff
git add -A && git commit -m "Add user profile page"
```

## Troubleshooting

### "A choices session is already active"

Cancel the existing session first:
```bash
/choices-cancel
```

### "Not in a git repository"

The plugin requires git worktrees. Initialize a git repo:
```bash
git init
git add -A && git commit -m "Initial commit"
```

### Variant stuck or failed

Check the variant's log:
```bash
cat .choices-worktrees/choices-variant-1/.choices-output/claude.log
```

## Architecture

```
plugins/choices/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── commands/
│   ├── choices.md           # /choices command
│   ├── choices-review.md    # /choices-review command
│   ├── choices-pick.md      # /choices-pick command
│   └── choices-cancel.md    # /choices-cancel command
├── scripts/
│   ├── setup-choices.sh     # Creates worktrees, spawns Claude
│   ├── review-choices.sh    # Generates comparison report
│   ├── pick-choice.sh       # Applies winner, cleans up
│   ├── cancel-choices.sh    # Cancels session
│   └── cleanup-choices.sh   # Removes worktrees and state
└── README.md
```

## Author

Christopher Settles ([@neverSettles](https://github.com/neverSettles))

## License

MIT
