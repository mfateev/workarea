# Claude Code - Task Workspace Management

## Session Startup Behavior

**IMPORTANT:** At the start of every session in this directory, immediately display the workspace status from the SessionStart hook output. Show it verbatim before responding to anything else.

---

## Hook Protection

**CRITICAL:** Hooks in `.claude/hooks/` provide essential safety checks. They must NEVER be disabled, renamed, or bypassed.

**Prohibited Actions:**
- ❌ **NEVER** disable hooks by renaming them (e.g., `.sh.disabled`)
- ❌ **NEVER** move hooks out of `.claude/hooks/`
- ❌ **NEVER** use `dangerouslyDisableSandbox` to bypass hooks
- ❌ **NEVER** modify hook permissions to prevent execution
- ❌ **NEVER** delete hooks

**If a hook blocks an operation:**
1. Understand WHY the hook is blocking it
2. **ASK THE USER** what to do - don't make assumptions or try workarounds
3. If the user confirms the operation is safe, fix the hook to allow the legitimate use case
4. If the hook has a bug, fix the hook itself - don't disable it

**When uncertain about any operation, ASK THE USER first.** Never disable safety mechanisms to proceed when you're not sure what to do.

Hooks exist to prevent destructive operations and maintain repository integrity. Bypassing them can lead to data loss, repository corruption, or violating the workarea architecture.

---

## Git Safety Rules

**CRITICAL:** Before running any destructive git command, ALWAYS verify you are in the correct repository.

### Dangerous Commands (Require Verification)

These commands can cause data loss or repository corruption if run in the wrong location:

- `git reset --hard` - Discards all local changes
- `git checkout <branch>` - Can overwrite working directory
- `git clean -fd` - Deletes untracked files permanently
- `git merge` / `git rebase` - Can alter history
- `git push --force` - Can overwrite remote history
- `git remote add/remove` - Alters repository configuration

### Required Safety Checks

**Before running any dangerous command, ALWAYS:**

1. **Verify the repository identity:**
   ```bash
   git remote -v
   ```
   Confirm the remote URL matches the expected repository.

2. **Check current location:**
   ```bash
   pwd
   ```
   Ensure you're in the correct directory (task worktree, not workarea root).

3. **Review current state:**
   ```bash
   git status
   ```
   Understand what will be affected.

### Protected Locations

**NEVER run destructive git commands in these locations:**

- `/Users/maxim/workarea` (workarea root) - This is a management repo, not a code repo
- `repos/` directory directly - Use worktrees in tasks instead

**ALWAYS work in:**
- `workspaces/<name>/tasks/<task>/<repo>/` - Task-specific worktrees

### Repos Directory Protection (Enforced by Hook)

The `repos/` directory contains shared git clones that should stay on the main branch. **ALL branch manipulation is blocked** in `repos/` and must happen in task worktrees instead.

**Blocked operations in repos/:**
- `git checkout -b` / `git switch -c` - Creating branches
- `git checkout <branch>` - Switching branches (except `main`/`master`)
- `git branch -d/-D` - Deleting branches
- `git branch -m/-M` - Renaming branches
- `git merge` - Merging branches
- `git rebase` - Rebasing
- `git commit` - Making commits
- `git reset` - Resetting (except `git reset --hard origin/main`)

**Allowed operations in repos/:**
- `git fetch` - Fetching updates from remotes
- `git checkout main` - Switching to main branch
- `git reset --hard origin/main` - Syncing with remote main
- `git status`, `git log`, `git diff` - Read-only operations
- `git worktree add` - Creating worktrees for tasks
- `git remote -v` - Viewing remotes

**Why this matters:**
- `repos/` is shared across all workspaces and tasks
- Branch changes in `repos/` can break existing worktrees
- All development work should be isolated in task worktrees

### Example Safe Workflow

```bash
# WRONG: Running git commands at workarea root
cd /Users/maxim/workarea
git checkout some-branch  # DANGEROUS - wrong repo!

# RIGHT: Navigate to specific task worktree first
cd /Users/maxim/workarea/workspaces/mywork/tasks/feature/sdk-java
git remote -v             # Verify: should show sdk-java remotes
git checkout feature-branch  # Safe: correct repo
```

---

## Fork-First Policy (CRITICAL)

**MANDATORY:** NEVER work directly from upstream repositories. ALWAYS create and use personal forks.

### Requirements

**When creating tasks (`/new-task`):**
1. **Check if a fork exists** on GitHub before setting up the repository
2. **If no fork exists:** Immediately create one using `gh repo fork <org>/<repo>`
3. **Configure task.json** with fork_url and fork_owner
4. **Clone from fork first**, then add upstream as a remote

**When resuming tasks (`/resume-task`):**
1. **Check task.json** for fork_url and fork_owner
2. **Check if repository is user-owned:** Look for `"owner_repo": true` in repository config
3. **If fork is missing (fork_url is null) AND not user-owned:**
   - STOP and create a fork: `gh repo fork <upstream-url>`
   - Update task.json with fork information
   - Clone from fork, not upstream
4. **If user-owned repository:** Proceed with restoration (fork-first policy does not apply)
5. **Never proceed** with restoration if no fork is configured (unless user-owned)

### Why This Matters

- **Security:** Prevents accidental pushes to upstream repositories
- **Safety:** You can't accidentally overwrite upstream branches
- **Best Practice:** Standard open-source contribution workflow
- **Isolation:** Your work stays in your namespace until ready to merge

### Fork Creation Workflow

```bash
# 1. Create fork on GitHub
gh repo fork <org>/<repo> --clone=false

# 2. Get fork URL
FORK_URL="https://github.com/<username>/<repo>.git"

# 3. Clone from fork (not upstream)
git clone $FORK_URL repos/<repo>

# 4. Add upstream as remote
cd repos/<repo>
git remote add upstream https://github.com/<org>/<repo>.git
git fetch upstream
```

### Enforcement Rules

**Claude Code MUST:**
- ❌ **NEVER** clone directly from upstream (unless exception applies)
- ❌ **NEVER** set `fork_url: null` in task.json (unless exception applies)
- ❌ **NEVER** proceed with task restoration without a fork (unless exception applies)
- ✅ **ALWAYS** create forks before any work begins (unless exception applies)
- ✅ **ALWAYS** push to fork remotes, never to origin/upstream (unless exception applies)
- ✅ **ALWAYS** update task.json with fork information

**Exceptions (Fork-First Policy Does Not Apply):**

1. **User-Owned Repositories:** Repositories under the user's own GitHub account where they have direct write access
   - Mark in task.json with: `"owner_repo": true` and `"notes": "This is a user-owned repository. Fork-first policy does not apply."`
   - Example: `https://github.com/mfateev/codex-temporal-go` (user's own project)

2. **Internal/Private Repositories:** Private repositories where the user has write access
   - Must be explicitly confirmed by the user before skipping fork creation

**Identifying User-Owned Repos:**
- Check if `owner_repo: true` is set in task.json repository configuration
- Look for notes indicating "user-owned" or "fork-first policy does not apply"
- When in doubt, ask the user if the repository is their own

---

## Testing Requirements

**CRITICAL:** Never push code or create PRs without running tests first.

### Required Before Pushing

1. **Run the full test suite** for the project before pushing any changes
2. **Do not skip tests** - Tests that require external services (databases, servers, etc.) must be run with those services
3. **Verify all tests pass** - Do not push if any tests fail
4. **Run relevant tests** for changes made - at minimum the tests related to modified code

### No Skipping Tests

**Tests that require services must be run with those services:**
- If tests need a Temporal server, start the Temporal server and run tests
- If tests need a database, start the database and run tests
- Never mark tests as "skipped because service unavailable" as passing

### Example Workflow

```bash
# WRONG: Push without testing or skipping E2E tests
git add . && git commit -m "Add feature" && git push

# WRONG: Claim tests pass when E2E tests were skipped
docker run --rm airflow-temporal:test  # skips E2E tests - NOT SUFFICIENT

# RIGHT: Start required services and run ALL tests
temporal server start-dev &  # Start Temporal server
docker run --rm --network host -e SKIP_TEMPORAL_E2E=false -e TEMPORAL_ADDRESS=localhost:7233 airflow-temporal:test
# Verify: ALL tests pass (including E2E)
git add . && git commit -m "Add feature" && git push
```

### When Tests Fail

- Fix the failing tests before pushing
- If tests are unrelated to your changes, investigate first
- Never assume test failures are acceptable

---

This document explains the workspace-based workflow for managing multiple git repositories using Claude Code.

## Overview

This repository provides **reusable tooling** for task management across multiple git repositories. User-specific tasks and workspaces are gitignored, making this repository shareable.

```
workarea/
├── bin/                 # Shared utility scripts (tracked)
├── repos/               # Git repository clones (shared, gitignored)
├── .claude/             # Claude skills and configuration (tracked)
├── workspaces/          # Container for user workspaces
│   ├── .gitkeep         # Keeps folder in git
│   └── <name>/          # Individual workspaces (gitignored)
│       ├── bin -> ../../bin  # Symlink to shared scripts
│       ├── tasks/            # Active tasks
│       │   └── <task>/       # Task folder
│       │       ├── task.json      # Machine config
│       │       ├── TASK_STATUS.md # Human notes
│       │       └── <repo>/        # Git worktree
│       ├── archived/         # Completed tasks
│       └── README.md         # Workspace description
└── CLAUDE.md            # This documentation (tracked)
```

## Key Concepts

- **Workspaces**: Isolated containers for related tasks (e.g., "personal", "work", "project-x")
- **Shared Repos**: All workspaces share the same `repos/` directory to save disk space
- **Tasks**: Each task has its own folder with git worktrees for each repository
- **Portability**: Task configuration in `task.json` allows restoring workspaces on any machine

## Available Commands

- **`/new-workspace`** - Create a new workspace
  - Creates isolated workspace with tasks/ and archived/ directories
  - Sets up bin symlink for script access
  - **Run this first if you don't have a workspace!**

- **`/list-workarea-tasks`** - List tasks or workspaces
  - At workarea root: Shows available workspaces
  - Inside a workspace: Shows tasks in that workspace
  - **Recommended:** Start sessions with this command

- **`/new-task`** - Create a new task (must be in a workspace)
  - Accepts task descriptions or PR URLs
  - Automatically configures repositories and worktrees
  - Generates task.json and TASK_STATUS.md

- **`/resume-task`** - Restore a task (must be in a workspace)
  - Reads task.json configuration
  - Clones repos and creates worktrees
  - Perfect for continuing work on another machine

## Quick Start

### First Time Setup

```bash
# 1. Clone the workarea repository
git clone https://github.com/user/workarea.git
cd workarea

# 2. Create your first workspace
/new-workspace personal "My personal projects"

# 3. Navigate to your workspace
cd workspaces/personal

# 4. Create your first task
/new-task https://github.com/org/repo/pull/123
# Or: /new-task Implement new feature
```

### Returning User

```bash
cd workarea
/list-workarea-tasks          # Shows available workspaces
cd workspaces/<name>
/list-workarea-tasks          # Shows tasks in this workspace
/resume-task <task>      # Resume a task
```

## Workflow

### 1. Create a Workspace (One-Time)

```bash
/new-workspace <name> [description]
```

Examples:
```bash
/new-workspace personal "Personal open source projects"
/new-workspace work "Work-related tasks and PRs"
/new-workspace temporal "Temporal SDK development"
```

This creates:
```
workspaces/<name>/
├── bin -> ../../bin     # Symlink to shared scripts
├── tasks/               # Your tasks go here
├── archived/            # Completed tasks
└── README.md
```

### 2. Create a Task

Navigate to your workspace first:
```bash
cd workspaces/<name>
```

Then create a task:
```bash
# With PR URL (recommended)
/new-task https://github.com/org/repo/pull/123

# Or with description
/new-task Implement user authentication
```

Claude will:
1. Parse the PR or task description
2. Set up repository worktrees
3. Generate `task.json` configuration
4. Create `TASK_STATUS.md` template
5. Navigate to the task directory

### 3. Work on a Task

```bash
cd workspaces/<workspace>/tasks/<task>/<repo>
# Make changes
git add .
git commit -m "Implement feature"
git push <fork-remote> <branch>
```

### 4. Resume a Task

If worktrees need to be restored (e.g., on a new machine):

```bash
cd workspaces/<workspace>
/resume-task <task-name>
```

### 5. Archive Completed Tasks

When a task is complete:

1. Remove git worktrees from the task folder
2. Move task folder to `archived/`
3. Update `archived/README.md` with task entry
4. Commit and push changes

## Task Files

### `task.json` - Machine Configuration

Automatically generated, contains everything needed to restore the task:

```json
{
  "task_name": "async-await",
  "created": "2026-01-06T14:47:00Z",
  "pr_url": "https://github.com/org/repo/pull/123",
  "pr_number": 123,
  "repositories": [
    {
      "name": "repo-name",
      "upstream_url": "https://github.com/org/repo.git",
      "fork_url": "https://github.com/user/repo.git",
      "branch": "feature-branch",
      "fork_owner": "user",
      "tracking_remote": "user",
      "tracking_branch": "feature-branch"
    }
  ]
}
```

### `TASK_STATUS.md` - Human Context

Manually maintained, tracks progress and context for continuity:

```markdown
# Task Status: [Task Name]

## Task Overview
- PR/Issue links
- Summary of what needs to be done

## Current Status
- Where you are
- What's completed
- What's pending

## CI/Test Status
- Passing/failing checks
- Analysis of failures

## Next Steps
- Actions to take
```

**Always update and commit** `TASK_STATUS.md` after making progress.

## Repository Management

### Shared Repos Directory

All repositories are cloned once to `repos/` at the workarea root:

```bash
repos/
├── sdk-java/     # Shared across all workspaces
├── sdk-go/
└── frontend/
```

### Git Worktrees

Each task gets worktrees (linked working directories):

```bash
workspaces/personal/tasks/my-feature/
├── sdk-java/     # Worktree linked to repos/sdk-java
└── sdk-go/       # Worktree linked to repos/sdk-go
```

Benefits:
- Share git history and objects
- Save disk space
- Independent working states per task

## Fork-Based Workflow (Required)

**CRITICAL:** Always use personal forks when contributing to upstream repositories. NEVER work directly from upstream.

### Initial Setup (During /new-task)

**Before cloning any repository:**

1. **Check for existing fork:**
   ```bash
   gh repo view <username>/<repo> 2>/dev/null || echo "No fork found"
   ```

2. **Create fork if missing:**
   ```bash
   gh repo fork <org>/<repo> --clone=false
   ```

3. **Clone from YOUR FORK (not upstream):**
   ```bash
   # CORRECT: Clone from fork
   git clone https://github.com/<username>/<repo>.git repos/<repo>

   # WRONG: Never clone from upstream
   # git clone https://github.com/<org>/<repo>.git repos/<repo>  ❌
   ```

4. **Add upstream as secondary remote:**
   ```bash
   cd repos/<repo>
   git remote add upstream https://github.com/<org>/<repo>.git
   git remote set-url --push upstream DISABLE  # Prevent accidental pushes
   git fetch upstream
   ```

5. **Verify remote configuration:**
   ```bash
   git remote -v
   # Should show:
   # origin    https://github.com/<username>/<repo>.git (fetch)
   # origin    https://github.com/<username>/<repo>.git (push)
   # upstream  https://github.com/<org>/<repo>.git (fetch)
   # upstream  DISABLE (push)
   ```

### Task Configuration

**task.json MUST include fork information:**

```json
{
  "repositories": [{
    "name": "repo-name",
    "upstream_url": "https://github.com/org/repo.git",
    "fork_url": "https://github.com/username/repo.git",  ← REQUIRED
    "branch": "feature-branch",
    "fork_owner": "username",                             ← REQUIRED
    "tracking_remote": "origin",                          ← Should be origin (fork)
    "tracking_branch": "feature-branch"
  }]
}
```

**NEVER create task.json with:**
- `"fork_url": null`
- `"fork_owner": null`
- `"tracking_remote": "upstream"`

### Working with Forks

```bash
# Always push to origin (your fork)
git push origin feature-branch

# Pull updates from upstream
git fetch upstream
git merge upstream/main

# Create PR from your fork to upstream
gh pr create --repo <org>/<repo> --head <username>:feature-branch
```

### Complete Example

```bash
# User wants to work on temporal/sdk-java

# 1. Create fork (if needed)
gh repo fork temporalio/sdk-java --clone=false

# 2. Clone from YOUR fork
git clone https://github.com/maxim/sdk-java.git repos/sdk-java

# 3. Add upstream
cd repos/sdk-java
git remote add upstream https://github.com/temporalio/sdk-java.git
git remote set-url --push upstream DISABLE

# 4. Create feature branch
git checkout -b feature-branch

# 5. Work and push to YOUR fork
git add . && git commit -m "Implement feature"
git push origin feature-branch

# 6. Create PR from fork to upstream
gh pr create --repo temporalio/sdk-java --head maxim:feature-branch
```

## Best Practices

1. **Always Use Forks (CRITICAL)**: Never work directly from upstream. Create a fork BEFORE starting any task
2. **One Workspace Per Project Area**: Keep workspaces focused (e.g., "work", "personal", "sdk-dev")
3. **One Task = One Goal**: Keep tasks atomic and focused
4. **Update TASK_STATUS.md**: Always maintain context for continuity
5. **Verify Remotes**: Run `git remote -v` before pushing to confirm you're pushing to your fork
6. **Archive, Don't Delete**: Move completed tasks to `archived/` for history

## Troubleshooting

### "Not in a workspace"

Scripts require workspace context. Navigate to a workspace first:
```bash
cd workspaces/<name>
```

### "worktree already exists"

```bash
cd repos/<repo-name>
git worktree list
git worktree remove <path>
```

### List all worktrees

```bash
cd repos/<repo-name>
git worktree list
```

### Update repositories

```bash
cd repos/<repo-name>
git fetch --all
```

## Claude Code Integration

Claude understands this workspace structure and can:
- Navigate between workspaces and tasks
- Work across multiple repositories
- Create commits and PRs following the fork workflow
- Track progress via TASK_STATUS.md

**Start every session with `/list-workarea-tasks`** to see available workspaces and tasks.
