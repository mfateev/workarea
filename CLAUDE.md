# Claude Code - Task Workspace Management

## Session Startup Behavior

**IMPORTANT:** At the start of every session in this directory, immediately display the workspace status from the SessionStart hook output. Show it verbatim before responding to anything else.

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

- **`/workarea-tasks`** - List tasks or workspaces
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
/workarea-tasks          # Shows available workspaces
cd workspaces/<name>
/workarea-tasks          # Shows tasks in this workspace
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

**Always use personal forks when contributing to upstream repositories.**

### Setup

```bash
# Add fork as remote
cd workspaces/<workspace>/tasks/<task>/<repo>
git remote add <username> https://github.com/<username>/<fork>.git

# Push to fork, not origin
git push <username> <branch>

# Create PR from fork
gh pr create --repo <org>/<repo> --head <username>:<branch>
```

### Example

```bash
# Working on org/repo, user is <username>
cd workspaces/myworkspace/tasks/feature/repo

# Add fork remote
git remote add <username> https://github.com/<username>/<fork-repo>.git

# Make changes and push to fork
git add . && git commit -m "Implement feature"
git push <username> feature-branch

# Create PR
gh pr create --repo <org>/<repo> --head <username>:feature-branch
```

## Best Practices

1. **One Workspace Per Project Area**: Keep workspaces focused (e.g., "work", "personal", "sdk-dev")
2. **One Task = One Goal**: Keep tasks atomic and focused
3. **Update TASK_STATUS.md**: Always maintain context for continuity
4. **Use Forks**: Never push directly to upstream repositories
5. **Archive, Don't Delete**: Move completed tasks to `archived/` for history

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

**Start every session with `/workarea-tasks`** to see available workspaces and tasks.
