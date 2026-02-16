# new-container-for-task

Create a local Linux container (via `apple/container`) and set it up for a specific task.

## Usage

```
/new-container-for-task <task-name-or-pattern>
/new-container-for-task <PR-URL-or-description>
```

## Examples

```
# Resume an existing task in a new container
/new-container-for-task airflow        # Creates container for "temporal-airflow" task
/new-container-for-task PR-2751        # Creates container for task by PR number
/new-container-for-task async          # Creates container for "async-await" task

# Create a new task in a new container
/new-container-for-task https://github.com/org/repo/pull/456   # Creates new task from PR
/new-container-for-task "Implement caching layer"               # Creates new task from description
```

## Purpose

This command creates a fully-configured local Linux container for working on a task:
- Creates a lightweight container using the `sandbox:latest` image
- SSH agent forwarding for GitHub auth (no manual `gh auth login`)
- Clones only the task's repositories (not the whole workarea)
- Checks out the correct branch
- Mounts task directory from host to `/home/dev/task/` (live, bidirectional)
- Faster and simpler than cloud-based alternatives

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

**If exactly one match -> EXISTING TASK MODE:**
- Extract the workspace name and task name
- Set mode = `existing`
- Read `task.json` from the task path to get repository info
- Proceed to step 2

**If multiple matches found:**
- Show all matches with their workspace
- Ask user which one they want
- Set mode = `existing`
- Read `task.json` from the selected task
- Proceed to step 2

**If no matches found -> check if input looks like a PR URL or description:**

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
- **Create the task on the host** using the existing `/new-task` workflow (run `setup-task-workspace.sh` locally)
- After the task is created on the host, read the generated `task.json` for repository info
- Proceed to step 2

If the input does NOT look like a PR URL or description (seems like it was meant to match a task):
- Show available tasks across all workspaces
- Ask user to clarify which task they meant

### 2. Read task.json

Read the task.json file from the task directory to extract repository configuration:

```bash
cat "$WORKAREA_ROOT/workspaces/<workspace>/tasks/<task-name>/task.json"
```

For each repository entry, extract:
- `name` - repo directory name
- `upstream_url` - upstream git URL
- `fork_url` - fork git URL (may be null for user-owned repos)
- `branch` - branch to check out
- `fork_owner` - fork owner username
- `owner_repo` - whether this is a user-owned repo

### 3. Confirm with user

Show what will be created:
```
Container setup:
  Name: <task-name>
  Mode: existing (resume) / new (create)
  Task: <task-name>
  Workspace: <workspace>
  Repositories:
    - <repo-name> (branch: <branch>)
      Clone from: <fork_url or upstream_url>

Shall I proceed? [Y/n]
```

### 4. Ensure sandbox image exists

Check if the sandbox image is available:
```bash
container image list 2>/dev/null | grep -q sandbox
```

If the image is not found, prompt the user:
```
The sandbox:latest image is not found. Would you like me to build it?
This will run: ./bin/build-sandbox-image.sh
```

If the user agrees, build it:
```bash
"$WORKAREA_ROOT/bin/build-sandbox-image.sh"
```

If the build fails, stop and show the error.

### 5. Create the container

Generate a sanitized container name (lowercase, alphanumeric and dashes only, max 30 chars).

The task directory path on the host is: `$WORKAREA_ROOT/workspaces/<workspace>/tasks/<task-name>`

Mount the host task directory to `/home/dev/task/` inside the container:
```bash
container run -d --name "<task-name>" --ssh --cpus 4 --memory 4G \
  -v <host-task-path>:/home/dev/task \
  sandbox:latest sleep infinity
```

If the name is already taken, inform the user and suggest alternatives:
- Append a number: `<task-name>-2`
- Or ask the user to remove the existing container: `container rm <task-name>`

### 6. Clone task repos inside the container

For each repository in task.json:

**Determine clone URL:**
- If `fork_url` is set (and not null): clone from fork_url
- Otherwise: clone from upstream_url

**Clone the repo:**
```bash
container exec <task-name> bash -c 'git clone <clone-url> /home/dev/<repo-name>'
```

**If cloning from a fork, add upstream remote:**
```bash
container exec <task-name> bash -c 'cd /home/dev/<repo-name> && git remote add upstream <upstream_url> && git remote set-url --push upstream DISABLE'
```

**Checkout the correct branch:**
```bash
container exec <task-name> bash -c 'cd /home/dev/<repo-name> && git checkout <branch> 2>/dev/null || git checkout -b <branch> origin/<branch>'
```

**Fetch upstream if fork:**
```bash
container exec <task-name> bash -c 'cd /home/dev/<repo-name> && git fetch upstream'
```

### 7. Confirm completion

After all repos are cloned and branches checked out:

```
Container ready!

Name: <task-name>
Task: <task-name>
Workspace: <workspace>
Repositories:
  - <repo-name> (branch: <branch>) -> /home/dev/<repo-name>
Task metadata: /home/dev/task/ (mounted from host — edits sync live)

To connect:
  container exec -it <task-name> bash

To stop/start:
  container stop <task-name>
  container start <task-name>

To remove:
  container rm <task-name>
```

## Error Handling

### Image Not Found
```
The sandbox:latest image is not found.
Run: ./bin/build-sandbox-image.sh
Or: container build -t sandbox:latest containers/sandbox/
```

### Container Name Conflict
```
A container named "<task-name>" already exists.

Options:
  1. Remove it: container rm <task-name>
  2. Use a different name: <task-name>-2
  3. Connect to existing: container exec -it <task-name> bash
```

### Clone Failed
```
Failed to clone <repo-name>.

Possible causes:
  - SSH agent not forwarding: check that SSH_AUTH_SOCK is set on host
  - Repository not accessible: verify URL and permissions
  - Network issue: check connectivity

Debug:
  container exec <task-name> bash -c 'ssh -T git@github.com 2>&1'
```

### Branch Not Found
```
Branch "<branch>" not found in <repo-name>.

Creating branch from default branch instead.
You may need to set up the branch manually:
  container exec -it <task-name> bash
  cd /home/dev/<repo-name>
  git checkout -b <branch>
```

### Task Not Found (and input doesn't look like a PR URL or description)
```
No tasks found matching "<pattern>".

Available tasks across all workspaces:
  projects:
    - temporal-airflow
    - kotlin-sdk
  issues:
    - async-await

Use: /new-container-for-task <task-name-or-pattern>
Or create a new task: /new-container-for-task <PR-URL-or-description>
```

## Key Differences from Sprite Workflow

1. **No manual GitHub auth**: SSH agent forwarding handles authentication automatically via `--ssh` flag
2. **No workarea/workspace clone**: Container gets only the task's repos, not the whole infrastructure
3. **Local execution**: Runs on your Mac via `apple/container`, no cloud service needed
4. **Simpler structure**: Container has `/home/dev/<repo>` only, no nested workarea paths
5. **Faster setup**: 7 steps instead of 11 — no shell config, no gh auth, no workarea cloning

## Container Environment

- **Base**: Debian Bookworm
- **User**: `dev` (uid 1000, sudo access)
- **Home**: `/home/dev`
- **Shell**: bash (vi mode, persistent history - baked into image)
- **Tools**: git, gh, node 22, claude-code, jq, curl
- **SSH**: Agent forwarded from host via `--ssh`
- **GitHub**: SSH host key pre-installed in image

## Container Naming

- Names are sanitized: lowercase, alphanumeric and dashes only
- Maximum 30 characters
- Use task name directly

## Lifecycle Management

```bash
# List running containers
container list

# Stop a container (preserves state)
container stop <task-name>

# Start a stopped container
container start <task-name>

# Remove a container (destroys state)
container rm <task-name>

# Connect to a running container
container exec -it <task-name> bash
```

## Notes

### Requirements
- `container` CLI must be installed (`apple/container` - macOS only)
- `sandbox:latest` image must be built (use `bin/build-sandbox-image.sh`)
- SSH agent running on host with GitHub key loaded (`ssh-add -l` to verify)

### Task metadata
- `task.json`, `TASK_STATUS.md`, and `CLAUDE.md` are volume-mounted from the host at `/home/dev/task/`
- Edits inside the container appear on the host instantly (and vice versa)
- Commit and push task metadata changes from the host (the workspace git repo)
