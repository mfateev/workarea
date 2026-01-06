# Workarea - Task Workspace Management

A structured workflow system for managing multi-repository development tasks using git worktrees.

## What is This?

This repository contains the infrastructure and documentation for organizing development work across multiple git repositories using a task-based approach with git worktrees.

**Repository URL:** https://github.com/mfateev/workarea

## Structure

```
workarea/
├── bin/                    # Utility scripts
│   └── setup-task-workspace.sh   # Main setup script
├── .claude/                # Claude Code configuration
│   └── commands/          # Custom slash commands
│       └── new-task.md    # /new-task skill definition
├── tasks/                  # Task workspaces (not in git)
│   └── <task-name>/
│       ├── task.json       # Task configuration (tracked)
│       ├── TASK_STATUS.md  # Task documentation (tracked)
│       └── <repo>/         # Git worktree (not tracked)
├── repos/                  # Repository storage (not in git)
│   └── <repo-name>/       # Main repositories
├── CLAUDE.md              # Main documentation
├── IMPROVEMENTS.md        # Changelog
└── README.md             # This file
```

## What's Tracked in Git

**Included:**
- ✅ Documentation (`.md` files)
- ✅ Scripts (`bin/`)
- ✅ Configuration (`.claude/`)
- ✅ Task status documents (`tasks/*/TASK_STATUS.md`)

**Excluded:**
- ❌ Cloned repositories (`repos/`)
- ❌ Git worktrees (`tasks/*/*/`)

This keeps the workspace repository lightweight while preserving documentation and tooling.

## Features

### 🚀 Automated Task Setup

Set up a complete task workspace with one command:

```bash
# For PR URLs (automatic branch detection)
/new-task https://github.com/org/repo/pull/123

# For new tasks
/new-task Implement user authentication
```

### 🔄 Task Restoration

Resume any task on any machine with full context:

```bash
# Clone workarea repository
git clone https://github.com/mfateev/workarea.git
cd workarea

# List available tasks
ls tasks/

# Restore complete task workspace
/resume-task async-await
# Or use the script directly:
./bin/resume-task.sh async-await

# Start working immediately
cd tasks/async-await/sdk-java
```

The `task.json` file in each task directory contains:
- Repository URLs (upstream and your fork)
- Branch names
- Remote tracking configuration
- PR information

**This enables perfect task restoration from any machine!**

### 🔄 Git Worktree Management

- Each task gets isolated worktrees
- No need to clone repositories multiple times
- Work on multiple tasks in parallel
- Fast switching between tasks

### 📋 Task Status Documentation

Every task includes a `TASK_STATUS.md` that tracks:
- Task overview and goals
- Current progress
- CI/test status
- Investigation findings
- Next steps for continuation

### 🔌 PR URL Support

Pass GitHub PR URLs directly:
- Automatically fetches PR branch
- Handles fork remotes
- Sets up correct branch checkout

## Quick Start

### Starting a New Task

1. **Clone this repository:**
   ```bash
   git clone https://github.com/mfateev/workarea.git
   cd workarea
   ```

2. **Start a new task:**
   ```bash
   # With Claude Code (recommended)
   /new-task https://github.com/org/repo/pull/123

   # Or with script directly
   ./bin/setup-task-workspace.sh task-name https://github.com/org/repo/pull/123
   ```

3. **Work on the task:**
   ```bash
   cd tasks/task-name/repo
   # Make changes, commit, push
   ```

4. **Track progress:**
   ```bash
   # Update task status
   vim tasks/task-name/TASK_STATUS.md

   # Commit documentation changes
   git add tasks/task-name/TASK_STATUS.md
   git commit -m "Update task status"
   git push
   ```

### Resuming an Existing Task

1. **Clone workarea (on new machine):**
   ```bash
   git clone https://github.com/mfateev/workarea.git
   cd workarea
   ```

2. **See available tasks:**
   ```bash
   ls tasks/
   ```

3. **Resume a task:**
   ```bash
   # With Claude Code (recommended)
   /resume-task async-await

   # Or with script directly
   ./bin/resume-task.sh async-await
   ```

4. **Continue working:**
   ```bash
   cd tasks/async-await/repo
   git pull  # Get latest changes from your fork
   # Continue working...
   ```

## Documentation

- **[CLAUDE.md](CLAUDE.md)** - Complete workflow guide
- **[IMPROVEMENTS.md](IMPROVEMENTS.md)** - Changelog and improvements
- **[setup-task-workspace.sh](bin/setup-task-workspace.sh)** - Main setup script

## Requirements

- Git 2.5+ (for worktree support)
- GitHub CLI (`gh`) for PR URL support
- Bash 4.0+

## Benefits

- **Session Continuity:** Task status documents preserve context across sessions
- **Parallel Work:** Multiple tasks without repository conflicts
- **Efficient Storage:** Shared git objects, no duplicate clones
- **Clean Organization:** Task-based structure with clear separation
- **Automation:** One command setup for both new tasks and existing PRs

## Example Workflow

```bash
# 1. Start working on a PR
/new-task https://github.com/temporalio/sdk-java/pull/2751

# 2. Navigate to task
cd tasks/async-await/sdk-java

# 3. Investigate, make changes
# ... work happens here ...

# 4. Update task status
vim ../TASK_STATUS.md

# 5. Commit and push changes
git add .
git commit -m "Fix metrics test issue"
git push

# 6. Document progress in workarea repo
cd ../..  # Back to workarea root
git add tasks/async-await/TASK_STATUS.md
git commit -m "Update async-await task status"
git push
```

## Contributing

This is a personal workspace management system. Feel free to fork and adapt for your needs.

## License

Private repository for personal use.

---

**Created:** 2026-01-06
**Author:** Maxim Fateev
**Purpose:** Efficient multi-repository task management with Claude Code
