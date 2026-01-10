# Cross-Machine Task Workflow

This document explains how to work on tasks across multiple machines using the task restoration system.

## Overview

The workarea repository tracks task metadata (not actual code) allowing you to:
- Start a task on Machine A
- Continue the same task on Machine B
- Return to Machine A and sync progress
- All repository configurations preserved

## Key Concept

**What's in Git:**
- ✅ `task.json` - Repository URLs, branches, fork information
- ✅ `TASK_STATUS.md` - Investigation notes, progress, CI status
- ❌ Actual code repositories (in `repos/`)
- ❌ Git worktrees (in `tasks/*/`)

**Assumption:** All code changes are pushed to your personal forks (e.g., `<username>/repo`)

## Complete Workflow Example

### Machine A: Start New Task

```bash
# 1. Navigate to workarea
cd /path/to/workarea

# 2. Start working on a PR
/new-task https://github.com/org/repo/pull/123

# Or use the script directly
./bin/setup-task-workspace.sh my-feature https://github.com/org/repo/pull/123

# This creates:
# - repos/repo/ (clone)
# - tasks/my-feature/repo/ (worktree)
# - tasks/my-feature/task.json (config - tracked in git)
# - tasks/my-feature/TASK_STATUS.md (docs - tracked in git)

# 3. Work on the task
cd tasks/my-feature/repo
# ... investigate, make changes ...

# 4. Push changes to YOUR FORK
git add .
git commit -m "Fix metrics test issue"
git push  # Pushes to <username>/fork-repo fork

# 5. Update task status
cd ..
vim TASK_STATUS.md
# ... document findings, CI failures, next steps ...

# 6. Commit documentation to workarea repo
cd ../..  # Back to workarea root
git add tasks/my-feature/TASK_STATUS.md
git commit -m "Update my-feature: analyzed metrics test failure"
git push  # Pushes to <username>/workarea
```

### Machine B: Continue Same Task

```bash
# 1. Clone workarea (if not already done)
git clone https://github.com/<username>/workarea.git
cd workarea

# 2. See available tasks
ls tasks/
# Output: my-feature

# 3. Read task status to understand current progress
cat tasks/my-feature/TASK_STATUS.md
# Shows: investigation notes, CI failures, what was discovered

cat tasks/my-feature/task.json
# Shows: repo URLs, branch names, fork configuration

# 4. Restore the complete task workspace
./bin/resume-task.sh my-feature

# This automatically:
# - Clones org/repo to repos/repo
# - Adds <username> remote pointing to your fork
# - Fetches <username>/my-feature branch
# - Creates worktree at tasks/my-feature/repo
# - Checks out the correct branch
# - Sets up tracking to <username>/my-feature

# 5. Start working immediately
cd tasks/my-feature/repo
git status  # Shows you're on my-feature branch, tracking <username> remote
git pull    # Gets latest changes from your fork

# 6. Continue work
# ... make more changes based on TASK_STATUS.md notes ...

# 7. Push changes back to YOUR FORK
git add .
git commit -m "Implement fix for metrics test"
git push  # Pushes to <username>/fork-repo

# 8. Update task status with progress
cd ..
vim TASK_STATUS.md
# ... document the fix, update CI status ...

# 9. Commit documentation
cd ../..
git add tasks/my-feature/TASK_STATUS.md
git commit -m "Update my-feature: implemented metrics test fix"
git push
```

### Machine A: Resume and Sync

```bash
# 1. Navigate to workarea
cd /path/to/workarea

# 2. Pull latest task documentation
git pull
# Gets updated TASK_STATUS.md from Machine B

# 3. Read what was done on Machine B
cat tasks/my-feature/TASK_STATUS.md

# 4. Pull code changes in the worktree
cd tasks/my-feature/repo
git pull  # Gets changes from <username>/fork-repo fork

# 5. Continue working or verify the fix
# ... test, review, finalize ...

# 6. Push final changes
git push

# 7. Update task status (mark as complete if done)
cd ..
vim TASK_STATUS.md
# ... mark as resolved, document final state ...

cd ../..
git add tasks/my-feature/TASK_STATUS.md
git commit -m "Mark my-feature as completed"
git push
```

## What Gets Synchronized

### Code Changes (via YOUR fork)
```
Machine A → push → github.com/<username>/fork-repo
         ↓
Machine B ← pull ← github.com/<username>/fork-repo
```

### Documentation (via workarea repo)
```
Machine A → push → github.com/<username>/workarea
         ↓
Machine B ← pull ← github.com/<username>/workarea
```

## Benefits

1. **No Context Loss:** Task status documents preserve all investigation notes
2. **Automatic Setup:** `resume-task.sh` recreates identical workspace
3. **Fork-based:** All changes in your personal forks, safe experimentation
4. **Lightweight:** Workarea repo only stores metadata, not code
5. **Multi-machine:** Work from laptop, desktop, or any machine seamlessly

## File Tracking Summary

| File | Location | Tracked in Git | Purpose |
|------|----------|----------------|---------|
| `task.json` | `tasks/<name>/` | ✅ Yes (workarea) | Repository configuration |
| `TASK_STATUS.md` | `tasks/<name>/` | ✅ Yes (workarea) | Investigation notes |
| Repositories | `repos/<name>/` | ❌ No | Cloned from GitHub |
| Worktrees | `tasks/<name>/<repo>/` | ❌ No | Working directories |

## Commands Reference

```bash
# On fresh machine
git clone https://github.com/<username>/workarea.git
cd workarea
./bin/resume-task.sh <task-name>

# Update documentation
vim tasks/<task-name>/TASK_STATUS.md
git add tasks/<task-name>/TASK_STATUS.md
git commit -m "Update task: <description>"
git push

# Sync code changes
cd tasks/<task-name>/<repo>
git pull   # Get changes from fork
git push   # Push changes to fork

# Sync documentation
cd /path/to/workarea
git pull   # Get latest task documentation
git push   # Share your documentation updates
```

## Cleanup

When task is complete:

```bash
# 1. Remove local worktree
cd repos/<repo>
git worktree remove ../../tasks/<task-name>/<repo>

# 2. Remove task directory
rm -rf tasks/<task-name>

# 3. Commit removal to workarea
git add -A
git commit -m "Remove completed task: <task-name>"
git push

# 4. (Optional) Clean up your fork branch
git push <username> --delete <branch-name>
```

## Troubleshooting

### "Worktree already exists"
```bash
cd tasks/<task-name>/<repo>
git pull  # Just sync, don't recreate
```

### "Can't find branch"
```bash
cd repos/<repo>
git fetch --all
git branch -a  # See all branches
```

### "Fork remote not found"
```bash
cd repos/<repo>
git remote add <username> https://github.com/<username>/<repo>.git
git fetch <username>
```

---

**Key Takeaway:** The `task.json` file is the magic that makes this all work. It captures everything needed to recreate your exact workspace on any machine!
