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
- Clones the workarea repository
- Resumes the specified task

## Instructions

When this command is invoked:

### 1. Find the task (REQUIRED - do this FIRST)

**CRITICAL:** Do NOT proceed until you have found the correct task.

Run this search command FIRST to locate the task:
```bash
./bin/find-task.sh "<task-pattern>"
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

### 2. Confirm with user

Show what will be created:
- Sprite name: `<workspace>-<task-name>` (sanitized, max 30 chars)
- Task to resume: `<task-name>`
- Workspace: `<workspace>`

Ask user to confirm before proceeding.

### 3. Create the sprite

Generate a sanitized sprite name (lowercase, alphanumeric and dashes only):
```bash
sprite create "<sprite-name>" -skip-console
```

Wait for the sprite to be created. The sprite name should be derived from the task name, e.g., `task-airflow` or `projects-temporal-airflow`.

### 4. Copy SSH key to sprite

Copy the SSH private key and set proper permissions:
```bash
sprite exec -s "<sprite-name>" mkdir -p /root/.ssh
sprite exec -s "<sprite-name>" -file ~/.ssh/id_ed25519:/root/.ssh/id_ed25519 chmod 600 /root/.ssh/id_ed25519
sprite exec -s "<sprite-name>" -file ~/.ssh/id_ed25519.pub:/root/.ssh/id_ed25519.pub chmod 644 /root/.ssh/id_ed25519.pub
```

If id_ed25519 doesn't exist, try id_rsa:
```bash
sprite exec -s "<sprite-name>" -file ~/.ssh/id_rsa:/root/.ssh/id_rsa chmod 600 /root/.ssh/id_rsa
sprite exec -s "<sprite-name>" -file ~/.ssh/id_rsa.pub:/root/.ssh/id_rsa.pub chmod 644 /root/.ssh/id_rsa.pub
```

Configure SSH to not check host keys for github.com:
```bash
sprite exec -s "<sprite-name>" bash -c 'echo -e "Host github.com\n\tStrictHostKeyChecking no\n\tUserKnownHostsFile=/dev/null" > /root/.ssh/config && chmod 600 /root/.ssh/config'
```

### 5. Update .bashrc

Add the interactive shell check to .bashrc:
```bash
sprite exec -s "<sprite-name>" bash -c 'cat > /root/.bashrc << '\''EOF'\''
# If not running interactively, don'\''t do anything
case $- in
    *i*) ;;
      *) return;;
esac
EOF'
```

### 6. Clone workarea repository

Clone the workarea repo and navigate to the workspace:
```bash
sprite exec -s "<sprite-name>" bash -c 'cd /root && git clone git@github.com:YOUR_USERNAME/workarea.git'
```

**Note:** You need to know the user's workarea repository URL. Check the current repo's remote:
```bash
git remote get-url origin
```

Use this URL for cloning.

### 7. Resume the task using claude -p

Run the resume-task command inside the sprite using `claude -p`:
```bash
sprite exec -s "<sprite-name>" bash -c 'cd /root/workarea/workspaces/<workspace> && claude -p "/resume-task <task-name>"'
```

This will:
- Navigate to the correct workspace
- Run Claude Code with the resume-task prompt
- Automatically restore repositories and worktrees

Stream the output to show progress.

### 8. Confirm completion and offer console

After the task is resumed, show:
```
Sprite setup complete!

Sprite name: <sprite-name>
Task resumed: <task-name>
Workspace: <workspace>

To start working:
  sprite console -s <sprite-name>
  cd /root/workarea/workspaces/<workspace>/tasks/<task-name>
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

I'll create a new sprite for this task:
  Sprite name: projects-temporal-airflow
  Task: temporal-airflow
  Workspace: projects

Shall I proceed? [Y/n]

User: y

Claude: Creating sprite "projects-temporal-airflow"...
[Runs sprite create]
✓ Sprite created

Setting up SSH keys...
[Copies SSH keys]
✓ SSH keys configured

Configuring .bashrc...
✓ .bashrc updated

Cloning workarea repository...
[Clones repo]
✓ Repository cloned

Resuming task...
[Runs claude -p "/resume-task temporal-airflow"]
✓ Repository exists: repos/airflow
✓ Worktree created: tasks/temporal-airflow/airflow
✓ Branch checked out: main

Sprite setup complete!

Sprite name: projects-temporal-airflow
Task resumed: temporal-airflow
Workspace: projects

To start working:
  sprite console -s projects-temporal-airflow
  cd /root/workarea/workspaces/projects/tasks/temporal-airflow

Would you like me to open a console to the sprite now? [Y/n]
```

## Error Handling

### SSH Key Not Found
```
Claude: Warning: Could not find SSH key at ~/.ssh/id_ed25519 or ~/.ssh/id_rsa

You'll need to manually copy your SSH key to the sprite:
  sprite exec -s <sprite-name> -file /path/to/your/key:/root/.ssh/id_rsa ...
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

## Notes

### Sprite Naming
- Names are sanitized: lowercase, alphanumeric and dashes only
- Maximum 30 characters
- Format: `<workspace>-<task>` or just `<task>` if too long

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
