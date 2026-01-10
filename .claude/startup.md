# Workarea Startup Guide

**Welcome to your multi-workspace task manager!**

This tooling helps you manage multiple development tasks across repositories using git worktrees and workspaces.

## Quick Start Commands

- **`/workarea-tasks`** - See workspaces (at root) or tasks (in workspace)
- **`/new-workspace`** - Create a new workspace
- **`/new-task`** - Start a new task (must be in workspace)
- **`/resume-task`** - Restore a specific task (must be in workspace)

## First Time Setup

```bash
# 1. Create your first workspace
/new-workspace personal "My projects"

# 2. Navigate to it
cd workspaces/personal

# 3. Create or resume tasks
/new-task https://github.com/org/repo/pull/123
```

## Recommended: Start Every Session

```
/workarea-tasks
```

This shows you:
- **At root**: Available workspaces with task counts
- **In workspace**: Tasks with CI status and last update time

## Directory Structure

```
workarea/
├── bin/                 # Shared scripts
├── repos/               # Shared git clones
├── workspaces/          # Your workspaces
│   ├── personal/        # A workspace
│   │   ├── tasks/       # Active tasks
│   │   └── archived/    # Completed tasks
│   └── work/            # Another workspace
└── CLAUDE.md            # Full documentation
```

## Your Workflow

### Starting Your Day
```bash
cd workarea
/workarea-tasks          # Pick workspace
cd workspaces/<name>
/workarea-tasks          # Pick task
cd tasks/<task>/<repo>
git pull                 # Get latest
```

### During Work
- Make changes in worktrees (`tasks/<name>/repo/`)
- Push to your personal forks regularly
- Update `TASK_STATUS.md` with findings

### Ending Your Day
```bash
git push                 # Push code changes
# Update task documentation
vim ../TASK_STATUS.md
```

## Key Concepts

- **Workspaces** - Isolated containers for related tasks
- **Shared repos** - All workspaces share same cloned repos
- **Portable tasks** - task.json enables cross-machine work
- **Fork-based** - Always push to personal forks

## Need Help?

- **CLAUDE.md** - Complete workflow guide

---

**Ready to start?** Run `/workarea-tasks` to see your workspaces!
