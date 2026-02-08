# resume-task

Restore a task workspace from its saved configuration.

## Usage

```
/resume-task <task-name-or-pattern>
```

## Examples

```
# From anywhere - will search all workspaces
/resume-task airflow        # Finds "temporal-airflow"
/resume-task PR-2751        # Finds task by PR number
/resume-task async          # Finds "async-await"

# From within a workspace - searches that workspace first
cd workspaces/projects
/resume-task airflow        # Finds within current workspace
```

## Purpose

This command restores a complete task workspace by:
- **Searching for tasks** by name or partial match across workspaces
- Reading the `task.json` configuration file
- Cloning required repositories (if not already present)
- Adding fork remotes automatically
- Creating worktrees on the correct branches
- Setting up tracking to your personal forks

**Use Case:** Continue working on a task from a different machine or after cleaning up local repositories.

## Instructions

When this command is invoked:

### 1. Find the task (REQUIRED - do this FIRST)

**CRITICAL:** Do NOT attempt to read task.json or TASK_STATUS.md until you have found the correct task path.

Run the find-task script directly (it auto-detects the workarea root):
```bash
./bin/find-task.sh "<task-pattern>"
```

This will:
- Search all workspaces for tasks matching the pattern
- Return the workspace and task name
- Handle partial matches (e.g., "airflow" matches "temporal-airflow")

**If no matches found:**
- First, pull the workarea repo to sync any tasks created on other machines:
  ```bash
  cd /Users/maxim/workarea && git pull
  ```
- Retry the find-task script after pulling
- If still not found, show available tasks across all workspaces
- Ask user to clarify which task they meant

**If multiple matches found:**
- Show all matches with their workspace
- Ask user which one they want to resume

**If exactly one match:**
- Proceed to step 2 with the found task

### 2. Display task information

Once you have the task path:
- Read and parse `task.json`
- Show task details:
  - Task name
  - Description
  - PR URL (if applicable)
  - Number of repositories
  - Created date
- Show preview of `TASK_STATUS.md` (first 20 lines) to give context

### 3. Execute restoration script

Navigate to the workspace first, then run the script:
```bash
cd <workspace-path> && ./bin/resume-task.sh <exact-task-name>
```

Stream output to user in real-time showing progress for:
- Repository cloning
- Remote addition
- Worktree creation
- Branch checkout

### 4. Verify restoration
- Check that worktrees were created successfully
- Verify branches are checked out correctly
- Test that tracking branches are set up

### 5. Pull latest from origin
- For each repository worktree in the task:
  - Run `git pull` to fetch and merge latest from tracking remote
  - Show pull output (new commits, already up to date, etc.)
- This ensures the workspace has the latest code before working

### 6. Provide next steps
- Navigate to the task directory
- Show current git status
- Remind user to:
  - Read `TASK_STATUS.md` for context
  - Continue working where they left off

## Example Interaction

```
User: /resume-task airflow

Claude: Let me find the task matching "airflow"...

[Runs ./bin/find-task.sh "airflow"]

Found task:
  Workspace: projects
  Task: temporal-airflow
  Path: workspaces/projects/tasks/temporal-airflow

Reading task configuration...

Task Information:
  Name: temporal-airflow
  Description: Temporal Airflow integration
  PR: N/A
  Created: 2026-01-10T14:47:00Z
  Repositories: 1
    - airflow (branch: main, fork: user)

[Runs cd workspaces/projects && ./bin/resume-task.sh temporal-airflow]

✓ Repository exists: repos/airflow
✓ Worktree already exists (updating...)
✓ Pulled latest changes

Pulling latest from origin...
  repo: Already up to date.

Workspace restored successfully!

Next steps:
  1. cd workspaces/projects/tasks/temporal-airflow/airflow
  2. Review task status: cat TASK_STATUS.md
  3. Continue working!

[Changes directory to the task]
```

## Error Handling

### Task Not Found

**FIRST:** Pull the workarea repo in case the task was created on another machine:
```bash
cd /Users/maxim/workarea && git pull
```

Then retry the find-task script. If still not found:
```
User: /resume-task nonexistent-task

Claude: [Runs git pull in workarea]
[Runs ./bin/find-task.sh "nonexistent-task"]

No tasks found matching "nonexistent-task".

Available tasks across all workspaces:

issues:
  - async-await (PR #2751)
  - core-await-timer

projects:
  - temporal-airflow
  - kotlin-sdk-samples

Use: /resume-task <task-name-or-pattern>
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
- ✅ Latest commits pulled from origin
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
/resume-task task-name  # ← This command (auto-pulls latest)
# ... continue working ...
```

### Automation Opportunities
The command could be enhanced to:
- Show diff summary of changes since last work
- Check CI status and show current build state
- Suggest next actions based on TASK_STATUS.md

## Technical Details

### Scripts Used

Scripts auto-detect the workarea root, so call them directly with relative paths.

**1. Task Finder** (run first):
```bash
./bin/find-task.sh "<pattern>"
```
- Searches all workspaces for matching tasks
- Supports partial name matching
- Outputs `MATCH:workspace:task:path` for machine parsing

**2. Task Restorer** (run after finding, from workspace directory):
```bash
cd <workspace-path> && ./bin/resume-task.sh <task-name>
```
- Restores repositories and worktrees
- Must be run from workspace directory

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
