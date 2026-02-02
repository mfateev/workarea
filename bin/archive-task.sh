#!/bin/bash

# Script to archive a completed task
# Usage: archive-task.sh <task-name> [workspace-path]
#
# This script:
# 1. Removes git worktrees from the task folder
# 2. Moves the task folder to archived/
# 3. Updates archived/README.md with task entry
#
# Must be run from within a workspace (workspaces/<name>/).

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Helper Functions
# =============================================================================

# Resolve the true workarea root (handles symlinks)
resolve_workarea_root() {
    local script_path="${BASH_SOURCE[0]}"
    local script_dir="$(dirname "$script_path")"

    # Check if the bin directory itself is a symlink (e.g., when called from workspace)
    if [ -L "$script_dir" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            local link_dir="$(cd "$(dirname "$script_dir")" && pwd)"
            local link_target="$(readlink "$script_dir")"
            if [[ "$link_target" == /* ]]; then
                script_dir="$link_target"
            else
                script_dir="$link_dir/$link_target"
            fi
        else
            script_dir="$(readlink -f "$script_dir")"
        fi
    fi

    # If the script file itself is a symlink, resolve it
    if [ -L "$script_path" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            local link_dir="$(cd "$(dirname "$script_path")" && pwd)"
            local link_target="$(readlink "$script_path")"
            if [[ "$link_target" == /* ]]; then
                script_path="$link_target"
            else
                script_path="$link_dir/$link_target"
            fi
            script_dir="$(dirname "$script_path")"
        else
            script_path="$(readlink -f "$script_path")"
            script_dir="$(dirname "$script_path")"
        fi
    fi

    # Resolve to absolute path
    script_dir="$(cd "$script_dir" && pwd -P)"
    dirname "$script_dir"
}

# Detect current workspace from cwd
detect_current_workspace() {
    local workarea_root="$1"
    local cwd="$(pwd)"
    local workspaces_dir="$workarea_root/workspaces"

    # Check if we're inside workspaces/
    if [[ "$cwd" == "$workspaces_dir/"* ]]; then
        local rel_path="${cwd#$workspaces_dir/}"
        local workspace_name="${rel_path%%/*}"

        if [ -d "$workspaces_dir/$workspace_name" ]; then
            echo "$workspaces_dir/$workspace_name"
            return 0
        fi
    fi

    return 1
}

# =============================================================================
# Configuration
# =============================================================================

WORKAREA_ROOT="$(resolve_workarea_root)"
REPOS_DIR="${WORKAREA_ROOT}/repos"
WORKSPACES_DIR="${WORKAREA_ROOT}/workspaces"

# Detect workspace context
WORKSPACE_DIR=""
TASKS_DIR=""
ARCHIVED_DIR=""

if WORKSPACE_DIR=$(detect_current_workspace "$WORKAREA_ROOT"); then
    TASKS_DIR="${WORKSPACE_DIR}/tasks"
    ARCHIVED_DIR="${WORKSPACE_DIR}/archived"
else
    echo -e "${RED}Error: Not in a workspace.${NC}"
    echo ""
    echo "This script must be run from within a workspace."
    echo ""
    echo "Navigate to a workspace first:"
    echo -e "  ${BLUE}cd workspaces/<workspace-name>${NC}"
    echo ""
    if [ -d "$WORKSPACES_DIR" ]; then
        echo "Available workspaces:"
        for ws in "$WORKSPACES_DIR"/*/; do
            [ -d "$ws" ] && echo "  - $(basename "$ws")"
        done
    fi
    exit 1
fi

# Print usage
usage() {
    echo "Usage: $0 [--force] <task-name> [workspace-path]"
    echo ""
    echo "Archives a completed task by:"
    echo "  1. Checking for uncommitted/unpushed changes"
    echo "  2. Removing git worktrees from the task"
    echo "  3. Moving the task folder to archived/"
    echo "  4. Updating archived/README.md"
    echo ""
    echo "Options:"
    echo "  --force         Skip checks for uncommitted/unpushed changes"
    echo ""
    echo "Arguments:"
    echo "  task-name       Name of the task to archive"
    echo "  workspace-path  (Optional) Path to the workspace directory"
    echo ""
    echo "Examples:"
    echo "  $0 async-await"
    echo "  $0 async-await workspaces/issues"
    echo "  $0 --force async-await"
    echo ""
    exit 1
}

# Parse arguments
FORCE_MODE=false

# Check for --force flag
if [ "$1" = "--force" ]; then
    FORCE_MODE=true
    shift
fi

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    usage
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

TASK_NAME="$1"

# Handle optional workspace path argument
if [ $# -eq 2 ]; then
    EXPLICIT_WORKSPACE="$2"

    if [[ "$EXPLICIT_WORKSPACE" != /* ]]; then
        EXPLICIT_WORKSPACE="${WORKAREA_ROOT}/${EXPLICIT_WORKSPACE}"
    fi

    if [ -d "$EXPLICIT_WORKSPACE" ]; then
        WORKSPACE_DIR="$EXPLICIT_WORKSPACE"
        TASKS_DIR="${WORKSPACE_DIR}/tasks"
        ARCHIVED_DIR="${WORKSPACE_DIR}/archived"
    else
        echo -e "${RED}Error: Workspace directory does not exist: ${EXPLICIT_WORKSPACE}${NC}"
        exit 1
    fi
fi

TASK_DIR="${TASKS_DIR}/${TASK_NAME}"

# Check if task directory exists
if [ ! -d "$TASK_DIR" ]; then
    echo -e "${RED}Error: Task directory does not exist: ${TASK_DIR}${NC}"
    echo ""
    echo "Available tasks:"
    ls -1 "$TASKS_DIR" 2>/dev/null || echo "  (none)"
    exit 1
fi

# Check if already archived
if [ -d "${ARCHIVED_DIR}/${TASK_NAME}" ]; then
    echo -e "${RED}Error: Task '${TASK_NAME}' is already archived.${NC}"
    exit 1
fi

echo -e "${GREEN}Archiving task: ${TASK_NAME}${NC}"
echo ""

# =============================================================================
# Step 1: Check for uncommitted/unpushed changes
# =============================================================================

echo -e "${BLUE}Step 1: Checking worktrees for uncommitted/unpushed changes...${NC}"

HAS_ISSUES=false
WORKTREE_ISSUES=""

for item in "$TASK_DIR"/*/; do
    if [ -d "$item" ]; then
        item_name=$(basename "$item")

        # Check if this is a git worktree
        if [ -f "$item/.git" ]; then
            (
                cd "$item"

                # Check for uncommitted changes
                UNCOMMITTED=$(git status --porcelain 2>/dev/null)
                if [ -n "$UNCOMMITTED" ]; then
                    echo -e "  ${YELLOW}⚠ ${item_name}: Has uncommitted changes${NC}"
                    echo "    $(echo "$UNCOMMITTED" | head -3)"
                    if [ $(echo "$UNCOMMITTED" | wc -l) -gt 3 ]; then
                        echo "    ... and more"
                    fi
                    exit 1
                fi

                # Check for unpushed commits
                # First check if we have an upstream configured
                UPSTREAM=$(git rev-parse --abbrev-ref @{u} 2>/dev/null) || true
                if [ -n "$UPSTREAM" ]; then
                    UNPUSHED=$(git log @{u}..HEAD --oneline 2>/dev/null)
                    if [ -n "$UNPUSHED" ]; then
                        echo -e "  ${YELLOW}⚠ ${item_name}: Has unpushed commits${NC}"
                        echo "    $(echo "$UNPUSHED" | head -3)"
                        if [ $(echo "$UNPUSHED" | wc -l) -gt 3 ]; then
                            echo "    ... and more"
                        fi
                        exit 2
                    fi
                else
                    # No upstream, check if there are any local commits not on any remote
                    # Get current branch
                    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
                    if [ -n "$CURRENT_BRANCH" ]; then
                        # Check all remotes for this branch
                        FOUND_ON_REMOTE=false
                        for remote in $(git remote 2>/dev/null); do
                            if git rev-parse --verify "${remote}/${CURRENT_BRANCH}" &>/dev/null; then
                                UNPUSHED=$(git log "${remote}/${CURRENT_BRANCH}..HEAD" --oneline 2>/dev/null)
                                if [ -z "$UNPUSHED" ]; then
                                    FOUND_ON_REMOTE=true
                                    break
                                fi
                            fi
                        done
                        if [ "$FOUND_ON_REMOTE" = false ]; then
                            # Check if there are any commits at all
                            COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo "0")
                            if [ "$COMMIT_COUNT" -gt 0 ]; then
                                echo -e "  ${YELLOW}⚠ ${item_name}: Branch '${CURRENT_BRANCH}' may have unpushed commits (no upstream configured)${NC}"
                                exit 2
                            fi
                        fi
                    fi
                fi

                echo -e "  ${GREEN}✓ ${item_name}: Clean${NC}"
            ) || {
                EXIT_CODE=$?
                HAS_ISSUES=true
                if [ $EXIT_CODE -eq 1 ]; then
                    WORKTREE_ISSUES="${WORKTREE_ISSUES}uncommitted:${item_name} "
                elif [ $EXIT_CODE -eq 2 ]; then
                    WORKTREE_ISSUES="${WORKTREE_ISSUES}unpushed:${item_name} "
                fi
            }
        fi
    fi
done

if [ "$HAS_ISSUES" = true ]; then
    echo ""
    if [ "$FORCE_MODE" = true ]; then
        echo -e "${YELLOW}Warning: Proceeding despite issues (--force mode)${NC}"
    else
        echo -e "${RED}Error: Cannot archive task with uncommitted or unpushed changes.${NC}"
        echo ""
        echo "Options:"
        echo "  1. Commit and push your changes first"
        echo "  2. Run with --force to archive anyway (changes will be lost!)"
        echo ""
        echo "To push changes:"
        for issue in $WORKTREE_ISSUES; do
            issue_type="${issue%%:*}"
            issue_repo="${issue##*:}"
            echo "  cd ${TASK_DIR}/${issue_repo}"
            if [ "$issue_type" = "uncommitted" ]; then
                echo "  git add . && git commit -m 'WIP' && git push"
            else
                echo "  git push"
            fi
        done
        echo ""
        exit 1
    fi
else
    echo -e "${GREEN}  All worktrees are clean${NC}"
fi
echo ""

# =============================================================================
# Step 2: Remove git worktrees
# =============================================================================

echo -e "${BLUE}Step 2: Removing git worktrees...${NC}"

# Find all directories in task that might be worktrees
WORKTREES_REMOVED=0
for item in "$TASK_DIR"/*/; do
    if [ -d "$item" ]; then
        item_name=$(basename "$item")

        # Check if this is a git worktree
        if [ -f "$item/.git" ]; then
            echo "  Removing worktree: ${item_name}"

            # Find the parent repository in repos/
            REPO_PATH="${REPOS_DIR}/${item_name}"

            if [ -d "$REPO_PATH" ]; then
                # Remove the worktree properly
                (cd "$REPO_PATH" && git worktree remove "$item" --force 2>/dev/null) || {
                    # If that fails, try removing manually
                    echo -e "${YELLOW}    Warning: Could not remove worktree cleanly, removing directory...${NC}"
                    rm -rf "$item"
                    # Prune worktree references
                    (cd "$REPO_PATH" && git worktree prune 2>/dev/null) || true
                }
                WORKTREES_REMOVED=$((WORKTREES_REMOVED + 1))
            else
                # Repository not found, just remove the directory
                echo -e "${YELLOW}    Warning: Repository not found at ${REPO_PATH}, removing directory...${NC}"
                rm -rf "$item"
            fi
        fi
    fi
done

if [ $WORKTREES_REMOVED -eq 0 ]; then
    echo "  No worktrees found to remove"
else
    echo -e "${GREEN}  ✓ Removed ${WORKTREES_REMOVED} worktree(s)${NC}"
fi
echo ""

# =============================================================================
# Step 3: Ensure archived directory exists
# =============================================================================

echo -e "${BLUE}Step 3: Preparing archive directory...${NC}"
mkdir -p "$ARCHIVED_DIR"
echo "  Archive directory: ${ARCHIVED_DIR}"
echo ""

# =============================================================================
# Step 4: Move task to archived
# =============================================================================

echo -e "${BLUE}Step 4: Moving task to archived...${NC}"
mv "$TASK_DIR" "${ARCHIVED_DIR}/${TASK_NAME}"
echo -e "${GREEN}  ✓ Moved to: ${ARCHIVED_DIR}/${TASK_NAME}${NC}"
echo ""

# =============================================================================
# Step 5: Update archived/README.md
# =============================================================================

echo -e "${BLUE}Step 5: Updating archived/README.md...${NC}"

README_PATH="${ARCHIVED_DIR}/README.md"
ARCHIVE_DATE=$(date +"%Y-%m-%d")

# Extract info from task.json if it exists
TASK_JSON="${ARCHIVED_DIR}/${TASK_NAME}/task.json"
PR_URL="N/A"
DESCRIPTION=""

if [ -f "$TASK_JSON" ] && command -v jq &> /dev/null; then
    PR_URL=$(jq -r '.pr_url // "N/A"' "$TASK_JSON")
    DESCRIPTION=$(jq -r '.description // ""' "$TASK_JSON")
fi

# Create README if it doesn't exist
if [ ! -f "$README_PATH" ]; then
    cat > "$README_PATH" << 'HEADER'
# Archived Tasks

Completed tasks that have been archived.

| Task | PR | Archived | Description |
|------|----|----|-------------|
HEADER
fi

# Add entry to the table
# Insert after the header row (line 6)
ENTRY="| ${TASK_NAME} | ${PR_URL} | ${ARCHIVE_DATE} | ${DESCRIPTION} |"

# Check if the task is already in the README
if grep -q "| ${TASK_NAME} |" "$README_PATH" 2>/dev/null; then
    echo -e "${YELLOW}  Task already listed in README.md${NC}"
else
    # Append to the table
    echo "$ENTRY" >> "$README_PATH"
    echo -e "${GREEN}  ✓ Added entry to README.md${NC}"
fi
echo ""

# =============================================================================
# Summary
# =============================================================================

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Task archived successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Archived to: ${ARCHIVED_DIR}/${TASK_NAME}"
echo ""
echo "Files preserved:"
echo "  - task.json (configuration)"
echo "  - TASK_STATUS.md (notes)"
echo ""
echo "To view archived task:"
echo "  cat ${ARCHIVED_DIR}/${TASK_NAME}/TASK_STATUS.md"
echo ""
echo "To restore (if needed):"
echo "  mv ${ARCHIVED_DIR}/${TASK_NAME} ${TASKS_DIR}/"
echo "  /resume-task ${TASK_NAME}"
echo ""
