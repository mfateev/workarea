# Git Safety Hook - Changelog

## Version 2.0 - Worktree Location Enforcement

### Added

**Worktree Location Validation** - Ensures worktrees only exist in the proper task structure.

The hook now validates that any git worktree (detected by `.git` file) is located at the correct path:

```
✅ VALID:   workspaces/<name>/tasks/<task>/<repo>/
❌ INVALID: workspaces/<name>/random-worktree/
❌ INVALID: workspaces/<name>/tasks/<repo>/ (missing task level)
❌ INVALID: /anywhere/else/
```

**Why This Matters:**

Without this validation, Claude could:
- Work in orphaned worktrees created manually
- Commit to worktrees in the wrong location
- Get confused by multiple git contexts
- Bypass the task management system

**With this validation:**
- All worktrees must be created via `/new-task` or `/resume-task`
- Worktrees outside the task structure are immediately blocked
- Clear error messages guide Claude to the correct location

### Test Coverage

Added 4 new test scenarios in `test-hook-scenarios.sh`:

1. **Worktree in correct location** (allowed) - `tasks/<task>/<repo>/`
2. **Worktree outside tasks/** (blocked) - `workspaces/<name>/random/`
3. **Worktree at wrong depth** (blocked) - `tasks/<repo>/`
4. **Worktree outside workarea** (blocked) - `/tmp/other-project/`

**All 21 tests pass** ✅

### Error Message Example

```bash
🛑 Git Safety Check: Worktree in unexpected location!

You're in a git worktree that's NOT inside the task structure:
  Working directory: /workarea/workspaces/projects/random-worktree
  Command: git commit -m "Fix bug"

Worktrees should ONLY exist inside task directories:
  ✅ Expected: workspaces/<name>/tasks/<task>/<repo>/
  ❌ Found: /workarea/workspaces/projects/random-worktree

This could be:
  - A worktree created in the wrong location
  - A different project's worktree
  - An orphaned worktree that should be removed

To fix:
  1. Use /resume-task to set up proper task worktrees
  2. Remove this worktree: git worktree remove /workarea/workspaces/projects/random-worktree
```

### Technical Details

**Detection Method:**
- Check if `.git` is a file (worktree) vs directory (main repo)
- Validate path matches regex: `/tasks/[^/]+/[^/]+/?$`
- Block operations before any other validations run

**Performance:**
- No additional git commands needed
- Simple filesystem checks only
- Negligible overhead

### Files Modified

- `.claude/hooks/git-safety-check.sh` - Added worktree location validation
- `.claude/hooks/test-hook-scenarios.sh` - Added 4 new test cases
- `.claude/hooks/README.md` - Updated documentation
- `.claude/hooks/CHANGELOG.md` - This file

---

## Version 1.0 - Initial Release

### Features

1. **Smart location check** - Distinguishes task metadata from code files
2. **Fork-First Policy enforcement** - Blocks pushes to upstream
3. **Destructive operation protection** - Blocks dangerous commands in workarea root
4. **Read-only command allowlist** - Status, log, diff always work

### Files Created

- `.claude/hooks/git-safety-check.sh` - Main hook script
- `.claude/settings.json` - Hook configuration
- `.claude/hooks/README.md` - Complete documentation
- `.claude/hooks/test-hook-scenarios.sh` - Test suite
