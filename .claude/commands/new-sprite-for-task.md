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
- Copies git SSH key to enable repository access
- Sets up .bashrc for proper interactive shell behavior
- Clones the workarea and workspace repositories
- Resumes the specified task

## Instructions

When this command is invoked:

### 1. Find the task (REQUIRED - do this FIRST)

**CRITICAL:** Do NOT proceed until you have found the correct task.

Run this search command FIRST to locate the task:
```bash
cd /Users/maxim/workarea && ./bin/find-task.sh "<task-pattern>"
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

### 6. Copy SSH key to sprite

**IMPORTANT:** Sprite runs as user `sprite` with home directory `/home/sprite`, NOT `/root`.

Create .ssh directory and copy keys:
```bash
sprite exec -s "<sprite-name>" mkdir -p /home/sprite/.ssh
sprite exec -s "<sprite-name>" -file ~/.ssh/id_ed25519:/home/sprite/.ssh/id_ed25519 chmod 600 /home/sprite/.ssh/id_ed25519
sprite exec -s "<sprite-name>" -file ~/.ssh/id_ed25519.pub:/home/sprite/.ssh/id_ed25519.pub chmod 644 /home/sprite/.ssh/id_ed25519.pub
```

If id_ed25519 doesn't exist, try id_rsa:
```bash
sprite exec -s "<sprite-name>" -file ~/.ssh/id_rsa:/home/sprite/.ssh/id_rsa chmod 600 /home/sprite/.ssh/id_rsa
sprite exec -s "<sprite-name>" -file ~/.ssh/id_rsa.pub:/home/sprite/.ssh/id_rsa.pub chmod 644 /home/sprite/.ssh/id_rsa.pub
```

Configure SSH to not check host keys for github.com:
```bash
sprite exec -s "<sprite-name>" bash -c 'echo -e "Host github.com\n\tStrictHostKeyChecking no\n\tUserKnownHostsFile=/dev/null" > /home/sprite/.ssh/config && chmod 600 /home/sprite/.ssh/config'
```

### 7. Update .bashrc

Prepend the interactive shell check to .bashrc:
```bash
sprite exec -s "<sprite-name>" bash -c 'cat > /tmp/bashrc_prepend << '\''EOF'\''
# If not running interactively, don'\''t do anything
case $- in
    *i*) ;;
      *) return;;
esac

EOF
cat /home/sprite/.bashrc >> /tmp/bashrc_prepend 2>/dev/null || true
mv /tmp/bashrc_prepend /home/sprite/.bashrc'
```

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

[Runs ./bin/find-task.sh "airflow"]

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

Setting up SSH keys...
[Copies SSH keys to /home/sprite/.ssh/]
✓ SSH keys configured

Configuring .bashrc...
✓ .bashrc updated

Cloning workarea repository...
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

### SSH Key Not Found
```
Claude: Warning: Could not find SSH key at ~/.ssh/id_ed25519 or ~/.ssh/id_rsa

You'll need to manually copy your SSH key to the sprite:
  sprite exec -s <sprite-name> -file /path/to/key:/home/sprite/.ssh/id_ed25519 chmod 600 /home/sprite/.ssh/id_ed25519
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

### SSH Key Types
- Prefers ed25519 keys over RSA
- Checks for both types if first isn't found
- Sets proper permissions (600 for private, 644 for public)

### Requirements
- `sprite` CLI must be installed and authenticated (`sprite login`)
- SSH key must exist locally
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
