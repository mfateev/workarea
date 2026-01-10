# Workarea - Multi-Repository Task Management

Reusable tooling for managing development tasks across multiple git repositories using workspaces and git worktrees.

## Overview

Workarea provides a structured approach to organizing multi-repo development work:
- **Workspaces** isolate related tasks (e.g., "issues", "projects", "experiments")
- **Tasks** contain git worktrees for each repository involved
- **Shared repos** save disk space across all workspaces
- **Portable configs** enable cross-machine workflows

```
workarea/
├── bin/                     # Shared scripts (tracked)
├── repos/                   # Git clones - shared (gitignored)
├── workspaces/              # Workspace container
│   └── <name>/              # Individual workspaces (gitignored, separate repos)
│       ├── tasks/
│       │   └── <task>/
│       │       ├── task.json       # Portable config
│       │       ├── TASK_STATUS.md  # Progress notes
│       │       └── <repo>/         # Git worktree
│       └── archived/
├── .claude/                 # Claude Code skills (tracked)
└── CLAUDE.md                # Documentation (tracked)
```

## Commands

| Command | Description |
|---------|-------------|
| `/new-workspace` | Create a new workspace |
| `/clone-workspace` | Clone existing workspace from GitHub |
| `/detach-workspace` | Safely remove workspace (after push) |
| `/workarea-tasks` | List workspaces or tasks |
| `/new-task` | Create a new task |
| `/resume-task` | Restore task worktrees |

## Quick Start

### First Time Setup

```bash
# 1. Clone workarea tooling
git clone https://github.com/<username>/workarea.git
cd workarea

# 2. Create a workspace
/new-workspace issues "Bug fixes and PRs"

# 3. Navigate and create a task
cd workspaces/issues
/new-task https://github.com/org/repo/pull/123
```

### Returning User

```bash
cd workarea
/workarea-tasks              # See workspaces
cd workspaces/issues
/workarea-tasks              # See tasks
/resume-task my-feature      # Restore worktrees
```

### New Machine

```bash
# Clone tooling
git clone https://github.com/<username>/workarea.git
cd workarea

# Clone your workspace
/clone-workspace workspace-issues
cd workspaces/issues
/resume-task my-feature
```

## Workspace Lifecycle

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  /new-workspace │ ──► │  Push to GitHub │ ──► │ /clone-workspace│
│  (create local) │     │  (backup/share) │     │ (new machine)   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│/detach-workspace│ ◄── │   git push      │ ◄── │  Work on tasks  │
│ (cleanup local) │     │  (save progress)│     │ /new-task, etc  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Key Concepts

### Workspaces
- Isolated containers for related tasks
- Each workspace is a separate git repository
- Can be pushed to GitHub and cloned elsewhere
- Gitignored in main workarea repo

### Shared Repos
- All workspaces share `repos/` directory
- Repositories cloned once, used by all tasks
- Git worktrees provide isolated working directories

### Task Portability
- `task.json` captures full repo/branch configuration
- `TASK_STATUS.md` preserves investigation context
- `/resume-task` restores complete workspace from config

## Requirements

- Git 2.5+ (worktree support)
- GitHub CLI (`gh`) for PR/repo operations
- `jq` for JSON parsing
- Bash 4.0+

## Documentation

- **[CLAUDE.md](CLAUDE.md)** - Detailed workflow guide

## License

MIT - Feel free to fork and adapt.
