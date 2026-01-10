#!/bin/bash

# Script to safely detach (remove) a workspace after ensuring all progress is saved
# Usage: detach-workspace.sh [workspace-name]
#
# If no workspace name is provided, uses current workspace (must be inside one)
#
# This script:
# 1. Checks for uncommitted changes in workspace repo
# 2. Checks for unpushed commits
# 3. Removes git worktrees cleanly
# 4. Deletes the workspace directory

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

    script_dir="$(cd "$script_dir" && pwd -P)"
    dirname "$script_dir"
}

# Detect current workspace from cwd
detect_current_workspace() {
    local workarea_root="$1"
    local cwd="$(pwd)"
    local workspaces_dir="$workarea_root/workspaces"

    if [[ "$cwd" == "$workspaces_dir/"* ]]; then
        local rel_path="${cwd#$workspaces_dir/}"
        local workspace_name="${rel_path%%/*}"

        if [ -d "$workspaces_dir/$workspace_name" ]; then
            echo "$workspace_name"
            return 0
        fi
    fi

    return 1
}

# =============================================================================
# Configuration
# =============================================================================

WORKAREA_ROOT="$(resolve_workarea_root)"
WORKSPACES_DIR="${WORKAREA_ROOT}/workspaces"
REPOS_DIR="${WORKAREA_ROOT}/repos"

# =============================================================================
# Main Script
# =============================================================================

usage() {
    echo "Usage: $0 [workspace-name]"
    echo ""
    echo "Safely detach (remove) a workspace after ensuring all progress is saved."
    echo ""
    echo "If no workspace name is provided, uses current workspace."
    echo ""
    echo "This command:"
    echo "  1. Checks for uncommitted changes in workspace"
    echo "  2. Checks for unpushed commits"
    echo "  3. Removes git worktrees cleanly"
    echo "  4. Deletes the workspace directory"
    echo ""
    echo "Options:"
    echo "  -f, --force    Skip confirmation prompt"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 issues          # Detach 'issues' workspace"
    echo "  $0                 # Detach current workspace"
    echo "  $0 -f issues       # Force detach without confirmation"
    exit 1
}

# Parse arguments
FORCE=false
WORKSPACE_NAME=""

while [ $# -gt 0 ]; do
    case "$1" in
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [ -z "$WORKSPACE_NAME" ]; then
                WORKSPACE_NAME="$1"
            fi
            shift
            ;;
    esac
done

# If no workspace specified, try to detect from cwd
if [ -z "$WORKSPACE_NAME" ]; then
    if WORKSPACE_NAME=$(detect_current_workspace "$WORKAREA_ROOT"); then
        echo -e "${BLUE}Detected workspace: ${WORKSPACE_NAME}${NC}"
    else
        echo -e "${RED}Error: Not in a workspace and no workspace name provided.${NC}"
        echo ""
        echo "Available workspaces:"
        for ws in "$WORKSPACES_DIR"/*/; do
            [ -d "$ws" ] && echo "  - $(basename "$ws")"
        done
        exit 1
    fi
fi

WORKSPACE_PATH="${WORKSPACES_DIR}/${WORKSPACE_NAME}"

# Verify workspace exists
if [ ! -d "$WORKSPACE_PATH" ]; then
    echo -e "${RED}Error: Workspace not found: ${WORKSPACE_PATH}${NC}"
    echo ""
    echo "Available workspaces:"
    for ws in "$WORKSPACES_DIR"/*/; do
        [ -d "$ws" ] && echo "  - $(basename "$ws")"
    done
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Detaching workspace: ${WORKSPACE_NAME}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# =============================================================================
# Step 1: Check workspace git status
# =============================================================================

echo -e "${BLUE}Checking workspace git status...${NC}"

cd "$WORKSPACE_PATH"

# Check if it's a git repo
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}Warning: Workspace is not a git repository${NC}"
    echo "  Changes will NOT be preserved after deletion!"
    echo ""
    if [ "$FORCE" != true ]; then
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 1
        fi
    fi
else
    # Check for uncommitted changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo -e "${RED}Error: Uncommitted changes detected!${NC}"
        echo ""
        echo "Changed files:"
        git status --short
        echo ""
        echo "Please commit or stash changes first:"
        echo "  cd ${WORKSPACE_PATH}"
        echo "  git add -A && git commit -m 'Save progress'"
        echo "  git push"
        exit 1
    fi

    # Check for untracked files (excluding worktrees)
    UNTRACKED=$(git status --porcelain | grep "^??" | grep -v "tasks/.*/.*/" || true)
    if [ -n "$UNTRACKED" ]; then
        echo -e "${YELLOW}Warning: Untracked files detected:${NC}"
        echo "$UNTRACKED"
        echo ""
        if [ "$FORCE" != true ]; then
            read -p "These files will be lost. Continue? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Aborted."
                exit 1
            fi
        fi
    fi

    # Check for unpushed commits
    REMOTE=$(git remote | head -1)
    if [ -n "$REMOTE" ]; then
        git fetch "$REMOTE" 2>/dev/null || true
        BRANCH=$(git rev-parse --abbrev-ref HEAD)

        UNPUSHED=$(git log "${REMOTE}/${BRANCH}..HEAD" --oneline 2>/dev/null || echo "")
        if [ -n "$UNPUSHED" ]; then
            echo -e "${RED}Error: Unpushed commits detected!${NC}"
            echo ""
            echo "Unpushed commits:"
            echo "$UNPUSHED"
            echo ""
            echo "Please push changes first:"
            echo "  cd ${WORKSPACE_PATH}"
            echo "  git push"
            exit 1
        fi
        echo -e "${GREEN}  ✓ All commits pushed to remote${NC}"
    else
        echo -e "${YELLOW}  Warning: No remote configured${NC}"
        if [ "$FORCE" != true ]; then
            read -p "Changes may not be backed up. Continue? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Aborted."
                exit 1
            fi
        fi
    fi

    echo -e "${GREEN}  ✓ No uncommitted changes${NC}"
fi

echo ""

# =============================================================================
# Step 2: Find and remove worktrees
# =============================================================================

echo -e "${BLUE}Checking for git worktrees...${NC}"

WORKTREES_REMOVED=0

# Find all task directories that might contain worktrees
if [ -d "${WORKSPACE_PATH}/tasks" ]; then
    for task_dir in "${WORKSPACE_PATH}/tasks"/*/; do
        [ ! -d "$task_dir" ] && continue
        task_name=$(basename "$task_dir")

        # Look for worktrees (directories with .git file, not .git directory)
        for repo_dir in "$task_dir"*/; do
            [ ! -d "$repo_dir" ] && continue

            # Check if it's a worktree (has .git file pointing to main repo)
            if [ -f "${repo_dir}.git" ]; then
                repo_name=$(basename "$repo_dir")
                echo "  Found worktree: tasks/${task_name}/${repo_name}"

                # Get the main repo path
                MAIN_REPO="${REPOS_DIR}/${repo_name}"

                if [ -d "$MAIN_REPO" ]; then
                    # Remove worktree properly
                    echo "    Removing from ${MAIN_REPO}..."
                    (cd "$MAIN_REPO" && git worktree remove "$repo_dir" --force 2>/dev/null) || {
                        echo -e "${YELLOW}    Warning: Could not remove worktree cleanly${NC}"
                        # Force remove if needed
                        rm -rf "$repo_dir"
                        (cd "$MAIN_REPO" && git worktree prune 2>/dev/null) || true
                    }
                    WORKTREES_REMOVED=$((WORKTREES_REMOVED + 1))
                else
                    echo -e "${YELLOW}    Warning: Main repo not found, removing directory${NC}"
                    rm -rf "$repo_dir"
                fi
            fi
        done
    done
fi

if [ $WORKTREES_REMOVED -gt 0 ]; then
    echo -e "${GREEN}  ✓ Removed ${WORKTREES_REMOVED} worktree(s)${NC}"
else
    echo "  No worktrees found"
fi

echo ""

# =============================================================================
# Step 3: Confirm and delete
# =============================================================================

echo -e "${BLUE}Ready to delete workspace${NC}"
echo ""
echo "Workspace: ${WORKSPACE_PATH}"
echo ""

if [ "$FORCE" != true ]; then
    read -p "Delete this workspace? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Go back to workarea root before deleting
cd "$WORKAREA_ROOT"

# Delete the workspace
rm -rf "$WORKSPACE_PATH"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Workspace detached successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "The workspace '${WORKSPACE_NAME}' has been removed."
echo ""
echo "To restore it later:"
echo -e "  ${BLUE}/clone-workspace workspace-${WORKSPACE_NAME}${NC}"
echo ""
echo "Remaining workspaces:"
for ws in "$WORKSPACES_DIR"/*/; do
    [ -d "$ws" ] && echo "  - $(basename "$ws")"
done
