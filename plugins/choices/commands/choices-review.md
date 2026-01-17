---
description: "Review and compare all implementation variants"
allowed-tools:
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/review-choices.sh)
  - Read(.claude/choices.local.md)
  - Read
---

# Choices Review - Compare Variants

Review the status and compare all implementation variants.

## Instructions

1. Run the review script to get status and diffs:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/review-choices.sh"
```

2. Analyze the output and help the user understand:
   - Which variants are complete, running, or failed
   - The key differences between implementations
   - Pros and cons of each approach

3. If all variants are complete, provide a recommendation:
   - Summarize each variant's approach
   - Highlight trade-offs (simplicity vs performance vs extensibility)
   - Suggest which variant might be best for their needs

4. Guide the user to next steps:
   - `/choices-pick N` to select variant N
   - `/choices-cancel` to discard all and start over

## Comparison Tips

When comparing variants, look for:
- Code organization and structure
- Error handling approaches
- Performance considerations
- Extensibility and maintainability
- Test coverage (if applicable)
