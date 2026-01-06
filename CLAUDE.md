# Claude Code - Task Workspace Management

This document explains the task-based workflow for managing multiple git repositories using Claude Code.

## Overview

This workspace uses a structured approach to organize work across multiple repositories:

```
workarea/
├── repos/           # Main git repositories (bare clones)
├── tasks/           # Task-specific workspaces
│   ├── feature-a/   # Each task has its own folder
│   │   ├── repo1/   # Git worktree for repo1
│   │   └── repo2/   # Git worktree for repo2
│   └── feature-b/
│       └── repo1/
└── bin/             # Utility scripts
```

## Benefits

- **Isolation**: Each task has its own workspace with separate worktrees
- **Efficiency**: No need to clone repos multiple times or switch branches
- **Organization**: All task-related changes are grouped together
- **Parallel Work**: Work on multiple features simultaneously without conflicts

## Workflow

### 1. Using the `/new-task` Command (Recommended)

The easiest way to set up a new task workspace:

```
/new-task Implement user authentication for frontend and backend
```

Claude will:
1. Analyze the task description
2. Identify which repositories are needed
3. Run the setup script automatically
4. Create worktrees in `tasks/<task-name>/`

### 2. Manual Setup with Script

If you know exactly which repositories you need:

```bash
# With repository URLs
./bin/setup-task-workspace.sh task-name \
  https://github.com/org/repo1.git \
  https://github.com/org/repo2.git

# With PR URL (automatically handles fork branches)
./bin/setup-task-workspace.sh task-name \
  https://github.com/org/repo/pull/123
```

**Features:**
- **PR URL Support**: Pass a GitHub PR URL and the script automatically:
  - Fetches the PR branch
  - Detects if it's from a fork
  - Adds the fork remote
  - Checks out the correct branch
- **Absolute Path Handling**: Works from any directory
- **Smart Branch Detection**: Uses PR branch, custom branch, or creates new branch

**Options:**
- `-b <branch>` - Use a specific branch instead of creating `task/<task-name>`
- `-h, --help` - Show help message

### 3. Working on a Task

Once the workspace is set up:

```bash
cd tasks/my-task
ls                    # See all repository worktrees
cd repo1              # Work in specific repo
git status            # Normal git commands work
```

Each worktree is a full git working directory:
- Make commits independently
- Create branches
- Push/pull changes
- All standard git operations

### 4. Task Status Documentation

**IMPORTANT:** For each task, maintain a `TASK_STATUS.md` file in the task directory that tracks:
- Task overview and PR/issue links
- Current status and progress
- CI/test failures and analysis
- Investigation findings
- Next steps and resolution strategy
- Key file paths and commands
- Enough context for a fresh Claude session to continue

**Location:** `tasks/<task-name>/TASK_STATUS.md`

**Purpose:** This document ensures continuity across Claude sessions and provides a single source of truth for the task's current state.

**When to update:**
- After initial task setup
- When discovering important findings
- After CI check failures
- Before/after significant code changes
- When blocked or changing direction

**Example structure:**
```markdown
# Task Status: [Task Name]

## Task Overview
- PR/Issue links
- Summary of what needs to be done

## Current Status
- Where you are in the investigation/implementation
- What's been completed
- What's pending

## CI/Test Status
- Passing/failing checks
- Specific error messages
- Analysis of failures

## Investigation Needed
- Questions to answer
- Files to examine
- Tests to run

## Commands Reference
- Build/test commands
- Git operations

## Session Handoff Checklist
- Steps for next session to continue
```

## Repository Management

### Main Repository Storage

Repositories are cloned once into `repos/`:
```bash
repos/
├── frontend/     # Main repo
├── backend/      # Main repo
└── shared/       # Main repo
```

### Git Worktrees

Each task gets worktrees (linked working directories):
```bash
tasks/auth-feature/
├── frontend/     # Worktree on branch task/auth-feature
└── backend/      # Worktree on branch task/auth-feature
```

Benefits:
- Share git history and objects
- Save disk space
- Fast creation/deletion
- Independent working states

## Common Operations

### Start New Task
```
/new-task Add pagination to user list view
```

### Check Task Status
```bash
cd tasks/my-task
for dir in */; do
  echo "=== $dir ==="
  (cd "$dir" && git status -s)
done
```

### Clean Up Completed Task
```bash
# Remove worktrees
cd repos/repo-name
git worktree remove ../../tasks/completed-task/repo-name

# Remove task directory
rm -rf tasks/completed-task
```

### List All Worktrees
```bash
cd repos/repo-name
git worktree list
```

## Best Practices

1. **One Task = One Goal**: Keep tasks focused and atomic
2. **Clean Branches**: Use descriptive task names (e.g., `fix-login-bug`, `add-dark-mode`)
3. **Regular Cleanup**: Remove completed task workspaces
4. **Commit Often**: Each worktree maintains its own state
5. **Push Early**: Push branches to back up your work

## Example Workflows

### Working on a New Feature

```bash
# 1. Start new task
/new-task Implement OAuth2 login flow

# 2. Navigate to task
cd tasks/implement-oauth2-login-flow

# 3. Work in each repo
cd frontend
# ... make changes ...
git add .
git commit -m "Add OAuth2 login UI"

cd ../backend
# ... make changes ...
git add .
git commit -m "Implement OAuth2 endpoints"

# 4. Push changes
cd frontend && git push -u origin task/implement-oauth2-login-flow
cd ../backend && git push -u origin task/implement-oauth2-login-flow

# 5. Create PRs (manual or via gh CLI)
gh pr create --title "Add OAuth2 login" --body "..."

# 6. After merge, clean up
cd ../..
rm -rf tasks/implement-oauth2-login-flow
cd repos/frontend && git worktree prune
cd ../backend && git worktree prune
```

### Working on an Existing PR

```bash
# 1. Set up workspace with PR URL (automatic branch detection)
./bin/setup-task-workspace.sh review-auth-pr \
  https://github.com/org/repo/pull/2751

# 2. Navigate to task
cd tasks/review-auth-pr/repo

# 3. Make changes, test, commit
git status
# ... make changes ...
git add .
git commit -m "Fix issue with authentication"

# 4. Push changes
git push

# 5. Clean up after PR is merged
cd ../..
rm -rf tasks/review-auth-pr
cd repos/repo && git worktree prune
```

## Troubleshooting

### "worktree already exists"
```bash
cd repos/repo-name
git worktree list
git worktree remove path/to/worktree
```

### "branch already exists"
```bash
# Use existing branch
./bin/setup-task-workspace.sh task-name -b existing-branch repo-url

# Or delete old branch
git branch -D task/old-task-name
```

### Update main repositories
```bash
cd repos/repo-name
git fetch --all
git pull
```

## Integration with Claude Code

Claude Code is aware of this structure and can:
- Navigate task workspaces
- Work across multiple repositories
- Create commits in appropriate repos
- Understand the relationship between tasks and code

When working with Claude, mention the task name and it will understand the context.
