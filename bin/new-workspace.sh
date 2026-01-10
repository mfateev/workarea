#!/bin/bash
# new-workspace.sh - Create a new workspace with proper structure
#
# Usage: ./bin/new-workspace.sh <workspace-name> [description]
#
# Creates:
#   workspaces/<name>/
#   workspaces/<name>/tasks/
#   workspaces/<name>/archived/
#   workspaces/<name>/bin -> ../../bin (symlink)
#   workspaces/<name>/README.md
#   workspaces/<name>/archived/README.md

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Resolve the true workarea root (handles symlinks)
resolve_workarea_root() {
    local script_path="${BASH_SOURCE[0]}"

    # If called via symlink, resolve it
    if [ -L "$script_path" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS: use combination of dirname and readlink
            local link_dir="$(cd "$(dirname "$script_path")" && pwd)"
            local link_target="$(readlink "$script_path")"
            if [[ "$link_target" == /* ]]; then
                script_path="$link_target"
            else
                script_path="$link_dir/$link_target"
            fi
        else
            script_path="$(readlink -f "$script_path")"
        fi
    fi

    local script_dir="$(cd "$(dirname "$script_path")" && pwd)"
    dirname "$script_dir"
}

WORKAREA_ROOT="$(resolve_workarea_root)"
WORKSPACES_DIR="${WORKAREA_ROOT}/workspaces"

usage() {
    echo "Usage: $0 <workspace-name> [description]"
    echo ""
    echo "Creates a new workspace with proper structure."
    echo ""
    echo "Arguments:"
    echo "  workspace-name  Name for the workspace (lowercase, alphanumeric, dashes)"
    echo "  description     Optional description for the workspace"
    echo ""
    echo "Examples:"
    echo "  $0 personal \"My personal projects\""
    echo "  $0 work \"Work-related tasks\""
    echo "  $0 temporal"
    exit 1
}

if [ $# -lt 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

WORKSPACE_NAME="$1"
DESCRIPTION="${2:-Workspace for $WORKSPACE_NAME}"

# Validate workspace name (lowercase alphanumeric with optional dashes, no leading/trailing dash)
if [[ ! "$WORKSPACE_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
    echo -e "${RED}Error: Workspace name must be lowercase alphanumeric with optional dashes${NC}"
    echo "Valid examples: personal, work-tasks, my-project, sdk"
    echo "Invalid: Work, my_project, -test, test-"
    exit 1
fi

WORKSPACE_DIR="${WORKSPACES_DIR}/${WORKSPACE_NAME}"

# Check if workspace already exists
if [ -d "$WORKSPACE_DIR" ]; then
    echo -e "${RED}Error: Workspace already exists: ${WORKSPACE_NAME}${NC}"
    echo "Location: $WORKSPACE_DIR"
    exit 1
fi

# Ensure workspaces directory exists
mkdir -p "$WORKSPACES_DIR"

echo -e "${GREEN}Creating workspace: ${WORKSPACE_NAME}${NC}"
echo ""

# Create directory structure
mkdir -p "$WORKSPACE_DIR"
mkdir -p "$WORKSPACE_DIR/tasks"
mkdir -p "$WORKSPACE_DIR/archived"

echo "  Created: $WORKSPACE_DIR/"
echo "  Created: $WORKSPACE_DIR/tasks/"
echo "  Created: $WORKSPACE_DIR/archived/"

# Create symlink to shared bin/
ln -s "../../bin" "$WORKSPACE_DIR/bin"
echo "  Created: $WORKSPACE_DIR/bin -> ../../bin"

# Create workspace README.md
cat > "$WORKSPACE_DIR/README.md" <<EOF
# Workspace: ${WORKSPACE_NAME}

${DESCRIPTION}

## Structure

\`\`\`
${WORKSPACE_NAME}/
├── bin -> ../../bin     # Shared scripts (symlink)
├── tasks/               # Active tasks
└── archived/            # Completed tasks
\`\`\`

## Usage

\`\`\`bash
# Navigate here
cd workspaces/${WORKSPACE_NAME}

# Create a new task
/new-task <description or PR URL>

# List tasks in this workspace
/workarea-tasks

# Resume a task
/resume-task <task-name>
\`\`\`

## Notes

- Repos are shared across all workspaces at \`../../repos/\`
- This workspace content is gitignored (local only)
- Tasks are isolated to this workspace
EOF
echo "  Created: $WORKSPACE_DIR/README.md"

# Create archived/README.md for task history
cat > "$WORKSPACE_DIR/archived/README.md" <<EOF
# Archived Tasks - ${WORKSPACE_NAME}

Completed tasks for this workspace.

| Task | Overview | Started | Completed | PR/Issue |
|------|----------|---------|-----------|----------|
<!-- New entries added above this line -->
EOF
echo "  Created: $WORKSPACE_DIR/archived/README.md"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Workspace created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Location: ${WORKSPACE_DIR}"
echo ""
echo "To start using this workspace:"
echo -e "  ${BLUE}cd ${WORKSPACE_DIR}${NC}"
echo -e "  ${BLUE}/new-task <description or PR URL>${NC}"
echo ""
echo "Or from anywhere:"
echo -e "  ${BLUE}cd $(realpath --relative-to="$(pwd)" "$WORKSPACE_DIR" 2>/dev/null || echo "$WORKSPACE_DIR")${NC}"
