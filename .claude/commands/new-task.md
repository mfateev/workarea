# new-task

Set up a new task workspace with git worktrees for multiple repositories.

**IMPORTANT:** Must be run from within a workspace (`workspaces/<name>/`).

## Usage

```
/new-task <task description or PR URL>
```

## Examples

```
# First, navigate to a workspace
cd workspaces/personal

# New feature tasks
/new-task Implement user authentication with JWT tokens
/new-task Fix pagination bug in admin dashboard
/new-task Add dark mode support to frontend

# Working on an existing PR (just pass the URL)
/new-task https://github.com/org/repo/pull/123
```

## Instructions

When this command is invoked:

### 0. Find workarea root and verify workspace context (REQUIRED)

**CRITICAL:** Find the WORKAREA ROOT dynamically - do NOT hardcode paths.

First, find the workarea root (look for the directory containing `bin/setup-task-workspace.sh`):
```bash
WORKAREA_ROOT="$(d="$PWD"; while [ "$d" != "/" ]; do [ -f "$d/bin/setup-task-workspace.sh" ] && echo "$d" && break; d="$(dirname "$d")"; done)"
```

Check if currently in a workspace (`workspaces/<name>/`).

**If NOT in a workspace:**
- Show available workspaces
- Ask: "Which workspace should this task be created in?"
- Options: [list workspaces] + "Create new workspace"
- Navigate to selected workspace before proceeding
- Run `/new-workspace` if user wants to create one first

**If in a workspace:**
- Proceed to step 1

### 1. Detect input type
   - Check if the input is a GitHub PR URL (matches `https://github.com/.*/pull/[0-9]+`)
   - If PR URL: Skip to step 3 (PR mode)
   - If task description: Continue to step 2 (New task mode)

### New Task Mode (for task descriptions)

2. **Parse the task description** provided by the user
   - Extract a clean task name (lowercase, dash-separated)
   - Example: "Implement user authentication" → "implement-user-authentication"

3. **Determine required repositories**
   - Ask the user which repositories are needed for this task
   - Provide suggestions based on common patterns:
     - Frontend changes → frontend repo
     - Backend changes → backend repo
     - Full-stack → both repos
     - Infrastructure → infra/devops repos
   - Present as a multiple-choice question with common repo URLs
   - Allow user to provide custom URLs

4. **Validate repository URLs**
   - Ensure URLs are valid git repository URLs
   - Support both HTTPS and SSH formats

5. **Execute setup script**
   - Run `"$WORKAREA_ROOT/bin/setup-task-workspace.sh"` with:
     - Task name (sanitized)
     - List of repository URLs
   - Show the script output to the user

### PR Mode (for PR URLs)

3. **Fetch PR information**
   - Use `gh pr view` to get PR details
   - Extract: PR title, branch name, and whether it's from a fork
   - Generate task name from PR title (sanitized)

4. **Execute setup script with PR URL**
   - Run `"$WORKAREA_ROOT/bin/setup-task-workspace.sh"` with:
     - Task name (from PR title)
     - PR URL (script handles branch detection automatically)
   - Show the script output to the user
   - **Note**: The script automatically:
     - Detects the PR branch
     - Handles fork remotes if needed
     - Checks out the correct branch

### Common Steps (both modes)

5. **Verify task.json was created**
   - The setup script automatically generates `task.json` with:
     - Repository URLs (upstream and fork)
     - Branch names
     - Remote tracking information
   - This file enables task restoration on any machine
   - File is automatically tracked in git

6. **Create task status document**
   - Create `TASK_STATUS.md` in the task directory
   - Include: task overview, PR/issue links, current status, CI status, next steps
   - See CLAUDE.md section 4 for full template

7. **Confirm setup**
   - Show that `task.json` was created
   - List the created worktrees
   - Show the task directory path
   - Provide next steps (cd into directory)

8. **Navigate to task workspace**
   - Change working directory to the new task folder
   - Ready to start working

## Example Interactions

### Example 1: New Task (Task Description)

```
User: /new-task Add real-time notifications
Claude: I'll set up a new task workspace for "Add real-time notifications"

Task name: add-real-time-notifications

Which repositories do you need for this task?

[Multiple choice question with options like:
- Frontend repository
- Backend repository
- Both frontend and backend
- Custom URLs]

User: Both frontend and backend

Claude: [Runs script and shows output]
✓ Task workspace created at: tasks/add-real-time-notifications/
✓ Worktrees ready:
  - tasks/add-real-time-notifications/frontend
  - tasks/add-real-time-notifications/backend

Creating task status document...
✓ Created: tasks/add-real-time-notifications/TASK_STATUS.md

You can now start working:
  cd tasks/add-real-time-notifications
```

### Example 2: Existing PR (PR URL)

```
User: /new-task https://github.com/org/repo/pull/123

Claude: I'll fetch information about PR #123 from org/repo...

[Fetches PR details]

PR Title: Add new feature
Task name: add-new-feature
Branch: feature-branch (from fork: <username>)

Setting up workspace...

[Runs script with PR URL - automatic branch detection]

✓ Repository cloned: repos/repo
✓ Fork remote added: <username>
✓ Branch fetched: <username>/feature-branch
✓ Worktree created: tasks/add-new-feature/repo

Creating task status document...
✓ Created: tasks/add-new-feature/TASK_STATUS.md
  - Includes PR details, CI status, and investigation plan

Workspace ready at: tasks/add-new-feature/repo

You can now start working:
  cd tasks/add-new-feature/repo
```

## Notes

### PR URL Support
- **Requires `gh` CLI**: PR URL parsing requires the GitHub CLI to be installed
- **Automatic Branch Detection**: Script handles fork branches automatically
- **Fork Remote Management**: Adds fork remotes as needed (e.g., `<username>` remote)
- **Task Naming**: Uses PR title to generate task name (sanitized)

### Repository Discovery
- Check if `repos/` already has cloned repositories to suggest them
- For new tasks, ask user which repositories are needed
- Support both HTTPS and SSH git URLs

### Task Status Documents
- **Always create** `TASK_STATUS.md` in the task directory
- For PR tasks: Include PR details, CI status, failing tests, investigation plan
- For new tasks: Include task overview, goals, and progress tracking
- Ensures continuity across Claude sessions

### Error Handling
- Sanitize task names to be filesystem-safe
- Handle missing script gracefully
- Show meaningful error messages for git/network issues
- Verify script exists before running
