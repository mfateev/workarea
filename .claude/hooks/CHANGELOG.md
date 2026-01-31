# Workarea Validation Hooks - Changelog

## Version 3.0 - Directory Structure Validation

### Added

**New Hook: directory-structure-check.sh** - Enforces workarea directory architecture.

This hook validates that Claude follows the workarea structure and only creates directories/clones repositories in authorized locations:

```
workarea/
├── repos/           ✅ Git clones ONLY
├── workspaces/      ✅ Workspace container ONLY
│   └── <name>/.git  ✅ Must be git repo
├── tasks/           ❌ NOT allowed at root
└── anything-else/   ❌ NOT allowed at root
```

**What It Validates:**

1. **Git Clone Location** - Must target `repos/` directory only
   ```bash
   ✅ git clone <url> repos/sdk-java
   ❌ git clone <url> sdk-java  # Wrong location
   ```

2. **Root Directory Creation** - Only `workspaces/` and `repos/` allowed
   ```bash
   ✅ mkdir workspaces
   ✅ mkdir repos
   ❌ mkdir tasks        # Not allowed at root
   ❌ mkdir projects     # Not allowed at root
   ```

3. **Workspace Git Repositories** - Workspaces must be git repos
   ```bash
   ✅ cd workspaces/issues && git commit  # If initialized
   ❌ cd workspaces/issues && git commit  # If not initialized
   ❌ cd workspaces && git init          # In container
   ```

### Why This Matters

**Without this validation, Claude could:**
- Clone repositories into random locations
- Create directories that break the architecture
- Work in non-git-tracked workspaces
- Lose task metadata (not tracked in git)

**With this validation:**
- All repositories stay in `repos/` (shared across workspaces)
- Workarea root stays clean (only infrastructure)
- Workspace metadata is always git-tracked
- Architecture is enforced automatically

### Test Coverage

Added `test-directory-structure.sh` with 23 test scenarios:

1. **Git clone operations** (4 tests)
   - Clone to repos/ (allowed)
   - Clone to workarea root (blocked)
   - Clone to workspaces/ (blocked)
   - Clone to tasks/ (blocked)

2. **Directory creation at root** (5 tests)
   - Create repos/ (allowed)
   - Create workspaces/ (allowed)
   - Create tasks/ (blocked)
   - Create random directories (blocked)
   - Create subdirectories (allowed)

3. **Workspace git validation** (4 tests)
   - Git in initialized workspace (allowed)
   - Git init in workspace (allowed)
   - Git in workspaces container (blocked)
   - Git commit in container (blocked)

4. **Other scenarios** (10 tests)
   - Non-Bash tools (pass through)
   - Operations outside workarea (pass through)
   - Safe operations (allowed)
   - Move/copy operations (validated)

**All 23 tests pass** ✅

### Error Message Examples

**Git clone to wrong location:**
```bash
🛑 Directory Structure Check: Clone target violates architecture!

You're trying to clone a repository outside the 'repos/' directory:
  Command: git clone <url> sdk-java
  Target: /workarea/sdk-java

Workarea architecture requires:
  ✅ Correct: Clone repositories into repos/
     Example: git clone <url> repos/sdk-java
```

**Unauthorized directory creation:**
```bash
🛑 Directory Structure Check: Invalid directory at workarea root!

You're trying to create/modify a directory at workarea root:
  Command: mkdir tasks
  Target: /workarea/tasks

Workarea root ONLY allows these directories:
  ✅ workspaces/  - Container for workspace repositories
  ✅ repos/       - Shared git repository clones
  ❌ tasks/       - Not allowed at root level
```

**Uninitialized workspace:**
```bash
🛑 Directory Structure Check: Workspace is not a git repository!

You're trying to run git commands in a workspace that's not initialized:
  Workspace: /workarea/workspaces/new-workspace
  Command: git commit -m "test"

Workspaces MUST be git repositories to track task metadata.
```

### Hook Execution Order

Both hooks run in sequence for comprehensive validation:

1. **directory-structure-check.sh** - Validates WHERE things are (architecture)
2. **git-safety-check.sh** - Validates WHAT you're doing (operations)

### Files Added

- `.claude/hooks/directory-structure-check.sh` - New validation hook
- `.claude/hooks/test-directory-structure.sh` - New test suite
- `.claude/hooks/DIRECTORY_STRUCTURE.md` - Complete documentation

### Files Modified

- `.claude/settings.json` - Added directory-structure-check.sh to PreToolUse
- `.claude/hooks/git-safety-check.sh` - Removed duplicate git clone validation
- `.claude/hooks/README.md` - Added overview of both hooks
- `.claude/hooks/CHANGELOG.md` - This file

---

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
