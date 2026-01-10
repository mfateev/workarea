# resume-task

Restore a task workspace from its saved configuration.

**IMPORTANT:** Must be run from within a workspace (`workspaces/<name>/`).

## Usage

```
/resume-task <task-name>
```

## Examples

```
# First, navigate to a workspace
cd workspaces/default

# Then resume a task
/resume-task my-feature
/resume-task feature-authentication
/resume-task fix-pagination
```

## Purpose

This command restores a complete task workspace by:
- Reading the `task.json` configuration file
- Cloning required repositories (if not already present)
- Adding fork remotes automatically
- Creating worktrees on the correct branches
- Setting up tracking to your personal forks

**Use Case:** Continue working on a task from a different machine or after cleaning up local repositories.

## Instructions

When this command is invoked:

### 0. Verify workspace context (REQUIRED)

Check if currently in a workspace (`workspaces/<name>/`).

**If NOT in a workspace:**
- Show available workspaces
- Ask: "Which workspace contains this task?"
- Navigate to selected workspace before proceeding

**If in a workspace:**
- Proceed to step 1

### 1. Validate task exists
   - Check if `tasks/<task-name>/` directory exists
   - Verify `tasks/<task-name>/task.json` is present
   - If not found, list available tasks from `tasks/` directory

2. **Display task information**
   - Read and parse `task.json`
   - Show task details:
     - Task name
     - Description
     - PR URL (if applicable)
     - Number of repositories
     - Created date
   - Show preview of `TASK_STATUS.md` (first 20 lines) to give context

3. **Confirm with user**
   - Ask user to confirm they want to restore this task
   - Show what will be done:
     - Repositories to be cloned
     - Branches to be checked out
     - Fork remotes to be added

4. **Execute restoration script**
   - Run `./bin/resume-task.sh <task-name>`
   - Stream output to user in real-time
   - Show progress for:
     - Repository cloning
     - Remote addition
     - Worktree creation
     - Branch checkout

5. **Verify restoration**
   - Check that worktrees were created successfully
   - Verify branches are checked out correctly
   - Test that tracking branches are set up

6. **Provide next steps**
   - Navigate to the task directory
   - Show current git status
   - Remind user to:
     - Read `TASK_STATUS.md` for context
     - Pull latest changes: `git pull`
     - Continue working where they left off

## Example Interaction

```
User: /resume-task my-feature

Claude: I'll restore the task workspace for "my-feature"

Reading task configuration...

Task Information:
  Name: my-feature
  Description: Implement new feature
  PR: https://github.com/org/repo/pull/123
  Created: 2026-01-06T14:47:00Z
  Repositories: 1
    - repo (branch: my-feature, fork: <username>)

Task Status Preview:
  > # Task Status: Feature PR #123
  >
  > **Last Updated:** 2026-01-06
  > **PR:** https://github.com/org/repo/pull/123
  > **Branch:** `my-feature` (from fork: <username>/fork-repo)
  >
  > ## Current Status
  >
  > ### CI Status
  > ❌ 1 FAILING CHECK:
  > - Unit test with in-memory test service [Edge]
  ...

[Runs ./bin/resume-task.sh my-feature]

✓ Repository cloned: repos/repo
✓ Fork remote added: <username>
✓ Branch fetched: <username>/my-feature
✓ Worktree created: tasks/my-feature/repo

Workspace restored successfully!

Next steps:
  1. Navigate to task: cd tasks/my-feature/repo
  2. Check status: git status
  3. Pull latest changes: git pull
  4. Review task status: cat ../TASK_STATUS.md

[Changes directory to tasks/my-feature/repo]

Current branch: my-feature
Tracking: <username>/my-feature
Status: Ready to work!
```

## Error Handling

### Task Not Found
```
User: /resume-task nonexistent-task

Claude: Task "nonexistent-task" not found.

Available tasks:
  - my-feature (PR #123: Implement new feature)
  - feature-auth (New feature: Implement user authentication)

Use: /resume-task <task-name>
```

### Missing task.json
```
Claude: Error: task.json not found for task "old-task"

The task directory exists but is missing configuration.
This might be an old task created before task.json was implemented.

Options:
  1. Manually inspect: cat tasks/old-task/TASK_STATUS.md
  2. Set up manually: /new-task <description>
  3. Remove old task: rm -rf tasks/old-task
```

### Repository Clone Failure
```
Claude: Warning: Failed to clone repository from upstream.

Attempting to clone from fork instead...
✓ Cloned from fork: <username>/repo

Note: You may need to add the upstream remote manually:
  cd repos/repo
  git remote add upstream https://github.com/org/repo.git
  git fetch upstream
```

## Notes

### Requirements
- **task.json must exist:** This command depends on the task configuration file
- **jq required:** The resume script uses `jq` for JSON parsing
  - If missing: `brew install jq`
- **Internet connection:** Needed to clone repositories and fetch from forks

### What Gets Restored
- ✅ Repository clones (to `repos/`)
- ✅ Fork remotes (e.g., `<username>`)
- ✅ Git worktrees (to `tasks/<name>/`)
- ✅ Branch checkouts
- ✅ Tracking branch setup
- ❌ Uncommitted changes (push before switching machines!)

### Differences from `/new-task`
| Feature | `/new-task` | `/resume-task` |
|---------|-------------|----------------|
| Creates new task | ✅ Yes | ❌ No |
| Reads task.json | ❌ No (creates it) | ✅ Yes |
| Asks for repos | ✅ Yes (interactive) | ❌ No (from config) |
| Clones repos | ✅ Yes | ✅ Yes (if missing) |
| Use case | Start new work | Continue existing work |

### Best Practices
1. **Always read TASK_STATUS.md** after resuming to understand context
2. **Pull before working** to get latest changes from your fork
3. **Push frequently** to keep your fork up to date across machines
4. **Update TASK_STATUS.md** after making progress
5. **Commit documentation** to workarea repo regularly

### Integration with Workflow
This command is part of the cross-machine workflow:

**Machine A (start):**
```bash
/new-task https://github.com/org/repo/pull/123
# ... work ...
git push  # Push to your fork
cd ../.. && git push  # Push task documentation
```

**Machine B (resume):**
```bash
git clone https://github.com/<username>/workarea.git
cd workarea
/resume-task task-name  # ← This command
git pull  # Get latest from your fork
# ... continue working ...
```

### Automation Opportunities
The command could be enhanced to:
- Auto-detect if repositories need updating (git fetch)
- Show diff summary of changes since last work
- Automatically pull latest changes
- Check CI status and show current build state
- Suggest next actions based on TASK_STATUS.md

## Technical Details

### Script Location
Calls: `./bin/resume-task.sh`

### Configuration File Format
Reads: `tasks/<task-name>/task.json`

Example structure:
```json
{
  "task_name": "my-feature",
  "created": "2026-01-06T14:47:00Z",
  "pr_url": "https://github.com/org/repo/pull/123",
  "pr_number": 123,
  "repositories": [
    {
      "name": "repo",
      "upstream_url": "https://github.com/org/repo.git",
      "fork_url": "https://github.com/<username>/fork-repo.git",
      "branch": "my-feature",
      "fork_owner": "<username>",
      "tracking_remote": "<username>",
      "tracking_branch": "my-feature"
    }
  ],
  "description": "Implement new feature"
}
```

### Output Expectations
The command should:
- Be verbose about what it's doing
- Show progress for long operations
- Clearly indicate success/failure
- Provide actionable next steps
- Navigate to the working directory at the end
