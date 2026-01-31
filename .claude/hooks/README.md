# Workarea Validation Hooks

The workarea uses two validation hooks to enforce architecture and prevent common mistakes:

1. **[directory-structure-check.sh](DIRECTORY_STRUCTURE.md)** - Validates directory architecture
   - Git clone only in `repos/`
   - Root directories limited to `workspaces/` and `repos/`
   - Workspaces must be git repositories

2. **git-safety-check.sh** (this document) - Validates git operations
   - Prevents code commits from wrong context
   - Enforces Fork-First Policy
   - Validates worktree locations

---

# Git Safety Hook

## Purpose

Prevents Claude from running git commands in the wrong repository context, solving the issue where code changes are committed to the workspace repo instead of the actual code repo.

## The Problem This Solves

In the workarea architecture, there are multiple nested git repositories:

```
workspaces/projects/tasks/my-feature/
├── task.json           # Part of workspace git repo
├── TASK_STATUS.md      # Part of workspace git repo
└── sdk-java/           # DIFFERENT git repo (worktree)
    └── src/Main.java
```

**Without the hook:** Claude might edit `sdk-java/src/Main.java` but then run `git commit` from the task root, committing to the workspace repo instead of the code repo.

**With the hook:** The operation is blocked with a clear error message before any damage is done.

## What It Validates

The hook runs before every Bash command containing `git` and validates:

1. **Worktree location enforcement**: Ensures worktrees only exist in task structure
   - ✅ Allowed: Worktrees at `workspaces/<name>/tasks/<task>/<repo>/`
   - ❌ Blocked: Worktrees outside `tasks/` directory
   - ❌ Blocked: Worktrees at wrong depth (e.g., `tasks/<repo>/` instead of `tasks/<task>/<repo>/`)
   - ❌ Blocked: Worktrees outside workarea structure entirely

2. **Smart location check**: Distinguishes between task metadata and code files
   - ✅ Allowed: Committing `task.json` or `TASK_STATUS.md` from task root
   - ✅ Allowed: Any git operations from inside worktree directories (after location check)
   - ❌ Blocked: Adding/committing code files (e.g., `sdk-java/src/Main.java`) from task root
   - ❌ Blocked: Destructive operations in workarea root

3. **Fork-First Policy**: Push operations must target personal forks, not upstream
   - ✅ Allowed: `git push origin feature-branch` (to your fork)
   - ❌ Blocked: Push to temporalio/, anthropic/, openai/, etc.

4. **Destructive operations**: Commands like `git reset --hard` are blocked in workarea root
   - ✅ Allowed: In task worktrees (after location validation)
   - ❌ Blocked: In workarea tooling repo root

5. **Read-only commands**: Always allowed (status, log, diff, remote -v, etc.)

## How It Works

1. **Triggered**: Before any Bash command execution (PreToolUse hook)
2. **Checks**: Analyzes command and current working directory
3. **Blocks**: Returns exit code 2 to prevent dangerous operations
4. **Allows**: Returns exit 0 for safe operations

## Configuration

Configured in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/git-safety-check.sh",
            "statusMessage": "Validating git operation..."
          }
        ]
      }
    ]
  }
}
```

## Example Operations

### Example 1: Allowed - Updating task metadata

```bash
# Claude is at: workspaces/projects/tasks/my-feature/
$ vim TASK_STATUS.md  # Update task status
$ git add TASK_STATUS.md
$ git commit -m "Update task status"

✅ Allowed! Task metadata files can be committed from task root.
```

### Example 2: Blocked - Committing code from wrong directory

```bash
# Claude is at: workspaces/projects/tasks/my-feature/
$ git add sdk-java/src/Main.java
$ git commit -m "Fix bug"

🛑 Git Safety Check: Operation blocked!

You're trying to run a git command from the WORKSPACE repo context:
  Working directory: /workarea/workspaces/projects/tasks/my-feature
  Command: git commit -m "Fix bug"

This will affect the workspace repo (task.json, TASK_STATUS.md), not your code!

✅ Expected: Run git commands from inside the worktree directory
   Example: workspaces/projects/tasks/my-feature/sdk-java/

To fix: Navigate to the specific repository directory first.
```

### Example 3: Push to upstream

```bash
# Claude tries to push to upstream instead of fork
$ git push upstream feature-branch

🛑 Git Safety Check: Push blocked!

You're trying to push to an UPSTREAM repository:
  Remote: upstream
  URL: git@github.com:temporalio/sdk-java.git

According to the Fork-First Policy, you should ONLY push to your personal fork.

✅ Correct: git push origin feature-branch
❌ Blocked: Pushing directly to upstream
```

### Example 4: Destructive operation in workarea root

```bash
# Claude is at: /workarea/
$ git reset --hard

🛑 Git Safety Check: Destructive operation blocked in workarea root!

You're trying to run a DESTRUCTIVE git command in the workarea tooling repo:
  Working directory: /workarea
  Command: git reset --hard

This could destroy the workarea tooling itself!

✅ Expected: Run destructive commands only in task worktrees
```

### Example 5: Worktree in wrong location

```bash
# Claude is working in a worktree outside the task structure
# Working directory: /workarea/workspaces/projects/random-worktree/
$ git commit -m "Fix bug"

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

## Testing the Hook

To test if the hook is working:

1. Navigate to a task root (not inside a worktree):
   ```bash
   cd workspaces/<name>/tasks/<task>/
   pwd  # Should show task root, not inside repo
   ```

2. Try a git commit:
   ```bash
   git commit -m "test"  # Should be blocked
   ```

3. Navigate into the worktree:
   ```bash
   cd <repo-name>/
   git commit -m "test"  # Should be allowed (if there are changes)
   ```

## Debugging

If the hook isn't working as expected:

1. Check if the hook is executable:
   ```bash
   ls -l .claude/hooks/git-safety-check.sh
   # Should show: -rwxr-xr-x
   ```

2. Enable debug mode:
   ```bash
   claude --debug hooks
   ```

3. Test the hook manually:
   ```bash
   echo '{"tool_name":"Bash","tool_input":{"command":"git commit"},"cwd":"'$(pwd)'"}' | \
     .claude/hooks/git-safety-check.sh
   echo "Exit code: $?"
   ```

4. Check settings.json syntax:
   ```bash
   cat .claude/settings.json | jq '.'
   ```

## Maintenance

The hook automatically blocks:
- Worktrees outside the task directory structure
- Git commands from task root directories (except task metadata)
- Pushes to known upstream organizations
- Destructive operations in workarea root

Update the upstream organization regex in the script if you work with other protected repos:

```bash
# Edit this line in git-safety-check.sh:
if echo "$REMOTE_URL" | grep -qE '(temporalio|anthropic|openai|yourorg)/'; then
```

## Architecture Enforcement

The hook enforces the proper directory hierarchy:

```
workspaces/<workspace>/
├── tasks/
│   └── <task>/              ← Task root (workspace repo)
│       ├── task.json        ← Can commit from here
│       ├── TASK_STATUS.md   ← Can commit from here
│       └── <repo>/          ← Worktree (code repo) - ONLY valid location
│           └── src/         ← Must navigate here for code commits
└── archived/
```

**Key principle**: Worktrees MUST exist at exactly `tasks/<task>/<repo>/`, nowhere else.

## Related Documentation

- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide.md)
- [Hooks Reference](https://code.claude.com/docs/en/hooks.md)
- [CLAUDE.md](../CLAUDE.md) - Workarea architecture and Git Safety Rules
