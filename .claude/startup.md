# Workarea Startup Guide

**Welcome to your multi-task workspace!**

This workspace helps you manage multiple development tasks across repositories using git worktrees.

## Quick Start Commands

- **`/workarea-tasks`** - See all available tasks and choose which to work on
- **`/new-task`** - Start a new task from a PR or description
- **`/resume-task`** - Restore a specific task by name

## Recommended: Start Every Session

```
/workarea-tasks
```

This shows you:
- All active tasks
- CI status for each
- Last time you worked on each
- Quick selection to resume any task

## Available Tasks

Run `/workarea-tasks` to see your current work queue with details like:
```
1. 🔴 async-await       [PR #2751] Failing CI - needs fix
2. 🟡 feature-auth      [WIP] In progress
3. 🟢 fix-pagination    [Done] Ready to clean up
```

## Your Workflow

### Starting Your Day
```bash
cd /Users/maxim/ai/workarea
/workarea-tasks                    # Choose what to work on
# Select a task from the list
cd tasks/<task>/repo
git pull                  # Get latest from your fork
```

### During Work
- Make changes in worktrees (`tasks/<name>/repo/`)
- Push to your personal forks regularly
- Update `TASK_STATUS.md` with findings

### Ending Your Day
```bash
# Push code changes
git push

# Update task documentation
cd ..
vim TASK_STATUS.md
git add TASK_STATUS.md
git commit -m "EOD: Update task status"
git push
```

### Switching Machines
```bash
# On new machine
git clone https://github.com/mfateev/workarea.git
cd workarea
/workarea-tasks                    # Same interface, choose task
```

## Directory Structure

```
workarea/
├── tasks/              # Your active work
│   ├── async-await/    # PR #2751 investigation
│   └── feature-auth/   # Authentication implementation
├── repos/              # Cloned repositories (not in git)
└── bin/                # Automation scripts
```

## Key Concepts

- **Tasks are portable** - Work on any machine
- **Fork-based** - All changes go to mfateev/* forks
- **Documented** - Every task has status notes
- **Automated** - Scripts handle repo setup

## Need Help?

- **CLAUDE.md** - Complete workflow guide
- **README.md** - Feature overview
- **CROSS_MACHINE_WORKFLOW.md** - Multi-machine usage

---

**Ready to start?** Run `/workarea-tasks` to see your work queue!
