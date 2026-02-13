# new-sprite-for-task

Create a new sprite (sprite.dev) environment and set it up for a specific task.

## Usage

```
/new-sprite-for-task <task-name-or-pattern>
```

## Examples

```
/new-sprite-for-task airflow        # Creates sprite for "temporal-airflow" task
/new-sprite-for-task PR-2751        # Creates sprite for task by PR number
/new-sprite-for-task async          # Creates sprite for "async-await" task
```

## Purpose

This command creates a fully-configured sprite environment for working on a task:
- Creates a new sprite with a name based on the task
- Authenticates with GitHub via `gh auth login`
- Sets up .bashrc with vi mode and persistent history
- Clones the workarea and workspace repositories
- Resumes the specified task

## Instructions

When this command is invoked:

### 1. Find the task (REQUIRED - do this FIRST)

**CRITICAL:** Do NOT proceed until you have found the correct task.

**CRITICAL:** Find the WORKAREA ROOT dynamically - do NOT hardcode paths.

First, find the workarea root (look for the directory containing `bin/find-task.sh`):
```bash
WORKAREA_ROOT="$(d="$PWD"; while [ "$d" != "/" ]; do [ -f "$d/bin/find-task.sh" ] && echo "$d" && break; d="$(dirname "$d")"; done)"
```

Then run the find-task script:
```bash
"$WORKAREA_ROOT/bin/find-task.sh" "<task-pattern>"
```

**If no matches found:**
- Show available tasks across all workspaces
- Ask user to clarify which task they meant

**If multiple matches found:**
- Show all matches with their workspace
- Ask user which one they want

**If exactly one match:**
- Extract the workspace name and task name
- Proceed to step 2

### 2. Ensure task is committed and pushed

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
- Task to resume: `<task-name>`
- Workspace: `<workspace>`
- Workspace repo: `<workspace-repo-url>`

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

### 10. Resume the task

Run the resume-task script directly (more reliable than claude -p):
```bash
sprite exec -s "<sprite-name>" bash -c 'cd /home/sprite/workarea/workspaces/<workspace> && ./bin/resume-task.sh <task-name>'
```

If the worktree creation fails due to branch conflict, create it manually:
```bash
sprite exec -s "<sprite-name>" bash -c 'cd /home/sprite/workarea/repos/<repo-name> && git worktree add /home/sprite/workarea/workspaces/<workspace>/tasks/<task-name>/<repo-name> HEAD'
```

### 11. Confirm completion and offer console

After the task is resumed, show:
```
Sprite setup complete!

Sprite name: <sprite-name>
Task resumed: <task-name>
Workspace: <workspace>

To start working:
  sprite console -s <sprite-name>
  cd /home/sprite/workarea/workspaces/<workspace>/tasks/<task-name>
```

Ask if the user wants to open an interactive console:
```bash
sprite console -s "<sprite-name>"
```

## Example Interaction

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

### Task Not Found
```
Claude: No tasks found matching "nonexistent-task".

Available tasks across all workspaces:
  projects:
    - temporal-airflow
    - kotlin-sdk
  issues:
    - async-await

Use: /new-sprite-for-task <task-name-or-pattern>
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
