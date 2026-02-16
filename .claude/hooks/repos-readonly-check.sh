#!/bin/bash
# Repos Read-Only Hook - Blocks file edits and additions in repos/ directory
#
# The repos/ directory contains shared git clones that should stay clean.
# ALL file modifications must happen in task worktrees, never directly in repos/.
# This hook intercepts Edit, Write, NotebookEdit, and Bash file-writing commands.

# Read hook input from stdin
INPUT=$(cat)

# Extract relevant fields
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Detect workarea root
WORKAREA_ROOT=""
CURRENT_DIR="$CWD"
while [[ "$CURRENT_DIR" != "/" ]]; do
  if [[ -f "$CURRENT_DIR/CLAUDE.md" ]] && [[ -d "$CURRENT_DIR/bin" ]]; then
    WORKAREA_ROOT="$CURRENT_DIR"
    break
  fi
  CURRENT_DIR=$(dirname "$CURRENT_DIR")
done

# If not in workarea, skip validation
if [[ -z "$WORKAREA_ROOT" ]]; then
  exit 0
fi

REPOS_DIR="$WORKAREA_ROOT/repos"

# --- Helper: check if a path is inside repos/ ---
is_in_repos() {
  local filepath="$1"

  # Resolve to absolute path if relative
  if [[ "$filepath" != /* ]]; then
    filepath="$CWD/$filepath"
  fi

  # Normalize path (resolve .., symlinks, etc.)
  filepath=$(realpath -m "$filepath" 2>/dev/null || echo "$filepath")

  # Check if path starts with repos directory
  if [[ "$filepath" == "$REPOS_DIR"/* ]]; then
    return 0  # true: is in repos/
  fi
  return 1  # false: not in repos/
}

# --- Helper: print block message ---
block_repos_edit() {
  local filepath="$1"
  local tool="$2"
  cat >&2 <<EOF
🛑 Repos Read-Only Check: File modification blocked in repos/!

You're trying to modify a file in the shared repos/ directory:
  Tool: $tool
  File: $filepath

The repos/ directory contains shared git clones and must stay CLEAN.
ALL file modifications must happen in task worktrees.

✅ Correct: Edit files in task worktrees
   Location: workspaces/<name>/tasks/<task>/<repo>/

❌ Blocked: Editing files directly in repos/
   Location: $filepath

To fix:
  1. Navigate to your task worktree
  2. Make edits there instead
  3. If no task exists, create one with /new-task
EOF
  exit 2
}

# === CHECK Edit TOOL ===
if [[ "$TOOL_NAME" == "Edit" ]]; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
  if [[ -n "$FILE_PATH" ]] && is_in_repos "$FILE_PATH"; then
    block_repos_edit "$FILE_PATH" "Edit"
  fi
fi

# === CHECK Write TOOL ===
if [[ "$TOOL_NAME" == "Write" ]]; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
  if [[ -n "$FILE_PATH" ]] && is_in_repos "$FILE_PATH"; then
    block_repos_edit "$FILE_PATH" "Write"
  fi
fi

# === CHECK NotebookEdit TOOL ===
if [[ "$TOOL_NAME" == "NotebookEdit" ]]; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.notebook_path // empty')
  if [[ -n "$FILE_PATH" ]] && is_in_repos "$FILE_PATH"; then
    block_repos_edit "$FILE_PATH" "NotebookEdit"
  fi
fi

# === CHECK Bash TOOL for file-writing commands ===
if [[ "$TOOL_NAME" == "Bash" ]]; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

  # Check if CWD itself is inside repos/
  if is_in_repos "$CWD"; then
    # Block file-writing commands when CWD is inside repos/
    # Allow: read-only commands, git fetch, git worktree, git remote, git status, git log, git diff, git show, git config
    # Block: anything that creates/modifies files (cp, mv, touch, tee, sed -i, etc.)

    # FIRST: Block shell redirections that write files (>, >>)
    # Must check before read-only allow list since commands like echo can have redirections
    if echo "$COMMAND" | grep -qE '>[^&]|>>'; then
      cat >&2 <<EOF
🛑 Repos Read-Only Check: File write via redirection blocked in repos/!

You're trying to write to a file inside the shared repos/ directory:
  Working directory: $CWD
  Command: $COMMAND

The repos/ directory must stay clean. ALL modifications belong in task worktrees.

✅ Correct: Write files in task worktrees
❌ Blocked: File redirection in repos/

To fix: Navigate to your task worktree first.
EOF
      exit 2
    fi

    # Block file-creating/modifying commands
    if echo "$COMMAND" | grep -qE '^(touch |cp |mv |mkdir |chmod |chown |ln |tee |sed -i|perl -i|patch )'; then
      cat >&2 <<EOF
🛑 Repos Read-Only Check: File modification blocked in repos/!

You're trying to run a file-modifying command inside the shared repos/ directory:
  Working directory: $CWD
  Command: $COMMAND

The repos/ directory must stay clean. ALL modifications belong in task worktrees.

✅ Correct: Run file-modifying commands in task worktrees
   Location: workspaces/<name>/tasks/<task>/<repo>/

❌ Blocked: File modification in repos/
   Current: $CWD

To fix: Navigate to your task worktree first.
EOF
      exit 2
    fi

    # Allow cd (shell builtin, doesn't modify files)
    if echo "$COMMAND" | grep -qE '^cd '; then
      exit 0
    fi
    # Allow safe read-only commands
    if echo "$COMMAND" | grep -qE '^(cat |head |tail |less |more |ls |find |grep |rg |wc |file |stat |du |tree |pwd|cd )'; then
      exit 0  # Read-only commands (cd changes CWD but doesn't modify files)
    fi
    # Allow gh CLI read-only commands (API queries, not file operations)
    if echo "$COMMAND" | grep -qE '^gh (api |repo view |repo list |pr view |pr list |issue view |issue list |auth status)'; then
      exit 0
    fi
    if echo "$COMMAND" | grep -qE '^git (status|log|diff|show|branch|remote|worktree|fetch|config|rev-parse|describe|tag -l|stash list)'; then
      exit 0  # Safe git commands
    fi
    # Allow git checkout main/master for syncing
    if echo "$COMMAND" | grep -qE '^git (checkout|switch)[[:space:]]+(main|master)([[:space:]]|$)'; then
      exit 0
    fi
    # Allow git reset --hard origin/main for syncing
    if echo "$COMMAND" | grep -qE '^git reset --hard origin/(main|master)([[:space:]]|$)'; then
      exit 0
    fi
    # Allow build/test commands (read-only execution)
    if echo "$COMMAND" | grep -qE '^(\./gradlew |gradle |mvn |npm |yarn |pnpm |go |cargo |make |python |pip )'; then
      exit 0  # Build/test commands (needed for reading/understanding repos)
    fi

    # Block everything else in repos/ - default deny
    cat >&2 <<EOF
🛑 Repos Read-Only Check: Command blocked in repos/!

You're trying to run a command inside the shared repos/ directory:
  Working directory: $CWD
  Command: $COMMAND

The repos/ directory must stay clean. Only read-only operations are allowed.

✅ Allowed: git fetch, git status, git log, git diff, cat, ls, grep, etc.
❌ Blocked: Any command that could modify files

To fix: Navigate to your task worktree to run this command.
EOF
    exit 2
  fi

  # Also check if commands reference repos/ paths explicitly (even from outside)
  # e.g., `cp foo repos/bar/baz` or `sed -i 's/x/y/' /path/to/repos/file`
  if echo "$COMMAND" | grep -qE "(^|[[:space:]])(touch|cp|mv|tee|sed -i|perl -i|patch)[[:space:]].*$REPOS_DIR/"; then
    cat >&2 <<EOF
🛑 Repos Read-Only Check: File modification targeting repos/ blocked!

A command is trying to modify files in the shared repos/ directory:
  Command: $COMMAND

The repos/ directory must stay clean. ALL modifications belong in task worktrees.

✅ Correct: Modify files in task worktrees
❌ Blocked: Targeting repos/ from outside

To fix: Target your task worktree path instead.
EOF
    exit 2
  fi
fi

# === CHECK MCP filesystem tools ===
if [[ "$TOOL_NAME" == "mcp__filesystem__write_file" ]] || [[ "$TOOL_NAME" == "mcp__filesystem__edit_file" ]]; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // empty')
  if [[ -n "$FILE_PATH" ]] && is_in_repos "$FILE_PATH"; then
    block_repos_edit "$FILE_PATH" "$TOOL_NAME"
  fi
fi

# All checks passed
exit 0
