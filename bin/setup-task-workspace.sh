#!/bin/bash

# Script to setup a task workspace with git worktrees
# Usage: setup-task-workspace.sh <task-name> <repo-url-1> [repo-url-2] ...

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
    echo "Usage: $0 <task-name> <repo-url-or-pr-url> [repo-url-or-pr-url] ..."
    echo ""
    echo "Supports both repository URLs and GitHub PR URLs."
    echo ""
    echo "Examples:"
    echo "  # With repository URLs"
    echo "  $0 feature-x https://github.com/user/repo1.git"
    echo ""
    echo "  # With PR URL (automatically fetches branch from fork if needed)"
    echo "  $0 async-await https://github.com/temporalio/sdk-java/pull/2751"
    echo ""
    echo "  # Multiple repositories"
    echo "  $0 feature-x https://github.com/user/repo1.git https://github.com/user/repo2.git"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo "  -b, --branch  Specify branch for worktree (default: creates new branch task/<task-name>)"
    echo ""
    echo "Note: PR URL support requires 'gh' CLI to be installed."
    exit 1
}

# Parse arguments
if [ $# -lt 2 ]; then
    usage
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

TASK_NAME="$1"
shift

BRANCH_NAME="task/${TASK_NAME}"
CUSTOM_BRANCH=""

# Check for branch option
if [ "$1" = "-b" ] || [ "$1" = "--branch" ]; then
    CUSTOM_BRANCH="$2"
    shift 2
fi

REPO_URLS=("$@")

if [ ${#REPO_URLS[@]} -eq 0 ]; then
    echo -e "${RED}Error: At least one repository URL is required${NC}"
    usage
fi

# Extract repo name from git URL
get_repo_name() {
    local url="$1"
    # Remove .git suffix and extract last part of path
    basename "$url" .git
}

# Parse PR URL to get repository and branch info
# Returns: "repo_url|branch_name|fork_owner" or just "repo_url" if not a PR
parse_pr_url() {
    local input="$1"

    # Check if this is a GitHub PR URL
    if [[ "$input" =~ ^https://github\.com/([^/]+)/([^/]+)/pull/([0-9]+)$ ]]; then
        local org="${BASH_REMATCH[1]}"
        local repo="${BASH_REMATCH[2]}"
        local pr_number="${BASH_REMATCH[3]}"

        # Use gh CLI to get PR details if available
        if command -v gh &> /dev/null; then
            echo -e "${YELLOW}  Fetching PR #${pr_number} details...${NC}"
            local pr_info=$(gh pr view "$pr_number" --repo "$org/$repo" --json headRefName,headRepositoryOwner,isCrossRepository 2>/dev/null)

            if [ $? -eq 0 ]; then
                local branch=$(echo "$pr_info" | grep -o '"headRefName":"[^"]*"' | cut -d'"' -f4)
                local fork_owner=$(echo "$pr_info" | grep -o '"login":"[^"]*"' | cut -d'"' -f4)
                local is_fork=$(echo "$pr_info" | grep -o '"isCrossRepository":[^,}]*' | cut -d':' -f2)

                if [ "$is_fork" = "true" ]; then
                    echo "https://github.com/${org}/${repo}.git|${branch}|${fork_owner}"
                else
                    echo "https://github.com/${org}/${repo}.git|${branch}"
                fi
                return
            fi
        fi

        # Fallback if gh is not available
        echo "https://github.com/${org}/${repo}.git"
        return
    fi

    # Not a PR URL, return as-is
    echo "$input"
}

# Create base directories
echo -e "${GREEN}Setting up workspace structure...${NC}"
mkdir -p "$REPOS_DIR"
mkdir -p "$TASKS_DIR"

# Create task directory
TASK_DIR="${TASKS_DIR}/${TASK_NAME}"
if [ -d "$TASK_DIR" ]; then
    echo -e "${YELLOW}Warning: Task directory already exists: ${TASK_DIR}${NC}"
    read -p "Continue and add worktrees? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    mkdir -p "$TASK_DIR"
    echo -e "${GREEN}Created task directory: ${TASK_DIR}${NC}"
fi

# Process each repository
for repo_input in "${REPO_URLS[@]}"; do
    # Parse PR URL if applicable
    parsed=$(parse_pr_url "$repo_input")
    IFS='|' read -r repo_url pr_branch fork_owner <<< "$parsed"

    REPO_NAME=$(get_repo_name "$repo_url")
    REPO_PATH="${REPOS_DIR}/${REPO_NAME}"
    WORKTREE_PATH="${TASK_DIR}/${REPO_NAME}"

    echo ""
    echo -e "${GREEN}Processing repository: ${REPO_NAME}${NC}"

    # Clone repository if it doesn't exist
    if [ ! -d "$REPO_PATH" ]; then
        echo -e "${YELLOW}  Cloning ${repo_url} into ${REPO_PATH}...${NC}"
        git clone "$repo_url" "$REPO_PATH"
    else
        echo -e "  Repository already exists: ${REPO_PATH}"
        # Fetch latest changes
        echo -e "  Fetching latest changes..."
        (cd "$REPO_PATH" && git fetch --all)
    fi

    # If this is from a fork, add the fork remote and fetch
    if [ -n "$fork_owner" ]; then
        echo -e "${YELLOW}  PR is from fork: ${fork_owner}${NC}"
        FORK_REMOTE="${fork_owner}"
        FORK_URL="https://github.com/${fork_owner}/${REPO_NAME}.git"

        # Add fork remote if it doesn't exist
        if ! (cd "$REPO_PATH" && git remote | grep -q "^${FORK_REMOTE}$"); then
            echo -e "  Adding fork remote: ${FORK_REMOTE}"
            (cd "$REPO_PATH" && git remote add "$FORK_REMOTE" "$FORK_URL")
        fi

        # Fetch from fork
        echo -e "  Fetching from fork: ${FORK_REMOTE}/${pr_branch}"
        (cd "$REPO_PATH" && git fetch "$FORK_REMOTE" "$pr_branch")
    fi

    # Create worktree
    if [ -d "$WORKTREE_PATH" ]; then
        echo -e "${YELLOW}  Worktree already exists: ${WORKTREE_PATH}${NC}"
    else
        echo -e "  Creating worktree at ${WORKTREE_PATH}..."

        # Determine which branch to use
        if [ -n "$pr_branch" ]; then
            TARGET_BRANCH="$pr_branch"
            if [ -n "$fork_owner" ]; then
                # For fork PRs, use the remote branch
                BRANCH_REF="${fork_owner}/${pr_branch}"
            else
                BRANCH_REF="$pr_branch"
            fi
        elif [ -n "$CUSTOM_BRANCH" ]; then
            TARGET_BRANCH="$CUSTOM_BRANCH"
            BRANCH_REF="$CUSTOM_BRANCH"
        else
            TARGET_BRANCH="$BRANCH_NAME"
            BRANCH_REF="$BRANCH_NAME"
        fi

        # Create worktree - use absolute path to avoid path issues
        (
            cd "$REPO_PATH"
            # Try to create with new branch
            if ! git worktree add "$WORKTREE_PATH" -b "$TARGET_BRANCH" 2>/dev/null; then
                # Try to checkout existing branch/ref
                if ! git worktree add "$WORKTREE_PATH" "$BRANCH_REF" 2>/dev/null; then
                    # Last resort: use HEAD
                    echo -e "${YELLOW}  Could not create/checkout branch ${TARGET_BRANCH}, using HEAD${NC}"
                    git worktree add "$WORKTREE_PATH"
                fi
            fi
        )

        echo -e "${GREEN}  ✓ Worktree created${NC}"
    fi
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Workspace setup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Task directory: ${TASK_DIR}"
echo ""
echo "Worktrees created:"
for repo_url in "${REPO_URLS[@]}"; do
    REPO_NAME=$(get_repo_name "$repo_url")
    echo "  - ${TASK_DIR}/${REPO_NAME}"
done
echo ""
echo "To start working:"
echo "  cd ${TASK_DIR}"
