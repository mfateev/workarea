# archive-task

Archive a completed task, preserving its configuration and notes.

## Usage

```
/archive-task <task-name-or-pattern>
```

## Examples

```
# Archive by exact name
/archive-task async-await

# Archive by partial match
/archive-task airflow        # Archives "temporal-airflow"

# From within a workspace
cd workspaces/projects
/archive-task kotlin         # Archives "kotlin-sdk-samples"
```

## Purpose

This command archives completed tasks by:
- **Removing git worktrees** from the task folder (saves disk space)
- **Moving the task** to `archived/` directory
- **Updating archived/README.md** with task entry for reference
- **Preserving task.json and TASK_STATUS.md** for future reference

**Use Case:** Clean up completed work while maintaining a record of what was done.

## Instructions

When this command is invoked:

### 1. Find the task (REQUIRED - do this FIRST)

**CRITICAL:** Use find-task.sh to locate the task before attempting any operations.

Run the find-task script directly (it auto-detects the workarea root):
```bash
./bin/find-task.sh "<task-pattern>"
```

**If no matches found:**
- Show available tasks across all workspaces
- Ask user to clarify which task they meant

**If multiple matches found:**
- Show all matches with their workspace
- Ask user which one they want to archive

**If exactly one match:**
- Proceed to step 2 with the found task

### 2. Display task information

Once you have the task path:
- Read and parse `task.json`
- Show task details:
  - Task name
  - Description
  - PR URL (if applicable)
  - Created date
  - Repository worktrees that will be removed
- Show quick summary from `TASK_STATUS.md`

### 3. Confirm with user

**IMPORTANT:** Archiving removes worktrees. Always confirm:

```
This will archive the task "async-await":

  Worktrees to be removed:
    - sdk-java (branch: async-await-pr2751)

  Files to be preserved:
    - task.json
    - TASK_STATUS.md

  Destination: workspaces/issues/archived/async-await

Are you sure you want to archive this task? [y/N]
```

- Default to NO if user doesn't explicitly confirm
- Warn if there are uncommitted changes in worktrees

### 4. Check for uncommitted/unpushed changes

The archive script automatically checks for:
- **Uncommitted changes** - Modified files not yet committed
- **Unpushed commits** - Commits not yet pushed to remote

If issues are found, the script will fail and show instructions.

**If there are uncommitted changes:**
- Show what files have changes
- Ask the user if they want to:
  1. Commit and push changes first
  2. Run with `--force` to archive anyway (changes will be lost!)
  3. Cancel the archive operation

**If there are unpushed commits:**
- Show the commits that haven't been pushed
- Ask the user if they want to:
  1. Push changes first: `git push`
  2. Run with `--force` to archive anyway (commits will remain only in local repos/)
  3. Cancel the archive operation

### 5. Execute archive script

Navigate to the workspace first, then run:

```bash
cd <workspace-path> && ./bin/archive-task.sh <exact-task-name>
```

Stream output to user in real-time showing:
- Worktree removal progress
- Move operation
- README.md update

### 6. Verify archival

- Check that task was moved to archived/
- Verify README.md was updated
- Confirm worktrees were removed from repos

### 7. Provide summary

Show what was done:
- Where the archived task is located
- What files were preserved
- How to restore if needed

## Example Interaction

```
User: /archive-task async-await

Claude: Let me find the task matching "async-await"...

[Runs ./bin/find-task.sh "async-await"]

Found task:
  Workspace: issues
  Task: async-await
  Path: workspaces/issues/tasks/async-await

Reading task configuration...

Task Information:
  Name: async-await
  Description: PR #2751 - Async/Await support
  PR: https://github.com/temporalio/sdk-java/pull/2751
  Created: 2026-01-06T14:47:00Z

Worktrees to be removed:
  - sdk-java (branch: async-await-pr2751)

Checking for uncommitted changes...
  sdk-java: Clean (no uncommitted changes)

This will archive the task and remove worktrees.
Are you sure you want to proceed? [y/N]

User: y

[Runs cd workspaces/issues && ./bin/archive-task.sh async-await]

Step 1: Checking worktrees for uncommitted/unpushed changes...
  ✓ sdk-java: Clean
  All worktrees are clean

Step 2: Removing git worktrees...
  Removing worktree: sdk-java
  ✓ Removed 1 worktree(s)

Step 3: Preparing archive directory...
  Archive directory: workspaces/issues/archived

Step 4: Moving task to archived...
  ✓ Moved to: workspaces/issues/archived/async-await

Step 5: Updating archived/README.md...
  ✓ Added entry to README.md

========================================
Task archived successfully!
========================================

Archived to: workspaces/issues/archived/async-await

Files preserved:
  - task.json (configuration)
  - TASK_STATUS.md (notes)

To restore (if needed):
  mv workspaces/issues/archived/async-await workspaces/issues/tasks/
  /resume-task async-await
```

## Error Handling

### Task Not Found

```
User: /archive-task nonexistent

Claude: [Runs ./bin/find-task.sh "nonexistent"]

No tasks found matching "nonexistent".

Available tasks across all workspaces:

issues:
  - async-await (PR #2751)

projects:
  - temporal-airflow
  - kotlin-sdk-samples

Use: /archive-task <task-name-or-pattern>
```

### Uncommitted Changes

```
Claude: [Runs ./bin/archive-task.sh async-await]

Step 1: Checking worktrees for uncommitted/unpushed changes...
  ⚠ sdk-java: Has uncommitted changes
    M src/main/java/Feature.java
    ?? src/test/java/FeatureTest.java

Error: Cannot archive task with uncommitted or unpushed changes.

The script detected uncommitted changes in sdk-java.

Options:
  1. Commit and push changes first
  2. Discard changes: git checkout . && git clean -fd
  3. Run with --force to archive anyway (changes will be lost!)
  4. Cancel archive

What would you like to do?
```

### Unpushed Commits

```
Claude: [Runs ./bin/archive-task.sh async-await]

Step 1: Checking worktrees for uncommitted/unpushed changes...
  ⚠ sdk-java: Has unpushed commits
    abc1234 Add new feature implementation
    def5678 Fix edge case in handler

Error: Cannot archive task with uncommitted or unpushed changes.

The script detected 2 unpushed commits in sdk-java.

Options:
  1. Push your commits first:
     cd workspaces/issues/tasks/async-await/sdk-java
     git push
  2. Run with --force to archive anyway (commits remain in repos/sdk-java)
  3. Cancel archive

What would you like to do?

User: 1

Claude: Let me push those commits for you...
[Runs git push in the worktree]

Now let me try archiving again...
[Runs $WORKAREA_ROOT/bin/archive-task.sh async-await]

✓ All worktrees are clean
...
```

### Already Archived

```
Claude: Error: Task 'async-await' is already archived.

Location: workspaces/issues/archived/async-await

To restore and work on it again:
  mv workspaces/issues/archived/async-await workspaces/issues/tasks/
  /resume-task async-await
```

## Notes

### What Gets Archived

- ✅ `task.json` - Task configuration (preserved)
- ✅ `TASK_STATUS.md` - Progress notes (preserved)
- ✅ Entry in `archived/README.md` - For reference
- ❌ Git worktrees - Removed to save space
- ❌ Uncommitted changes - Must be committed first (or use `--force`)
- ❌ Unpushed commits - Must be pushed first (or use `--force`, commits stay in repos/)

### The --force Flag

Use `--force` to skip safety checks and archive anyway:

```bash
./bin/archive-task.sh --force <task-name>
```

**Warning:** With `--force`:
- Uncommitted changes will be **lost forever**
- Unpushed commits will remain only in `repos/<name>` (not backed up remotely)

### What Gets Removed

Worktrees are removed from `repos/<name>` but the repository itself remains.
This saves disk space while keeping the shared repository available for other tasks.

### Restoring an Archived Task

If you need to work on an archived task again:

```bash
# Move back to tasks/
mv workspaces/<workspace>/archived/<task> workspaces/<workspace>/tasks/

# Resume the task (recreates worktrees)
/resume-task <task-name>
```

### Best Practices

1. **Commit all changes** before archiving
2. **Push to your fork** to ensure code is backed up
3. **Update TASK_STATUS.md** with final status before archiving
4. **Archive promptly** after PRs are merged to keep workspace clean

### Archived README Format

The `archived/README.md` maintains a table of archived tasks:

```markdown
# Archived Tasks

Completed tasks that have been archived.

| Task | PR | Archived | Description |
|------|----|----|-------------|
| async-await | https://github.com/org/repo/pull/2751 | 2026-01-15 | Async/Await support |
| feature-x | N/A | 2026-01-10 | Implement feature X |
```

## Related Commands

- `/new-task` - Create a new task
- `/resume-task` - Resume/restore a task (including archived ones after moving)
- `/workarea-tasks` - List tasks in current workspace

## Technical Details

### Scripts Used

Scripts auto-detect the workarea root, so call them directly with relative paths.

**Task Finder (run first):**
```bash
./bin/find-task.sh "<pattern>"
```

**Archive Script (run from workspace directory):**
```bash
cd <workspace-path> && ./bin/archive-task.sh <task-name>
```

### Directory Structure

Before archiving:
```
workspaces/<name>/
├── tasks/
│   └── my-task/          # Active task
│       ├── task.json
│       ├── TASK_STATUS.md
│       └── repo/         # Git worktree (removed)
└── archived/
    └── README.md
```

After archiving:
```
workspaces/<name>/
├── tasks/                # Empty or other tasks
└── archived/
    ├── README.md         # Updated with entry
    └── my-task/          # Archived task
        ├── task.json     # Preserved
        └── TASK_STATUS.md # Preserved
```
