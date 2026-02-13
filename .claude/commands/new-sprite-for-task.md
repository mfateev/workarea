# new-sprite-for-task

Create a new sprite (sprite.dev) environment and set it up for a specific task.

## Usage

```
/new-sprite-for-task <task-name-or-pattern>
/new-sprite-for-task <PR-URL-or-description>
```

## Examples

```
# Resume an existing task in a new sprite
/new-sprite-for-task airflow        # Creates sprite for "temporal-airflow" task
/new-sprite-for-task PR-2751        # Creates sprite for task by PR number
/new-sprite-for-task async          # Creates sprite for "async-await" task

# Create a new task in a new sprite
/new-sprite-for-task https://github.com/org/repo/pull/456   # Creates new task from PR
/new-sprite-for-task "Implement caching layer"               # Creates new task from description
```

## Purpose

This command creates a fully-configured sprite environment for working on a task:
- Creates a new sprite with a name based on the task
- Authenticates with GitHub via `gh auth login`
- Sets up .bashrc with vi mode and persistent history
- Clones the workarea and workspace repositories
- Resumes the specified task (existing task mode)
- Creates new tasks from PR URLs or descriptions if the task doesn't exist yet (new task mode)

## Instructions

When this command is invoked:

### 1. Find the task or enter new-task mode (REQUIRED - do this FIRST)

**CRITICAL:** Find the WORKAREA ROOT dynamically - do NOT hardcode paths.

First, find the workarea root (look for the directory containing `bin/find-task.sh`):
```bash
WORKAREA_ROOT="$(d="$PWD"; while [ "$d" != "/" ]; do [ -f "$d/bin/find-task.sh" ] && echo "$d" && break; d="$(dirname "$d")"; done)"
```

Then run the find-task script:
```bash
"$WORKAREA_ROOT/bin/find-task.sh" "<task-pattern>"
```

**If exactly one match → EXISTING TASK MODE:**
- Extract the workspace name and task name
- Set mode = `existing`
- Proceed to step 2

**If multiple matches found:**
- Show all matches with their workspace
- Ask user which one they want
- Set mode = `existing`
- Proceed to step 2

**If no matches found → check if input looks like a PR URL or description:**

The input is a PR URL or description if:
- It starts with `https://github.com/` and contains `/pull/`
- OR it does NOT match any existing task name pattern (treat as a task description)

If the input looks like a PR URL or description, enter **NEW TASK MODE**:
- Set mode = `new`
- Ask the user which workspace to use (list available workspaces):
  ```bash
  ls -d "$WORKAREA_ROOT"/workspaces/*/
  ```
- Ask the user for a task name:
  - If input is a PR URL: auto-suggest a name from the PR title (fetch with `gh pr view <url> --json title --jq '.title'`), sanitized to lowercase-alphanumeric-dashes
  - If input is a description: auto-suggest a sanitized version of the description
  - Let the user override the suggestion
- Save the PR URL or description, workspace name, and task name for later steps
- Proceed to step 2

If the input does NOT look like a PR URL or description (seems like it was meant to match a task):
- Show available tasks across all workspaces
- Ask user to clarify which task they meant

### 2. Ensure task is committed and pushed (EXISTING TASK MODE only)

**Skip this step if mode = `new`.** New tasks don't exist locally yet — they'll be created inside the sprite.

**CRITICAL:** The task must exist in the remote repository before it can be resumed in the sprite.

Check if task files need to be committed:
```bash
cd workspaces/<workspace>
git status tasks/<task-name>/
```

If task.json or TASK_STATUS.md are untracked or modified:
```bash
git add tasks/<task-name>/task.json tasks/<task-name>/TASK_STATUS.md
git commit -m "Add <task-name> task"
git push
```

### 3. Get workspace repository URL

**IMPORTANT:** Each workspace is a separate git repository.

```bash
cd workspaces/<workspace>
git remote get-url origin
```

Save this URL - you'll need it to clone the workspace in the sprite.

### 4. Confirm with user

Show what will be created:
- Sprite name: `<task-name>` (sanitized, max 30 chars)
- Mode: `existing` (resume task) or `new` (create task)
- Task: `<task-name>`
- Workspace: `<workspace>`
- Workspace repo: `<workspace-repo-url>`
- (New task mode only) PR URL or description: `<input>`

Ask user to confirm before proceeding.

### 5. Create the sprite

Generate a sanitized sprite name (lowercase, alphanumeric and dashes only):
```bash
sprite create "<sprite-name>" -skip-console
```

### 6. Update .bashrc

Append shell configuration to .bashrc:
```bash
sprite exec -s "<sprite-name>" bash -c 'cat >> /home/sprite/.bashrc << '\''EOF'\''

# Vi keybindings
set -o vi

# Persistent history
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoredups:erasedups
shopt -s histappend
PROMPT_COMMAND="history -a;$PROMPT_COMMAND"
EOF'
```

### 7. Authenticate with GitHub

**IMPORTANT:** This step requires user interaction in the sprite console.

First, append a welcome message to .bashrc that will display when the user enters the console:
```bash
sprite exec -s "<sprite-name>" bash -c 'cat >> /home/sprite/.bashrc << '\''EOF'\''

# Welcome message (remove after first login)
echo ""
echo "================================================"
echo "  GitHub Authentication Required"
echo "================================================"
echo ""
echo "  Run the following command to authenticate:"
echo ""
echo "    gh auth login"
echo ""
echo "  Select: GitHub.com → HTTPS → Login with a web browser"
echo ""
echo "  After authenticating, type 'exit' to continue sprite setup."
echo "================================================"
echo ""
EOF'
```

Then tell the user you are opening a console and open it:
```
I'm opening a console to the sprite for GitHub authentication.
Please run `gh auth login` inside the sprite, then type `exit` when done.
```

```bash
sprite console -s "<sprite-name>"
```

After the user exits the console, ask them to confirm that authentication succeeded before proceeding to the next step.

### 8. Clone workarea repository

Get the workarea repo URL:
```bash
git remote get-url origin  # Run locally in workarea root
```

Clone into the sprite:
```bash
sprite exec -s "<sprite-name>" bash -c 'git clone <workarea-repo-url> /home/sprite/workarea'
```

### 9. Clone workspace repository

**IMPORTANT:** Workspaces are separate git repositories, not part of the main workarea repo.

Clone the workspace into the correct location:
```bash
sprite exec -s "<sprite-name>" bash -c 'git clone <workspace-repo-url> /home/sprite/workarea/workspaces/<workspace>'
```

Checkout the correct branch if not on default:
```bash
sprite exec -s "<sprite-name>" bash -c 'cd /home/sprite/workarea/workspaces/<workspace> && git checkout <branch-name>'
```

### 10. Resume or create the task

#### Existing task mode (mode = `existing`)

Run the resume-task script directly (more reliable than claude -p):
```bash
sprite exec -s "<sprite-name>" bash -c 'cd /home/sprite/workarea/workspaces/<workspace> && ./bin/resume-task.sh <task-name>'
```

If the worktree creation fails due to branch conflict, create it manually:
```bash
sprite exec -s "<sprite-name>" bash -c 'cd /home/sprite/workarea/repos/<repo-name> && git worktree add /home/sprite/workarea/workspaces/<workspace>/tasks/<task-name>/<repo-name> HEAD'
```

#### New task mode (mode = `new`)

Run the setup-task-workspace script to create the task inside the sprite:
```bash
sprite exec -s "<sprite-name>" bash -c 'cd /home/sprite/workarea/workspaces/<workspace> && ./bin/setup-task-workspace.sh <task-name> <pr-url-or-repo-url>'
```

The `setup-task-workspace.sh` script handles:
- Creating the task directory
- Cloning repositories into `repos/`
- Creating worktrees in `tasks/<task-name>/`
- Generating `task.json` with repository configuration
- For PR URLs: fetching PR details via `gh` (which is why step 7 gh auth must happen first)

After the setup script completes, generate a `TASK_STATUS.md` template inside the sprite:
```bash
sprite exec -s "<sprite-name>" bash -c 'cat > /home/sprite/workarea/workspaces/<workspace>/tasks/<task-name>/TASK_STATUS.md << '\''EOF'\''
# Task Status: <task-name>

## Task Overview
- PR: <pr-url-or-description>
- Summary: <brief description>

## Current Status
- Task just created in sprite
- Ready to start work

## Next Steps
- Review the PR / codebase
- Begin implementation
EOF'
```

Then commit and push the new task files to the workspace repo inside the sprite:
```bash
sprite exec -s "<sprite-name>" bash -c 'cd /home/sprite/workarea/workspaces/<workspace> && git add tasks/<task-name>/task.json tasks/<task-name>/TASK_STATUS.md && git commit -m "Add <task-name> task" && git push'
```

### 11. Confirm completion and offer console

After the task is resumed or created, show:
```
Sprite setup complete!

Sprite name: <sprite-name>
Task <resumed|created>: <task-name>
Workspace: <workspace>

To start working:
  sprite console -s <sprite-name>
  cd /home/sprite/workarea/workspaces/<workspace>/tasks/<task-name>
```

Ask if the user wants to open an interactive console:
```bash
sprite console -s "<sprite-name>"
```

## Example Interactions

### Existing Task (Resume)

```
User: /new-sprite-for-task airflow

Claude: Let me find the task matching "airflow"...

[Finds workarea root, runs $WORKAREA_ROOT/bin/find-task.sh "airflow"]

Found task:
  Workspace: projects
  Task: temporal-airflow
  Path: workspaces/projects/tasks/temporal-airflow

Checking if task is committed...
✓ Task files are already committed and pushed

Getting workspace repository URL...
  Workspace repo: git@github.com:user/workspace-projects.git

I'll create a new sprite for this task:
  Sprite name: temporal-airflow
  Task: temporal-airflow
  Workspace: projects
  Workspace repo: git@github.com:user/workspace-projects.git

Shall I proceed? [Y/n]

User: y

Claude: Creating sprite "temporal-airflow"...
[Runs sprite create]
✓ Sprite created

Configuring .bashrc (vi mode, persistent history)...
✓ .bashrc updated

Authenticating with GitHub...
I'm opening a console to the sprite for GitHub authentication.
Please run `gh auth login` inside the sprite, then type `exit` when done.

[Opens sprite console - user runs gh auth login and exits]

Did GitHub authentication succeed? [Y/n]

User: y

Claude: Cloning workarea repository...
[Clones to /home/sprite/workarea]
✓ Workarea cloned

Cloning workspace repository...
[Clones to /home/sprite/workarea/workspaces/projects]
✓ Workspace cloned

Resuming task...
[Runs ./bin/resume-task.sh temporal-airflow]
✓ Repository cloned: repos/airflow
✓ Worktree created: tasks/temporal-airflow/airflow
✓ Branch checked out: main

Sprite setup complete!

Sprite name: temporal-airflow
Task resumed: temporal-airflow
Workspace: projects

To start working:
  sprite console -s temporal-airflow
  cd /home/sprite/workarea/workspaces/projects/tasks/temporal-airflow

Would you like me to open a console to the sprite now? [Y/n]
```

### New Task (Create from PR URL)

```
User: /new-sprite-for-task https://github.com/temporalio/sdk-go/pull/456

Claude: Let me find a task matching that input...

[Finds workarea root, runs $WORKAREA_ROOT/bin/find-task.sh "https://github.com/temporalio/sdk-go/pull/456"]

No existing task found. The input looks like a PR URL — I'll create a new task.

Fetching PR details...
  PR #456: "Add context propagation for workflow signals"
  Repo: temporalio/sdk-go

Which workspace should this task be created in?
  1. projects
  2. issues

User: 1

Claude: Suggested task name: "sdk-go-context-propagation"
Would you like to use this name, or provide a different one?

User: sdk-go-456

Claude: I'll create a new sprite and task:
  Sprite name: sdk-go-456
  Mode: new (create task)
  Task: sdk-go-456
  Workspace: projects
  Workspace repo: git@github.com:user/workspace-projects.git
  PR: https://github.com/temporalio/sdk-go/pull/456

Shall I proceed? [Y/n]

User: y

Claude: Creating sprite "sdk-go-456"...
[Runs sprite create]
✓ Sprite created

Configuring .bashrc (vi mode, persistent history)...
✓ .bashrc updated

Authenticating with GitHub...
I'm opening a console to the sprite for GitHub authentication.
Please run `gh auth login` inside the sprite, then type `exit` when done.

[Opens sprite console - user runs gh auth login and exits]

Did GitHub authentication succeed? [Y/n]

User: y

Claude: Cloning workarea repository...
[Clones to /home/sprite/workarea]
✓ Workarea cloned

Cloning workspace repository...
[Clones to /home/sprite/workarea/workspaces/projects]
✓ Workspace cloned

Creating task...
[Runs ./bin/setup-task-workspace.sh sdk-go-456 https://github.com/temporalio/sdk-go/pull/456]
✓ Repository cloned: repos/sdk-go
✓ Worktree created: tasks/sdk-go-456/sdk-go
✓ task.json generated

Creating TASK_STATUS.md...
✓ TASK_STATUS.md created

Committing task files to workspace repo...
✓ Task committed and pushed

Sprite setup complete!

Sprite name: sdk-go-456
Task created: sdk-go-456
Workspace: projects

To start working:
  sprite console -s sdk-go-456
  cd /home/sprite/workarea/workspaces/projects/tasks/sdk-go-456

Would you like me to open a console to the sprite now? [Y/n]
```

## Error Handling

### GitHub Authentication Failed
```
Claude: It looks like GitHub authentication didn't complete successfully.

Would you like me to open the sprite console again so you can retry `gh auth login`?
  sprite console -s <sprite-name>

Or you can authenticate later:
  sprite console -s <sprite-name>
  gh auth login
```

### Sprite Creation Failed
```
Claude: Error: Failed to create sprite.

Possible causes:
  - Not logged in: Run `sprite login`
  - Sprite name already exists: Choose a different name
  - Network issue: Check connection

Would you like to try with a different name?
```

### Task Not Found (and input doesn't look like a PR URL or description)
```
Claude: No tasks found matching "nonexistent-task".

Available tasks across all workspaces:
  projects:
    - temporal-airflow
    - kotlin-sdk
  issues:
    - async-await

Use: /new-sprite-for-task <task-name-or-pattern>
Or create a new task: /new-sprite-for-task <PR-URL-or-description>
```

### Task Creation Failed (new task mode)
```
Claude: Error: Task creation failed inside the sprite.

Possible causes:
  - Invalid PR URL: Verify the URL is a valid GitHub PR
  - gh auth not working: Re-run gh auth login in sprite console
  - Repository clone failed: Check network connectivity
  - setup-task-workspace.sh error: Check script output above

Would you like me to open a console to the sprite to debug?
  sprite console -s <sprite-name>
```

### Task Not Committed
```
Claude: Task files are not committed to the repository.

Committing and pushing task files...
[git add, commit, push]
✓ Task files pushed

Continuing with sprite setup...
```

### Worktree Branch Conflict
```
Claude: Worktree creation failed (branch already checked out).

Creating worktree with detached HEAD instead...
[git worktree add ... HEAD]
✓ Worktree created
```

## Key Differences from Initial Version

1. **User context**: Sprite runs as `sprite` user, not `root`. All paths use `/home/sprite/` instead of `/root/`.

2. **Workspace repositories**: Each workspace (e.g., `projects`, `issues`) is a separate git repository that must be cloned independently.

3. **Task must be pushed**: Before resuming in sprite, ensure task.json and TASK_STATUS.md are committed and pushed.

4. **Direct script execution**: Use `./bin/resume-task.sh` directly instead of `claude -p` for more reliable execution.

5. **Worktree fallback**: If branch is already checked out, use `HEAD` to create detached worktree.

6. **GitHub auth via `gh auth login`**: Authentication is done interactively in the sprite console, not by copying SSH keys.

## Notes

### Sprite Environment
- User: `sprite` (uid 1001)
- Home: `/home/sprite`
- Shell: bash
- Claude Code is pre-installed

### Sprite Naming
- Names are sanitized: lowercase, alphanumeric and dashes only
- Maximum 30 characters
- Use task name directly (workspace prefix not needed)

### Requirements
- `sprite` CLI must be installed and authenticated (`sprite login`)
- `gh` CLI must be available in the sprite for GitHub authentication
- Internet connection for sprite creation and repo cloning

### Cleanup
To destroy a sprite when done:
```bash
sprite destroy -s <sprite-name>
```

Or list all sprites:
```bash
sprite list
```
