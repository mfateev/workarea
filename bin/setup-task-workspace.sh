#!/bin/bash

# Script to setup a task workspace with git worktrees
# Usage: setup-task-workspace.sh <task-name> <repo-url-1> [repo-url-2] ...
#
# IMPORTANT: Must be run from within a workspace (workspaces/<name>/).
# Repos are shared at workarea root. Tasks are created in the current workspace.

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
    echo "Or create a new workspace:"
    echo -e "  ${BLUE}/new-workspace <name>${NC}"
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

# Initialize array to store repository configurations
REPO_CONFIGS=()

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

    # Store repository info for config generation
    REPO_CONFIGS+=("$(cat <<EOF
{
  "name": "$REPO_NAME",
  "upstream_url": "$repo_url",
  "fork_url": $([ -n "$fork_owner" ] && echo "\"https://github.com/${fork_owner}/${REPO_NAME}.git\"" || echo "null"),
  "branch": "$TARGET_BRANCH",
  "fork_owner": $([ -n "$fork_owner" ] && echo "\"$fork_owner\"" || echo "null"),
  "tracking_remote": $([ -n "$fork_owner" ] && echo "\"$fork_owner\"" || echo "\"origin\""),
  "tracking_branch": "$TARGET_BRANCH"
}
EOF
)")
done

# Generate task.json configuration file
echo ""
echo -e "${GREEN}Generating task configuration...${NC}"

CONFIG_FILE="${TASK_DIR}/task.json"

# Determine PR info if available
if [ -n "${pr_branch}" ]; then
    # Extract PR number from first repo URL if it's a PR
    PR_INFO=$(echo "${REPO_URLS[0]}" | grep -o 'pull/[0-9]*' || echo "")
    PR_NUMBER=$(echo "$PR_INFO" | grep -o '[0-9]*' || echo "")

    if [ -n "$PR_NUMBER" ]; then
        PR_URL="${REPO_URLS[0]}"
        PR_DESC=$(gh pr view "$PR_NUMBER" --repo "${repo_url%.git}" --json title --jq '.title' 2>/dev/null || echo "")
    fi
fi

# Build repositories JSON array
REPOS_JSON="["
for i in "${!REPO_CONFIGS[@]}"; do
    if [ $i -gt 0 ]; then
        REPOS_JSON+=","
    fi
    REPOS_JSON+="${REPO_CONFIGS[$i]}"
done
REPOS_JSON+="]"

# Generate config file
cat > "$CONFIG_FILE" <<EOF
{
  "task_name": "$TASK_NAME",
  "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "pr_url": $([ -n "$PR_URL" ] && echo "\"$PR_URL\"" || echo "null"),
  "pr_number": $([ -n "$PR_NUMBER" ] && echo "$PR_NUMBER" || echo "null"),
  "repositories": $REPOS_JSON,
  "description": $([ -n "$PR_DESC" ] && echo "\"$PR_DESC\"" || echo "\"$TASK_NAME\"")
}
EOF

echo -e "${GREEN}  ✓ Created: ${CONFIG_FILE}${NC}"

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
