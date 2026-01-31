#!/bin/bash
# Git Safety Hook - Validates git commands target the correct repository
#
# This hook prevents Claude from running git commands in the wrong context,
# specifically ensuring operations happen in worktrees, not workspace repos.

# Read hook input from stdin
INPUT=$(cat)

# Extract relevant fields
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Only validate Bash tool git commands
if [[ "$TOOL_NAME" != "Bash" ]] || [[ ! "$COMMAND" =~ ^git[[:space:]] ]]; then
  exit 0  # Allow non-git commands
fi

# Skip validation for safe read-only commands
if echo "$COMMAND" | grep -qE '^git (status|log|diff|show|branch|remote -v|worktree list|fetch|config --get)'; then
  exit 0  # Allow safe read-only commands
fi

# For write operations (add, commit, push, reset, checkout, etc), validate context
# Note: git clone validation is handled by directory-structure-check.sh

# First, validate that if we're in a worktree, it's in the right location
# Worktrees should ONLY exist inside tasks/<task-name>/<repo-name>/
if [[ -f "$CWD/.git" ]]; then
  # This is a git worktree (has .git file, not directory)
  # Verify it's inside a tasks directory structure
  if [[ ! "$CWD" =~ /tasks/[^/]+/[^/]+/?$ ]]; then
    cat >&2 <<EOF
🛑 Git Safety Check: Worktree in unexpected location!

You're in a git worktree that's NOT inside the task structure:
  Working directory: $CWD
  Command: $COMMAND

Worktrees should ONLY exist inside task directories:
  ✅ Expected: workspaces/<name>/tasks/<task>/<repo>/
  ❌ Found: $CWD

This could be:
  - A worktree created in the wrong location
  - A different project's worktree
  - An orphaned worktree that should be removed

To fix:
  1. Use /resume-task to set up proper task worktrees
  2. Remove this worktree: git worktree remove $CWD
EOF
    exit 2  # Block operations in misplaced worktrees
  fi
  # Worktree is in the correct location - allow operation
  exit 0
fi

# Strategy: Worktrees have a .git FILE (not directory). Task roots have task.json.
# If we're in a task directory (has task.json) but NOT in a worktree (no .git file),
# then we're in the wrong place for code operations.

if [[ -f "$CWD/task.json" ]]; then
  # We're in a task directory
  # Check if this is a worktree (has .git file) or task root (no .git file)
  if [[ ! -f "$CWD/.git" ]]; then
    # Not a worktree - this is the task root (workspace repo context)
    # Special handling for task metadata vs code files

      # Special case: Allow git operations on task metadata files
      # Check if this is a commit/add operation for task metadata only
      if echo "$COMMAND" | grep -qE '^git (add|commit)'; then
        # Get the list of files being operated on
        if echo "$COMMAND" | grep -q 'git commit'; then
          # For commits, check staged files (relative to git repo root)
          GIT_ROOT=$(cd "$CWD" && git rev-parse --show-toplevel 2>/dev/null)
          STAGED_FILES=$(cd "$CWD" && git diff --cached --name-only 2>/dev/null || echo "")

          # Get task directory relative to git root
          TASK_REL_PATH=${CWD#$GIT_ROOT/}

          # Check if any staged files are in repository subdirectories within this task
          # E.g., if task is at "tasks/my-feature" and staged files include
          # "tasks/my-feature/sdk-java/...", that's code files
          while IFS= read -r file; do
            if [[ -z "$file" ]]; then
              continue
            fi

            # Check if file is under the task directory
            if [[ "$file" == "$TASK_REL_PATH/"* ]]; then
              # Get the part after the task directory
              FILE_IN_TASK=${file#$TASK_REL_PATH/}

              # Check if it's in a subdirectory (potential repository)
              if [[ "$FILE_IN_TASK" == *"/"* ]]; then
                SUBDIR=$(echo "$FILE_IN_TASK" | cut -d/ -f1)

                # Check if this subdirectory exists and looks like a repo (not allowed files)
                if [[ -d "$CWD/$SUBDIR" ]] && [[ "$SUBDIR" != ".claude" ]]; then
                  cat >&2 <<EOF
🛑 Git Safety Check: Code files staged in wrong repository!

You're trying to commit CODE files from the WORKSPACE repo context:
  Working directory: $CWD
  Command: $COMMAND

Staged file in repository subdirectory: $file

This will commit code changes to the workspace repo instead of the code repo!

✅ Correct: Navigate into the repository directory and commit from there
   Example: cd $SUBDIR/ && git add . && git commit -m "..."

❌ Wrong: Committing repository files from task root
   Current: $CWD

To fix:
  1. git reset (to unstage)
  2. cd $SUBDIR/
  3. git add <files>
  4. git commit -m "message"
EOF
                  exit 2  # Block the commit
                fi
              fi
            fi
          done <<< "$STAGED_FILES"

          # Only task metadata files staged - allow it
          exit 0

        elif echo "$COMMAND" | grep -q 'git add'; then
          # For git add, check if adding repository subdirectories
          # Extract the part after 'git add'
          CMD_ARGS=$(echo "$COMMAND" | sed 's/^git add //')

          # Check if adding paths with slashes (subdirectories)
          # Simple check: does the command contain a path with a slash?
          if echo "$CMD_ARGS" | grep -qE '[a-zA-Z0-9_-]+/'; then
            # Extract the first directory component
            FIRST_DIR=$(echo "$CMD_ARGS" | grep -oE '[a-zA-Z0-9_-]+/' | head -1 | tr -d '/')

            # Check if this directory exists and looks like a repository
            # (not tasks/, archived/, .claude/, etc.)
            if [[ -n "$FIRST_DIR" ]] && [[ "$FIRST_DIR" != "tasks" ]] && [[ "$FIRST_DIR" != "archived" ]] && [[ "$FIRST_DIR" != ".claude" ]] && [[ -d "$CWD/$FIRST_DIR" ]]; then
              cat >&2 <<EOF
🛑 Git Safety Check: Staging code files in wrong repository!

You're trying to stage CODE files from the WORKSPACE repo context:
  Working directory: $CWD
  Command: $COMMAND

This would stage files from repository subdirectories to the workspace repo!

Detected repository directory: $FIRST_DIR/

✅ Correct: Navigate into the repository directory first
   Example: cd $FIRST_DIR/ && git add <files>

❌ Wrong: git add $FIRST_DIR/<files> (from task root)
   Current: $CWD

To fix: Navigate to the specific repository directory first.
EOF
              exit 2  # Block the add
            fi
          fi

          # Only adding task metadata files or safe paths - allow it
          exit 0
        fi
      fi

    # For other operations (not add/commit), still block
    cat >&2 <<EOF
🛑 Git Safety Check: Operation blocked!

You're trying to run a git command from the WORKSPACE repo context:
  Working directory: $CWD
  Command: $COMMAND

This will affect the workspace repo (task.json, TASK_STATUS.md), not your code!

✅ Expected: Run git commands from inside the worktree directory
   Example: workspaces/<name>/tasks/<task>/<repo>/

❌ Wrong: Running from task root or workspace root
   Current: $CWD

To fix: Navigate to the specific repository directory first.
EOF
    exit 2  # Block the command
  fi
fi

# Additional safety: Verify remote is not a protected upstream
if echo "$COMMAND" | grep -qE '^git push'; then
  # Extract the remote being pushed to (defaults to 'origin')
  REMOTE=$(echo "$COMMAND" | sed -n 's/^git push \([^ ]*\).*/\1/p')
  [[ -z "$REMOTE" ]] && REMOTE="origin"

  # Get the remote URL
  REMOTE_URL=$(cd "$CWD" && git config --get "remote.$REMOTE.url" 2>/dev/null)

  # Check if pushing to known upstream organizations (not forks)
  if echo "$REMOTE_URL" | grep -qE '(temporalio|anthropic|openai|google|microsoft|facebook|apache)/'; then
    cat >&2 <<EOF
🛑 Git Safety Check: Push blocked!

You're trying to push to an UPSTREAM repository:
  Remote: $REMOTE
  URL: $REMOTE_URL

According to the Fork-First Policy, you should ONLY push to your personal fork.

✅ Correct: git push <your-username> <branch>
❌ Blocked: Pushing directly to upstream

To fix: Push to your fork remote instead.
EOF
    exit 2  # Block the push
  fi
fi

# Additional safety: Warn about destructive operations
if echo "$COMMAND" | grep -qE '^git (reset --hard|clean -fd|checkout \.|restore \.)'; then
  # Check if this is the workarea root itself (the tooling repo)
  if [[ "$CWD" =~ /workarea/?$ ]] && [[ ! "$CWD" =~ /workarea/workspaces/ ]]; then
    cat >&2 <<EOF
🛑 Git Safety Check: Destructive operation blocked in workarea root!

You're trying to run a DESTRUCTIVE git command in the workarea tooling repo:
  Working directory: $CWD
  Command: $COMMAND

This could destroy the workarea tooling itself!

✅ Expected: Run destructive commands only in task worktrees
❌ Blocked: Destructive operations in workarea root

To fix: Navigate to the specific task worktree first.
EOF
    exit 2  # Block destructive operations in workarea root
  fi
fi

# All checks passed
exit 0
