#!/bin/bash
# Directory Structure Hook - Validates workarea architecture is followed
#
# This hook ensures Claude follows the workarea directory structure:
# - Only workspaces/ and repos/ directories at root
# - Workspaces must be git repositories
# - No unauthorized directory creation

# Read hook input from stdin
INPUT=$(cat)

# Extract relevant fields
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Only validate Bash tool commands
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0  # Only validate Bash commands
fi

# Detect workarea root by checking for CLAUDE.md and bin/ directory
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

# === VALIDATE GIT CLONE ===
# Git clone operations must target repos/ directory only

if echo "$COMMAND" | grep -qE '^git clone'; then
  # Extract target directory from git clone command
  # Get the last argument (usually the target directory)
  TARGET_DIR=$(echo "$COMMAND" | awk '{print $NF}')

  # If last argument is a URL, no target was specified - extract repo name
  if [[ "$TARGET_DIR" =~ ^(https?://|git@) ]]; then
    TARGET_DIR=$(basename "$TARGET_DIR" .git)
  fi

  # Resolve target path relative to CWD
  if [[ "$TARGET_DIR" = /* ]]; then
    FULL_TARGET="$TARGET_DIR"
  else
    FULL_TARGET="$CWD/$TARGET_DIR"
  fi

  # Normalize path
  FULL_TARGET=$(realpath -m "$FULL_TARGET" 2>/dev/null || echo "$FULL_TARGET")

  # Check if target is in repos/ directory
  if [[ ! "$FULL_TARGET" =~ /repos/[^/]+/?$ ]]; then
    cat >&2 <<EOF
🛑 Directory Structure Check: Clone target violates architecture!

You're trying to clone a repository outside the 'repos/' directory:
  Command: $COMMAND
  Target: $FULL_TARGET

Workarea architecture requires:
  ✅ Correct: Clone repositories into repos/
     Example: git clone <url> repos/sdk-java

  ❌ Wrong: Cloning into workspaces, tasks, or workarea root
     Current: $FULL_TARGET

The 'repos/' directory is for shared git clones used by all workspaces.
Use /resume-task to create worktrees in the correct locations.

To fix: Specify the target as 'repos/<repo-name>'
EOF
    exit 2  # Block the clone
  fi

  # Clone is targeting repos/ - allow it
  exit 0
fi

# === VALIDATE DIRECTORY CREATION ===
# Check for mkdir, mv, or cp commands that create directories at root level

if echo "$COMMAND" | grep -qE '^(mkdir|mv|cp) '; then
  # Extract target paths from command
  # This is a simplified extraction - handles common cases
  TARGETS=$(echo "$COMMAND" | sed -E 's/^(mkdir|mv|cp)( -[a-zA-Z]+)* //' | tr ' ' '\n' | grep -v '^-')

  while IFS= read -r TARGET; do
    [[ -z "$TARGET" ]] && continue

    # Resolve to absolute path
    if [[ "$TARGET" = /* ]]; then
      FULL_PATH="$TARGET"
    else
      FULL_PATH="$CWD/$TARGET"
    fi

    # Normalize path
    FULL_PATH=$(realpath -m "$FULL_PATH" 2>/dev/null || echo "$FULL_PATH")

    # Check if creating/moving/copying directly under workarea root
    # Pattern: workarea root + one level (not deeper)
    if [[ "$FULL_PATH" =~ ^$WORKAREA_ROOT/[^/]+/?$ ]]; then
      # Extract the directory name at root level
      ROOT_DIR=$(basename "$FULL_PATH")

      # Only workspaces and repos are allowed at root
      if [[ "$ROOT_DIR" != "workspaces" ]] && [[ "$ROOT_DIR" != "repos" ]]; then
        cat >&2 <<EOF
🛑 Directory Structure Check: Invalid directory at workarea root!

You're trying to create/modify a directory at workarea root:
  Command: $COMMAND
  Target: $FULL_PATH

Workarea root ONLY allows these directories:
  ✅ workspaces/  - Container for workspace repositories
  ✅ repos/       - Shared git repository clones

  ❌ $ROOT_DIR/    - Not allowed at root level

The workarea root is for infrastructure only. User work belongs in:
  - workspaces/<name>/tasks/<task>/  (for task metadata)
  - workspaces/<name>/tasks/<task>/<repo>/  (for code, as worktrees)

To fix: Use /new-workspace to create workspaces, or work within existing ones.
EOF
        exit 2  # Block the operation
      fi
    fi
  done <<< "$TARGETS"
fi

# === VALIDATE GIT INIT LOCATION ===
# git init should only happen in repos/ or workspaces/<name>/, never in tasks

if echo "$COMMAND" | grep -qE '^git init'; then
  # Allowed locations for git init:
  # 1. repos/<repo>/ subdirectories (NOT repos/ itself - it's a container)
  # 2. workspaces/<name>/ directory (workspace root only, NOT workspaces/ itself)

  # Check if in repos/ subdirectory (but NOT the repos/ container itself)
  if [[ "$CWD" =~ ^$WORKAREA_ROOT/repos/[^/]+(/.*)?$ ]]; then
    exit 0  # Allow git init in repos/<repo>/ subdirectories
  fi

  # Check if at repos/ container itself (block it)
  if [[ "$CWD" == "$WORKAREA_ROOT/repos" ]]; then
    cat >&2 <<EOF
🛑 Directory Structure Check: git init not allowed in repos/ container!

You're trying to initialize a git repository in the repos/ container:
  Directory: $CWD
  Command: $COMMAND

The repos/ directory is just a container for repository clones.

Allowed locations for git init:
  ✅ repos/<repo>/       - Inside a specific repository directory
  ✅ workspaces/<name>/  - For workspace metadata tracking

  ❌ repos/              - Container directory (not a repository)

To initialize a repository:
  1. Create repository directory: mkdir repos/<repo>
  2. Navigate into it: cd repos/<repo>
  3. Initialize: git init
EOF
    exit 2  # Block git init at repos/ container
  fi

  # Check if in workspace root directory (not in tasks)
  if [[ "$CWD" =~ ^$WORKAREA_ROOT/workspaces/[^/]+/?$ ]]; then
    exit 0  # Allow git init in workspace root for metadata tracking
  fi

  # Check if we're in tasks directory or deeper
  if [[ "$CWD" =~ /tasks(/|$) ]]; then
    cat >&2 <<EOF
🛑 Directory Structure Check: git init not allowed in task directories!

You're trying to initialize a git repository inside a task directory:
  Directory: $CWD
  Command: $COMMAND

Task directories should ONLY use git worktrees, never initialize repos.

Allowed locations for git init:
  ✅ repos/              - For main repository clones
  ✅ repos/<repo>/       - Inside a repository
  ✅ workspaces/<name>/  - For workspace metadata tracking

  ❌ workspaces/<name>/tasks/               - Tasks container
  ❌ workspaces/<name>/tasks/<task>/        - Task root
  ❌ workspaces/<name>/tasks/<task>/<repo>/ - Worktree location

To work in a repository:
  1. Clone to repos/: git clone <url> repos/<repo>
  2. Use /resume-task to create worktrees in task directories

Worktrees link to repos/ and should be created with:
  git worktree add <path> <branch>
EOF
    exit 2  # Block git init in tasks
  fi

  # Check if at workarea root
  if [[ "$CWD" == "$WORKAREA_ROOT" ]]; then
    cat >&2 <<EOF
🛑 Directory Structure Check: git init not allowed at workarea root!

You're trying to initialize a git repository at the workarea root:
  Directory: $CWD
  Command: $COMMAND

The workarea root is already a git repository for tooling.

Allowed locations for git init:
  ✅ repos/<repo>/       - For repository clones
  ✅ workspaces/<name>/  - For workspace metadata

To fix:
  - Navigate to repos/ or a workspace directory first
EOF
    exit 2  # Block git init at workarea root
  fi
fi

# === VALIDATE WORKSPACE GIT OPERATIONS ===
# Ensure workspaces contain .git directories (are valid git repos)

if echo "$COMMAND" | grep -qE '^git (init|clone|add|commit)'; then
  # Check if we're in a workspace directory (not in a task worktree)
  if [[ "$CWD" =~ ^$WORKAREA_ROOT/workspaces/[^/]+/?$ ]]; then
    # We're at workspace root - this is where workspace repo lives
    # Check if .git exists (after init/clone it should)

    # For git init or git clone, allow it (will create .git)
    # (git init already validated above, this is for clone)
    if echo "$COMMAND" | grep -qE '^git (init|clone)'; then
      exit 0  # Allow init/clone in workspace directories
    fi

    # For git add/commit, verify .git exists
    if [[ ! -d "$CWD/.git" ]]; then
      cat >&2 <<EOF
🛑 Directory Structure Check: Workspace is not a git repository!

You're trying to run git commands in a workspace that's not initialized:
  Workspace: $CWD
  Command: $COMMAND

Workspaces MUST be git repositories to track task metadata.

To fix:
  1. Initialize workspace: git init && git remote add origin <your-workspace-repo-url>
  2. Or use /clone-workspace to clone an existing workspace

Workspace repos track:
  - tasks/*/task.json     (task configuration)
  - tasks/*/TASK_STATUS.md (progress notes)
EOF
      exit 2  # Block git operations in uninitialized workspace
    fi
  fi

  # Check if we're in the workspaces container itself (not a specific workspace)
  if [[ "$CWD" == "$WORKAREA_ROOT/workspaces" ]]; then
    cat >&2 <<EOF
🛑 Directory Structure Check: Git operation in workspaces container!

You're trying to run git commands in the workspaces/ container:
  Directory: $CWD
  Command: $COMMAND

The workspaces/ directory is just a container. Git operations should happen:
  ✅ In specific workspaces: workspaces/<name>/
  ❌ Not in the container: workspaces/

To fix:
  1. Navigate to a specific workspace: cd workspaces/<name>
  2. Or create a new workspace: /new-workspace <name>
EOF
    exit 2  # Block git operations in container
  fi
fi

# All checks passed
exit 0
