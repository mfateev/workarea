#!/bin/bash

# Script to resume/restore a task from its task.json configuration
# Usage: resume-task.sh <task-name>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKAREA_DIR="$(dirname "$SCRIPT_DIR")"
REPOS_DIR="${WORKAREA_DIR}/repos"
TASKS_DIR="${WORKAREA_DIR}/tasks"

# Print usage
usage() {
    echo "Usage: $0 <task-name>"
    echo ""
    echo "Restores a task workspace from its task.json configuration."
    echo ""
    echo "Examples:"
    echo "  $0 async-await"
    echo "  $0 feature-authentication"
    echo ""
    echo "Note: This reads tasks/<task-name>/task.json to set up repositories and worktrees."
    exit 1
}

# Parse arguments
if [ $# -ne 1 ]; then
    usage
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

TASK_NAME="$1"
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
cd "$WORKAREA_DIR"

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
