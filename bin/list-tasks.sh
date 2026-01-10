#!/bin/bash

# List all tasks with their status
# Can be run standalone or called by /workarea-tasks command
#
# Behavior:
# - If run from within a workspace: lists tasks for that workspace
# - If run from workarea root or elsewhere: lists available workspaces

# Colors
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

    return 1
}

# =============================================================================
# Main Script
# =============================================================================

WORKAREA_ROOT="$(resolve_workarea_root)"
REPOS_DIR="${WORKAREA_ROOT}/repos"
WORKSPACES_DIR="${WORKAREA_ROOT}/workspaces"

# Try to detect workspace context
WORKSPACE_DIR=""
TASKS_DIR=""

if WORKSPACE_DIR=$(detect_current_workspace "$WORKAREA_ROOT"); then
    TASKS_DIR="${WORKSPACE_DIR}/tasks"
else
    # Not in a workspace - show available workspaces
    echo -e "${GREEN}=== Available Workspaces ===${NC}"
    echo ""

    if [ -d "$WORKSPACES_DIR" ]; then
        shopt -s nullglob
        WORKSPACE_DIRS=("$WORKSPACES_DIR"/*/)
        shopt -u nullglob

        if [ ${#WORKSPACE_DIRS[@]} -eq 0 ]; then
            echo -e "${YELLOW}No workspaces attached.${NC}"
            echo ""
            echo "Attach a workspace with tasks using:"
            echo -e "  ${BLUE}/clone-workspace <git-url>${NC}"
            echo ""
            echo "Or create a new empty workspace:"
            echo -e "  ${BLUE}/new-workspace <name>${NC}"
        else
            WS_NUM=0
            for ws_path in "${WORKSPACE_DIRS[@]}"; do
                ws_name=$(basename "$ws_path")
                WS_NUM=$((WS_NUM + 1))

                # Count tasks
                task_count=0
                if [ -d "$ws_path/tasks" ]; then
                    shopt -s nullglob
                    task_dirs=("$ws_path/tasks"/*/)
                    shopt -u nullglob
                    task_count=${#task_dirs[@]}
                fi

                # Get workspace description from README if available
                description=""
                if [ -f "$ws_path/README.md" ]; then
                    # Get first non-empty line after the title
                    description=$(grep -v "^#" "$ws_path/README.md" | grep -v "^$" | head -1 | cut -c1-50)
                fi

                echo -e "${BLUE}${WS_NUM}.${NC} ${ws_name}"
                echo "   ${task_count} task(s)"
                if [ -n "$description" ]; then
                    echo "   ${description}"
                fi
                echo ""
            done

            echo -e "${GREEN}Commands:${NC}"
            echo "  cd workspaces/<name>      - Navigate to a workspace"
            echo "  /new-workspace <name>     - Create a new workspace"
            echo ""
            echo -e "To see tasks: ${BLUE}cd workspaces/<name>${NC} then ${BLUE}/workarea-tasks${NC}"
        fi
    else
        echo -e "${YELLOW}No workspaces attached.${NC}"
        echo ""
        echo "Attach a workspace with tasks using:"
        echo -e "  ${BLUE}/clone-workspace <git-url>${NC}"
        echo ""
        echo "Or create a new empty workspace:"
        echo -e "  ${BLUE}/new-workspace <name>${NC}"
    fi
    exit 0
fi

# =============================================================================
# List Tasks (when in a workspace)
# =============================================================================

# Check if tasks directory exists
if [ ! -d "$TASKS_DIR" ]; then
    echo -e "${YELLOW}No tasks directory found in this workspace.${NC}"
    echo "Create your first task with: /new-task <description>"
    exit 0
fi

# Check if there are any tasks
shopt -s nullglob
TASK_DIRS=("$TASKS_DIR"/*)
shopt -u nullglob

if [ ${#TASK_DIRS[@]} -eq 0 ]; then
    WORKSPACE_NAME=$(basename "$WORKSPACE_DIR")
    echo -e "${YELLOW}No tasks found in workspace '${WORKSPACE_NAME}'.${NC}"
    echo ""
    echo "Start a new task:"
    echo "  /new-task <description or PR URL>"
    echo ""
    echo "Example:"
    echo "  /new-task https://github.com/org/repo/pull/123"
    exit 0
fi

# Show workspace context
WORKSPACE_NAME=$(basename "$WORKSPACE_DIR")
echo -e "${GREEN}=== Tasks in workspace: ${WORKSPACE_NAME} ===${NC}"
echo ""

# Counter for numbering
TASK_NUM=0

# Iterate through tasks
for TASK_PATH in "${TASK_DIRS[@]}"; do
    # Skip if not a directory
    [ ! -d "$TASK_PATH" ] && continue

    TASK_NAME=$(basename "$TASK_PATH")
    TASK_NUM=$((TASK_NUM + 1))

    CONFIG_FILE="${TASK_PATH}/task.json"
    STATUS_FILE="${TASK_PATH}/TASK_STATUS.md"

    # Get modification time of status file
    if [ -f "$STATUS_FILE" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            MOD_TIME=$(stat -f "%m" "$STATUS_FILE")
            MOD_DATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$STATUS_FILE")
        else
            MOD_TIME=$(stat -c "%Y" "$STATUS_FILE")
            MOD_DATE=$(stat -c "%y" "$STATUS_FILE" | cut -d'.' -f1)
        fi

        # Calculate relative time
        CURRENT_TIME=$(date +%s)
        TIME_DIFF=$((CURRENT_TIME - MOD_TIME))

        if [ $TIME_DIFF -lt 3600 ]; then
            MINUTES=$((TIME_DIFF / 60))
            RELATIVE_TIME="${MINUTES}m ago"
        elif [ $TIME_DIFF -lt 86400 ]; then
            HOURS=$((TIME_DIFF / 3600))
            RELATIVE_TIME="${HOURS}h ago"
        else
            DAYS=$((TIME_DIFF / 86400))
            RELATIVE_TIME="${DAYS}d ago"
        fi
    else
        RELATIVE_TIME="unknown"
    fi

    # Parse task.json if available
    if [ -f "$CONFIG_FILE" ] && command -v jq &> /dev/null; then
        DESCRIPTION=$(jq -r '.description // "N/A"' "$CONFIG_FILE" 2>/dev/null)
        PR_URL=$(jq -r '.pr_url // "N/A"' "$CONFIG_FILE" 2>/dev/null)
        PR_NUMBER=$(jq -r '.pr_number // "N/A"' "$CONFIG_FILE" 2>/dev/null)
        REPO_COUNT=$(jq -r '.repositories | length' "$CONFIG_FILE" 2>/dev/null)
    else
        DESCRIPTION="(no config)"
        PR_URL="N/A"
        PR_NUMBER="N/A"
        REPO_COUNT=0
    fi

    # Determine status from TASK_STATUS.md
    STATUS_ICON="⚪"
    STATUS_TEXT="Unknown"

    if [ -f "$STATUS_FILE" ]; then
        # Check for failing CI
        if grep -q -E "(❌|FAILED|failing.*CI|CI.*failing)" "$STATUS_FILE" 2>/dev/null; then
            STATUS_ICON="🔴"
            STATUS_TEXT="CI Failing"
        # Check for passing
        elif grep -q -E "(✅.*PASSING|All.*pass|CI.*pass)" "$STATUS_FILE" 2>/dev/null; then
            STATUS_ICON="🟢"
            STATUS_TEXT="Passing"
        # Check for in progress
        elif grep -q -E "(Investigation|WIP|TODO|In Progress)" "$STATUS_FILE" 2>/dev/null; then
            STATUS_ICON="🟡"
            STATUS_TEXT="In Progress"
        # Check for completed
        elif grep -q -E "(✅.*[Cc]omplete|DONE|[Rr]esolved)" "$STATUS_FILE" 2>/dev/null; then
            STATUS_ICON="🟢"
            STATUS_TEXT="Complete"
        fi
    fi

    # Truncate description
    if [ ${#DESCRIPTION} -gt 50 ]; then
        DESCRIPTION="${DESCRIPTION:0:47}..."
    fi

    # Print task info
    echo -e "${BLUE}${TASK_NUM}.${NC} ${STATUS_ICON} ${TASK_NAME}"

    if [ "$PR_NUMBER" != "N/A" ] && [ "$PR_NUMBER" != "null" ]; then
        echo "   PR #${PR_NUMBER}"
    fi

    echo "   ${DESCRIPTION}"
    echo "   Status: ${STATUS_TEXT} | Last updated: ${RELATIVE_TIME}"

    if [ "$PR_URL" != "N/A" ] && [ "$PR_URL" != "null" ]; then
        echo "   ${PR_URL}"
    fi

    echo ""
done

echo -e "${GREEN}Commands:${NC}"
echo "  /resume-task <task-name>  - Restore and work on a task"
echo "  /new-task <description>   - Create a new task"
echo ""
echo -e "To resume: ${BLUE}/resume-task <task-name>${NC}"
