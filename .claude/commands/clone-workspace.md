# clone-workspace

Clone an existing workspace repository into the workspaces directory.

## Usage

```
/clone-workspace <repo-url-or-name> [workspace-name]
```

## Examples

```
# Clone by full URL
/clone-workspace https://github.com/user/workspace-issues

# Clone by repo name (uses gh CLI to resolve)
/clone-workspace workspace-issues

# Clone with custom local name
/clone-workspace workspace-issues my-issues

# Clone and restore all tasks
/clone-workspace --restore workspace-issues
```

## Purpose

This command enables the workspace sharing workflow:
1. Create a workspace locally with `/new-workspace`
2. Push it to GitHub as a separate repo
3. On another machine, use `/clone-workspace` to bring it in
4. Tasks are restored with `/resume-task` as needed

**Use Case:** Set up a workspace from a remote repository (new machine, shared workspace, etc.)

## Instructions

When this command is invoked:

### 0. Find workarea root (REQUIRED)

**CRITICAL:** Find the WORKAREA ROOT dynamically - do NOT hardcode paths.

First, find the workarea root (look for the directory containing `bin/clone-workspace.sh`):
```bash
WORKAREA_ROOT="$(d="$PWD"; while [ "$d" != "/" ]; do [ -f "$d/bin/clone-workspace.sh" ] && echo "$d" && break; d="$(dirname "$d")"; done)"
```

### 1. Parse the input

Determine if the input is:
- A full Git URL (https:// or git@)
- A repository name (will resolve via `gh` CLI)
- A shorthand name (tries with and without `workspace-` prefix)

### 2. Execute the clone script

Run `"$WORKAREA_ROOT/bin/clone-workspace.sh"` with the provided arguments.

The script will:
- Resolve the repository URL
- Clone into `workspaces/<name>/`
- Verify the workspace structure
- Create missing directories (tasks/, archived/)
- Ensure bin symlink exists

### 3. Show results

Display:
- Clone status
- Workspace location
- Task count
- List of tasks with descriptions

### 4. Offer next steps

- Navigate to workspace
- List tasks with `/workarea-tasks`
- Restore tasks with `/resume-task`

## Example Interaction

```
User: /clone-workspace workspace-issues

Claude: I'll clone the workspace-issues repository.

[Finds workarea root, runs $WORKAREA_ROOT/bin/clone-workspace.sh workspace-issues]

Resolving repository...
  Repository: https://github.com/user/workspace-issues
  Workspace name: issues
  Target path: /path/to/workarea/workspaces/issues

Cloning workspace repository...
  ✓ Cloned successfully

Verifying workspace structure...
  ✓ bin symlink exists

Workspace cloned successfully!

  Location: /path/to/workarea/workspaces/issues
  Tasks: 2
  Archived: 1

Tasks:
  - async-await: Implement new feature
  - fix-bug: Fix critical bug in auth

Next steps:
  cd workspaces/issues
  /workarea-tasks

Would you like me to restore any tasks? This will set up the git worktrees.
```

## Options

| Option | Description |
|--------|-------------|
| `-r, --restore` | Restore all tasks after cloning (runs resume-task for each) |
| `-h, --help` | Show help message |

## Error Handling

### Workspace already exists

```
Error: Workspace already exists: workspaces/issues

Options:
  1. Remove existing: rm -rf workspaces/issues
  2. Use different name: /clone-workspace workspace-issues other-name
  3. Pull updates: cd workspaces/issues && git pull
```

### Repository not found

```
Error: Failed to clone repository

Check:
  - Repository URL is correct
  - You have access to the repository
  - gh CLI is authenticated (gh auth status)
```

## Related Commands

- `/new-workspace` - Create a new empty workspace
- `/workarea-tasks` - List workspaces or tasks
- `/resume-task` - Restore task worktrees

## Workflow

### Sharing a workspace

**Machine A (create and push):**
```bash
/new-workspace my-project "My project workspace"
cd workspaces/my-project
/new-task https://github.com/org/repo/pull/123
# ... work on tasks ...

# Push workspace to GitHub
git init
git add -A
git commit -m "Initial workspace"
gh repo create workspace-my-project --private --source=. --push
```

**Machine B (clone and use):**
```bash
cd workarea
/clone-workspace workspace-my-project
cd workspaces/my-project
/resume-task my-feature
# ... continue working ...
```

### Syncing workspace changes

```bash
cd workspaces/my-project
git pull                    # Get task config updates
/resume-task updated-task   # Restore any new tasks
```
