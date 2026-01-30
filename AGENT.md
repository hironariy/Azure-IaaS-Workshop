# Agent Rules

This document contains rules for AI agents working on this repository.

## GitHub Issue Operations

**IMPORTANT:** All GitHub Issue operations (comments, creation, updates) MUST use file-based approach.

### Rule: Use `--body-file` Instead of `--body`

When adding comments or creating issues via `gh` CLI:

❌ **DO NOT** use inline body:
```bash
gh issue comment 1 --body "Comment text here"
```

✅ **DO** use file-based approach:
```bash
# 1. Create a temporary file with the comment content
echo "Comment text here" > /tmp/gh-comment.md

# 2. Use --body-file flag
gh issue comment 1 --body-file /tmp/gh-comment.md

# 3. Clean up
rm /tmp/gh-comment.md
```

### Reason
- Shell escaping issues with special characters (backticks, quotes, exclamation marks)
- Heredoc syntax often fails in terminal tool
- File-based approach is more reliable and predictable

### Applies To
- `gh issue comment`
- `gh issue create`
- `gh issue edit`
- `gh pr comment`
- `gh pr create`
