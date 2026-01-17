#!/bin/bash

# Script to resume/restore a task from its task.json configuration
# Usage: resume-task.sh <task-name> [workspace-path]
#
# Can be run from anywhere if workspace-path is provided.
# Otherwise, must be run from within a workspace (workspaces/<name>/).
# Repos are shared at workarea root.

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
    # This handles the case where workspace/bin -> ../../bin
    if [ -L "$script_dir" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS: resolve the symlink manually
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
# Returns workspace path if in a workspace, empty string if not
detect_current_workspace() {
    local workarea_root="$1"
    local cwd="$(pwd)"
    local workspaces_dir="$workarea_root/workspaces"

    # Check if we're inside workspaces/
    if [[ "$cwd" == "$workspaces_dir/"* ]]; then
        # Extract workspace name (first component after workspaces/)
        local rel_path="${cwd#$workspaces_dir/}"
        local workspace_name="${rel_path%%/*}"

        if [ -d "$workspaces_dir/$workspace_name" ]; then
            echo "$workspaces_dir/$workspace_name"
            return 0
        fi
    fi

    # Legacy support: check if we're in old tasks/ structure (at root)
    if [ -d "$workarea_root/tasks" ] && [[ "$cwd" == "$workarea_root/tasks"* || "$cwd" == "$workarea_root" ]]; then
        # Return workarea root as pseudo-workspace for legacy mode
        echo "$workarea_root"
        return 0
    fi

    return 1
}

# =============================================================================
# Configuration
# =============================================================================

WORKAREA_ROOT="$(resolve_workarea_root)"
REPOS_DIR="${WORKAREA_ROOT}/repos"  # Always shared at workarea root
WORKSPACES_DIR="${WORKAREA_ROOT}/workspaces"

# Detect workspace context
WORKSPACE_DIR=""
TASKS_DIR=""

if WORKSPACE_DIR=$(detect_current_workspace "$WORKAREA_ROOT"); then
    if [ "$WORKSPACE_DIR" = "$WORKAREA_ROOT" ]; then
        # Legacy mode - tasks at root level
        TASKS_DIR="${WORKAREA_ROOT}/tasks"
    else
        TASKS_DIR="${WORKSPACE_DIR}/tasks"
    fi
else
    # Not in a workspace - show error
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
    echo "Usage: $0 <task-name> [workspace-path]"
    echo ""
    echo "Restores a task workspace from its task.json configuration."
    echo ""
    echo "Arguments:"
    echo "  task-name       Name of the task to resume"
    echo "  workspace-path  (Optional) Path to the workspace directory"
    echo "                  If not provided, detects from current directory"
    echo ""
    echo "Examples:"
    echo "  $0 async-await"
    echo "  $0 async-await /path/to/workspaces/issues"
    echo "  $0 temporal-airflow workspaces/projects"
    echo ""
    echo "Note: This reads tasks/<task-name>/task.json to set up repositories and worktrees."
    exit 1
}

# Parse arguments
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    usage
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

TASK_NAME="$1"

# Handle optional workspace path argument
if [ $# -eq 2 ]; then
    # Workspace path provided explicitly
    EXPLICIT_WORKSPACE="$2"

    # Convert relative to absolute if needed
    if [[ "$EXPLICIT_WORKSPACE" != /* ]]; then
        EXPLICIT_WORKSPACE="${WORKAREA_ROOT}/${EXPLICIT_WORKSPACE}"
    fi

    if [ -d "$EXPLICIT_WORKSPACE" ]; then
        WORKSPACE_DIR="$EXPLICIT_WORKSPACE"
        TASKS_DIR="${WORKSPACE_DIR}/tasks"
    else
        echo -e "${RED}Error: Workspace directory does not exist: ${EXPLICIT_WORKSPACE}${NC}"
        exit 1
    fi
fi

TASK_DIR="${TASKS_DIR}/${TASK_NAME}"
CONFIG_FILE="${TASK_DIR}/task.json"

# Check if task directory exists
if [ ! -d "$TASK_DIR" ]; then
    echo -e "${RED}Error: Task directory does not exist: ${TASK_DIR}${NC}"
    echo "Available tasks:"
    ls -1 "$TASKS_DIR" 2>/dev/null || echo "  (none)"
    exit 1
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Task configuration not found: ${CONFIG_FILE}${NC}"
    exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: 'jq' is required but not installed${NC}"
    echo "Install with: brew install jq"
    exit 1
fi

echo -e "${GREEN}Resuming task: ${TASK_NAME}${NC}"
echo ""

# Parse task configuration
TASK_CONFIG=$(cat "$CONFIG_FILE")
REPO_COUNT=$(echo "$TASK_CONFIG" | jq -r '.repositories | length')

echo "Task configuration loaded:"
echo "  Description: $(echo "$TASK_CONFIG" | jq -r '.description // "N/A"')"
echo "  Created: $(echo "$TASK_CONFIG" | jq -r '.created // "N/A"')"
echo "  PR URL: $(echo "$TASK_CONFIG" | jq -r '.pr_url // "N/A"')"
echo "  Repositories: $REPO_COUNT"
echo ""

# Create base directories
mkdir -p "$REPOS_DIR"

# Process each repository
for ((i=0; i<$REPO_COUNT; i++)); do
    REPO_NAME=$(echo "$TASK_CONFIG" | jq -r ".repositories[$i].name")
    UPSTREAM_URL=$(echo "$TASK_CONFIG" | jq -r ".repositories[$i].upstream_url")
    FORK_URL=$(echo "$TASK_CONFIG" | jq -r ".repositories[$i].fork_url")
    BRANCH=$(echo "$TASK_CONFIG" | jq -r ".repositories[$i].branch")
    FORK_OWNER=$(echo "$TASK_CONFIG" | jq -r ".repositories[$i].fork_owner")
    TRACKING_REMOTE=$(echo "$TASK_CONFIG" | jq -r ".repositories[$i].tracking_remote")
    TRACKING_BRANCH=$(echo "$TASK_CONFIG" | jq -r ".repositories[$i].tracking_branch")

    REPO_PATH="${REPOS_DIR}/${REPO_NAME}"
    WORKTREE_PATH="${TASK_DIR}/${REPO_NAME}"

    echo -e "${GREEN}Processing repository: ${REPO_NAME}${NC}"

    # Clone repository if it doesn't exist
    if [ ! -d "$REPO_PATH" ]; then
        echo -e "${YELLOW}  Cloning ${UPSTREAM_URL}...${NC}"
        git clone "$UPSTREAM_URL" "$REPO_PATH"
    else
        echo "  Repository already exists: ${REPO_PATH}"
    fi

    # Navigate to repo
    cd "$REPO_PATH"

    # Fetch latest from upstream
    echo "  Fetching from upstream..."
    git fetch origin

    # Add fork remote if specified and doesn't exist
    if [ "$FORK_URL" != "null" ] && [ -n "$FORK_URL" ]; then
        if ! git remote | grep -q "^${FORK_OWNER}$"; then
            echo -e "${YELLOW}  Adding fork remote: ${FORK_OWNER}${NC}"
            git remote add "$FORK_OWNER" "$FORK_URL"
        fi

        # Fetch from fork
        echo "  Fetching from fork: ${FORK_OWNER}..."
        git fetch "$FORK_OWNER"
    fi

    # Create worktree if it doesn't exist
    if [ -d "$WORKTREE_PATH" ]; then
        echo -e "${YELLOW}  Worktree already exists: ${WORKTREE_PATH}${NC}"

        # Update the worktree to latest
        (
            cd "$WORKTREE_PATH"
            echo "  Pulling latest changes..."
            git pull 2>/dev/null || echo "  (No changes to pull)"
        )
    else
        echo "  Creating worktree at ${WORKTREE_PATH}..."

        # Determine the correct branch reference
        if [ "$TRACKING_REMOTE" != "null" ] && [ -n "$TRACKING_REMOTE" ]; then
            BRANCH_REF="${TRACKING_REMOTE}/${TRACKING_BRANCH}"
        else
            BRANCH_REF="$BRANCH"
        fi

        # Create worktree
        if ! git worktree add "$WORKTREE_PATH" -b "$BRANCH" "$BRANCH_REF" 2>/dev/null; then
            # Branch might already exist, try without -b
            if ! git worktree add "$WORKTREE_PATH" "$BRANCH" 2>/dev/null; then
                echo -e "${RED}  Failed to create worktree${NC}"
                continue
            fi
        fi

        # Set up tracking branch if fork is involved
        if [ "$TRACKING_REMOTE" != "null" ] && [ -n "$TRACKING_REMOTE" ]; then
            (
                cd "$WORKTREE_PATH"
                echo "  Setting up tracking branch: ${TRACKING_REMOTE}/${TRACKING_BRANCH}"
                git branch --set-upstream-to="${TRACKING_REMOTE}/${TRACKING_BRANCH}" "$BRANCH" 2>/dev/null || true
            )
        fi

        echo -e "${GREEN}  ✓ Worktree created${NC}"
    fi

    echo ""
done

# Return to workarea directory
cd "$WORKSPACE_DIR"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Task restored successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Task directory: ${TASK_DIR}"
echo ""
echo "Worktrees:"
for ((i=0; i<$REPO_COUNT; i++)); do
    REPO_NAME=$(echo "$TASK_CONFIG" | jq -r ".repositories[$i].name")
    echo "  - ${TASK_DIR}/${REPO_NAME}"
done
echo ""
echo "To start working:"
echo "  cd ${TASK_DIR}"
echo ""
echo "Review task status:"
echo "  cat ${TASK_DIR}/TASK_STATUS.md"
