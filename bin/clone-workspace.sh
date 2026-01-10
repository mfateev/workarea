#!/bin/bash

# Script to clone an existing workspace repository into workspaces/
# Usage: clone-workspace.sh <repo-url-or-name> [workspace-name]
#
# Examples:
#   clone-workspace.sh https://github.com/user/workspace-issues
#   clone-workspace.sh workspace-issues                    # Uses gh to find repo
#   clone-workspace.sh workspace-issues my-issues          # Custom local name

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

# Extract workspace name from URL or repo name
extract_workspace_name() {
    local input="$1"
    local name

    # Remove .git suffix if present
    name="${input%.git}"

    # Extract last component of URL path
    name="$(basename "$name")"

    # Remove common prefixes like "workspace-"
    name="${name#workspace-}"

    echo "$name"
}

# Resolve repo URL from shorthand name
resolve_repo_url() {
    local input="$1"

    # If already a URL, return as-is
    if [[ "$input" =~ ^https?:// ]] || [[ "$input" =~ ^git@ ]]; then
        echo "$input"
        return 0
    fi

    # Try to find repo using gh CLI
    if command -v gh &> /dev/null; then
        # First try exact name
        local repo_url
        repo_url=$(gh repo view "$input" --json url --jq '.url' 2>/dev/null)
        if [ -n "$repo_url" ]; then
            echo "$repo_url"
            return 0
        fi

        # Try with workspace- prefix
        repo_url=$(gh repo view "workspace-$input" --json url --jq '.url' 2>/dev/null)
        if [ -n "$repo_url" ]; then
            echo "$repo_url"
            return 0
        fi
    fi

    # Fallback: assume it's a GitHub repo name for current user
    echo "https://github.com/$(gh api user --jq '.login' 2>/dev/null || echo 'user')/$input.git"
}

# =============================================================================
# Configuration
# =============================================================================

WORKAREA_ROOT="$(resolve_workarea_root)"
WORKSPACES_DIR="${WORKAREA_ROOT}/workspaces"

# =============================================================================
# Main Script
# =============================================================================

# Print usage
usage() {
    echo "Usage: $0 <repo-url-or-name> [workspace-name]"
    echo ""
    echo "Clone an existing workspace repository into workspaces/"
    echo ""
    echo "Arguments:"
    echo "  repo-url-or-name   Git URL or repository name"
    echo "  workspace-name     Optional: local name for the workspace"
    echo ""
    echo "Examples:"
    echo "  $0 https://github.com/user/workspace-issues"
    echo "  $0 workspace-issues"
    echo "  $0 workspace-issues my-issues"
    echo ""
    echo "Options:"
    echo "  -h, --help         Show this help message"
    echo "  -r, --restore      Restore all tasks after cloning"
    exit 1
}

# Parse arguments
if [ $# -lt 1 ]; then
    usage
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

RESTORE_TASKS=false
REPO_INPUT=""
WORKSPACE_NAME=""

# Parse flags and positional arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -r|--restore)
            RESTORE_TASKS=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [ -z "$REPO_INPUT" ]; then
                REPO_INPUT="$1"
            elif [ -z "$WORKSPACE_NAME" ]; then
                WORKSPACE_NAME="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$REPO_INPUT" ]; then
    echo -e "${RED}Error: Repository URL or name is required${NC}"
    usage
fi

# Resolve the repository URL
echo -e "${BLUE}Resolving repository...${NC}"
REPO_URL=$(resolve_repo_url "$REPO_INPUT")
echo "  Repository: $REPO_URL"

# Determine workspace name
if [ -z "$WORKSPACE_NAME" ]; then
    WORKSPACE_NAME=$(extract_workspace_name "$REPO_URL")
fi

WORKSPACE_PATH="${WORKSPACES_DIR}/${WORKSPACE_NAME}"

echo "  Workspace name: $WORKSPACE_NAME"
echo "  Target path: $WORKSPACE_PATH"
echo ""

# Check if workspace already exists
if [ -d "$WORKSPACE_PATH" ]; then
    echo -e "${RED}Error: Workspace already exists: ${WORKSPACE_PATH}${NC}"
    echo ""
    echo "Options:"
    echo "  1. Remove existing: rm -rf ${WORKSPACE_PATH}"
    echo "  2. Use different name: $0 $REPO_INPUT <different-name>"
    echo "  3. Pull updates: cd ${WORKSPACE_PATH} && git pull"
    exit 1
fi

# Create workspaces directory if needed
mkdir -p "$WORKSPACES_DIR"

# Clone the repository
echo -e "${GREEN}Cloning workspace repository...${NC}"
if ! git clone "$REPO_URL" "$WORKSPACE_PATH"; then
    echo -e "${RED}Error: Failed to clone repository${NC}"
    exit 1
fi

echo -e "${GREEN}  ✓ Cloned successfully${NC}"
echo ""

# Verify workspace structure
echo -e "${BLUE}Verifying workspace structure...${NC}"

VALID_STRUCTURE=true

if [ ! -d "${WORKSPACE_PATH}/tasks" ]; then
    echo -e "${YELLOW}  Warning: tasks/ directory not found${NC}"
    mkdir -p "${WORKSPACE_PATH}/tasks"
    echo "  Created tasks/ directory"
fi

if [ ! -d "${WORKSPACE_PATH}/archived" ]; then
    echo -e "${YELLOW}  Warning: archived/ directory not found${NC}"
    mkdir -p "${WORKSPACE_PATH}/archived"
    echo "  Created archived/ directory"
fi

# Check/create bin symlink
if [ -L "${WORKSPACE_PATH}/bin" ]; then
    echo "  ✓ bin symlink exists"
elif [ -d "${WORKSPACE_PATH}/bin" ]; then
    echo -e "${YELLOW}  Warning: bin/ is a directory, not a symlink${NC}"
else
    echo "  Creating bin symlink..."
    ln -s "../../bin" "${WORKSPACE_PATH}/bin"
    echo "  ✓ Created bin -> ../../bin symlink"
fi

echo ""

# Count tasks
TASK_COUNT=0
if [ -d "${WORKSPACE_PATH}/tasks" ]; then
    shopt -s nullglob
    TASK_DIRS=("${WORKSPACE_PATH}/tasks"/*/)
    shopt -u nullglob
    TASK_COUNT=${#TASK_DIRS[@]}
fi

ARCHIVED_COUNT=0
if [ -d "${WORKSPACE_PATH}/archived" ]; then
    shopt -s nullglob
    ARCHIVED_DIRS=("${WORKSPACE_PATH}/archived"/*/)
    shopt -u nullglob
    ARCHIVED_COUNT=${#ARCHIVED_DIRS[@]}
fi

echo -e "${GREEN}Workspace cloned successfully!${NC}"
echo ""
echo "  Location: ${WORKSPACE_PATH}"
echo "  Tasks: ${TASK_COUNT}"
echo "  Archived: ${ARCHIVED_COUNT}"
echo ""

# List tasks
if [ $TASK_COUNT -gt 0 ]; then
    echo "Tasks:"
    for task_dir in "${TASK_DIRS[@]}"; do
        task_name=$(basename "$task_dir")
        if [ -f "${task_dir}/task.json" ] && command -v jq &> /dev/null; then
            description=$(jq -r '.description // "N/A"' "${task_dir}/task.json" 2>/dev/null | head -c 50)
            echo "  - ${task_name}: ${description}"
        else
            echo "  - ${task_name}"
        fi
    done
    echo ""
fi

# Restore tasks if requested
if [ "$RESTORE_TASKS" = true ] && [ $TASK_COUNT -gt 0 ]; then
    echo -e "${GREEN}Restoring tasks...${NC}"
    echo ""

    cd "$WORKSPACE_PATH"

    for task_dir in "${TASK_DIRS[@]}"; do
        task_name=$(basename "$task_dir")
        echo -e "${BLUE}Restoring: ${task_name}${NC}"

        if [ -f "${task_dir}/task.json" ]; then
            "${WORKAREA_ROOT}/bin/resume-task.sh" "$task_name" || {
                echo -e "${YELLOW}  Warning: Failed to restore ${task_name}${NC}"
            }
        else
            echo -e "${YELLOW}  Skipped: No task.json found${NC}"
        fi
        echo ""
    done
fi

# Print next steps
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Next steps:${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Navigate to workspace:"
echo -e "  ${BLUE}cd ${WORKSPACE_PATH}${NC}"
echo ""
echo "List tasks:"
echo -e "  ${BLUE}/workarea-tasks${NC}"
echo ""

if [ $TASK_COUNT -gt 0 ] && [ "$RESTORE_TASKS" != true ]; then
    echo "Restore a task (creates worktrees):"
    echo -e "  ${BLUE}/resume-task <task-name>${NC}"
    echo ""
    echo "Or restore all tasks:"
    echo -e "  ${BLUE}$0 --restore $REPO_INPUT${NC}"
fi
