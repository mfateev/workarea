# detach-workspace

Safely remove a workspace after ensuring all progress is saved and pushed.

## Usage

```
/detach-workspace [workspace-name]
```

If no workspace name is provided, uses the current workspace.

## Examples

```
# Detach a specific workspace
/detach-workspace issues

# Detach current workspace (must be inside one)
cd workspaces/issues
/detach-workspace

# Force detach without confirmation
/detach-workspace -f issues
```

## Purpose

Cleanly remove a workspace from your local machine while ensuring:
1. All changes are committed
2. All commits are pushed to remote
3. Git worktrees are removed properly
4. Workspace can be restored later with `/clone-workspace`

**Use Case:** Free up disk space or clean up after finishing work, knowing you can restore the workspace anytime.

## Instructions

When this command is invoked:

### 1. Identify workspace

- If workspace name provided, use it
- Otherwise, detect from current directory
- Verify workspace exists

### 2. Execute detach script

Run `./bin/detach-workspace.sh` with the workspace name.

The script performs these checks:

#### Safety Checks
1. **Uncommitted changes** - Fails if any uncommitted changes exist
2. **Unpushed commits** - Fails if commits haven't been pushed to remote
3. **Untracked files** - Warns about files that will be lost

#### Cleanup Steps
1. Find all git worktrees in tasks/
2. Remove worktrees cleanly from main repos
3. Delete workspace directory

### 3. Confirm with user

Unless `--force` is used, ask for confirmation before deletion.

### 4. Provide restoration info

Show how to restore the workspace later with `/clone-workspace`.

## Example Interaction

```
User: /detach-workspace issues

Claude: I'll safely detach the 'issues' workspace.

[Runs ./bin/detach-workspace.sh issues]

========================================
Detaching workspace: issues
========================================

Checking workspace git status...
  ✓ All commits pushed to remote
  ✓ No uncommitted changes

Checking for git worktrees...
  Found worktree: tasks/my-feature/repo
    Removing from repos/repo...
  ✓ Removed 1 worktree(s)

Ready to delete workspace

Workspace: /path/to/workarea/workspaces/issues

Delete this workspace? (y/n) y

========================================
Workspace detached successfully!
========================================

The workspace 'issues' has been removed.

To restore it later:
  /clone-workspace workspace-issues

Remaining workspaces:
  - projects
```

## Error Handling

### Uncommitted changes

```
Error: Uncommitted changes detected!

Changed files:
 M tasks/my-feature/TASK_STATUS.md

Please commit or stash changes first:
  cd workspaces/issues
  git add -A && git commit -m 'Save progress'
  git push
```

### Unpushed commits

```
Error: Unpushed commits detected!

Unpushed commits:
abc1234 Update task status

Please push changes first:
  cd workspaces/issues
  git push
```

### No remote configured

```
Warning: No remote configured
Changes may not be backed up. Continue? (y/n)
```

## Options

| Option | Description |
|--------|-------------|
| `-f, --force` | Skip all confirmation prompts |
| `-h, --help` | Show help message |

## Safety Features

- **Won't delete with uncommitted changes** - Must commit first
- **Won't delete with unpushed commits** - Must push first
- **Warns about untracked files** - Gives chance to save them
- **Warns if no remote** - Data might be lost
- **Removes worktrees cleanly** - Prevents git corruption
- **Requires confirmation** - Unless `--force` is used

## Related Commands

- `/clone-workspace` - Restore a detached workspace
- `/new-workspace` - Create a new workspace
- `/workarea-tasks` - List workspaces

## Workflow

### Typical detach flow

```bash
# 1. Make sure work is saved
cd workspaces/issues
git status                    # Check for changes
git add -A && git commit -m "Save progress"
git push

# 2. Detach the workspace
/detach-workspace issues

# 3. Later, restore if needed
/clone-workspace workspace-issues
```

### Quick cleanup (all in one)

```bash
# Commit, push, and detach
cd workspaces/issues
git add -A && git commit -m "Save progress" && git push
/detach-workspace -f
```

## Notes

- Workspace git repository is preserved on GitHub
- Task configurations (task.json, TASK_STATUS.md) are preserved
- Git worktrees are removed to prevent orphaned references
- Main repos in `repos/` are NOT deleted (shared across workspaces)
- Archived tasks are preserved in the workspace repo
