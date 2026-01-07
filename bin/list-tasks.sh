#!/bin/bash

# List all tasks with their status
# Can be run standalone or called by /tasks command

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKAREA_DIR="$(dirname "$SCRIPT_DIR")"
TASKS_DIR="${WORKAREA_DIR}/tasks"

# Check if tasks directory exists
if [ ! -d "$TASKS_DIR" ]; then
    echo -e "${YELLOW}No tasks directory found.${NC}"
    echo "Create your first task with: /new-task <description>"
    exit 0
fi

# Check if there are any tasks
shopt -s nullglob
TASK_DIRS=("$TASKS_DIR"/*)
shopt -u nullglob

if [ ${#TASK_DIRS[@]} -eq 0 ]; then
    echo -e "${YELLOW}No tasks found.${NC}"
    echo ""
    echo "Start a new task:"
    echo "  /new-task <description or PR URL>"
    echo ""
    echo "Example:"
    echo "  /new-task https://github.com/org/repo/pull/123"
    exit 0
fi

echo -e "${GREEN}=== Available Tasks ===${NC}"
echo ""

# Counter for numbering
TASK_NUM=0

# Iterate through tasks
for TASK_PATH in "${TASK_DIRS[@]}"; do
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
