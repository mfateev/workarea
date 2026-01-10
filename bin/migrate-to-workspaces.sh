#!/bin/bash
# migrate-to-workspaces.sh
#
# One-time migration script to move existing tasks/ and archived/
# to a default workspace under the new structure.
#
# Usage: ./bin/migrate-to-workspaces.sh [workspace-name]
#        Default workspace name is "default"

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get workarea root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKAREA_ROOT="$(dirname "$SCRIPT_DIR")"

WORKSPACE_NAME="${1:-default}"
WORKSPACES_DIR="${WORKAREA_ROOT}/workspaces"
WORKSPACE_DIR="${WORKSPACES_DIR}/${WORKSPACE_NAME}"

echo -e "${GREEN}Workarea Redesign Migration${NC}"
echo "==============================="
echo ""
echo "This script will migrate existing tasks/ and archived/ to:"
echo "  ${BLUE}workspaces/${WORKSPACE_NAME}/${NC}"
echo ""
echo "Current structure:"
if [ -d "${WORKAREA_ROOT}/tasks" ]; then
    TASK_COUNT=$(ls -d "${WORKAREA_ROOT}/tasks"/*/ 2>/dev/null | wc -l | tr -d ' ')
    echo "  tasks/        (${TASK_COUNT} tasks found)"
else
    echo "  tasks/        (not found)"
fi
if [ -d "${WORKAREA_ROOT}/archived" ]; then
    ARCHIVED_COUNT=$(ls -d "${WORKAREA_ROOT}/archived"/*/ 2>/dev/null | wc -l | tr -d ' ')
    echo "  archived/     (${ARCHIVED_COUNT} archived tasks found)"
else
    echo "  archived/     (not found)"
fi
echo ""

# Check if workspace already exists
if [ -d "$WORKSPACE_DIR" ]; then
    echo -e "${RED}Error: Workspace already exists: ${WORKSPACE_NAME}${NC}"
    echo "Location: $WORKSPACE_DIR"
    echo ""
    echo "To migrate to a different workspace:"
    echo "  $0 <other-workspace-name>"
    exit 1
fi

# Check if there's anything to migrate
if [ ! -d "${WORKAREA_ROOT}/tasks" ] && [ ! -d "${WORKAREA_ROOT}/archived" ]; then
    echo -e "${YELLOW}Nothing to migrate.${NC}"
    echo ""
    echo "No existing tasks/ or archived/ directories found."
    echo "You can create a new workspace with:"
    echo "  ./bin/new-workspace.sh <name>"
    exit 0
fi

# Confirm migration
read -p "Continue with migration? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled."
    exit 0
fi

echo ""
echo "Starting migration..."
echo ""

# Create workspaces directory structure
mkdir -p "$WORKSPACES_DIR"
if [ ! -f "${WORKSPACES_DIR}/.gitkeep" ]; then
    touch "${WORKSPACES_DIR}/.gitkeep"
    echo -e "  ${GREEN}Created:${NC} workspaces/.gitkeep"
fi

# Create workspace directory
mkdir -p "$WORKSPACE_DIR"
echo -e "  ${GREEN}Created:${NC} workspaces/${WORKSPACE_NAME}/"

# Move tasks/ if exists
if [ -d "${WORKAREA_ROOT}/tasks" ]; then
    mv "${WORKAREA_ROOT}/tasks" "${WORKSPACE_DIR}/tasks"
    echo -e "  ${GREEN}Moved:${NC}   tasks/ -> workspaces/${WORKSPACE_NAME}/tasks/"
else
    mkdir -p "${WORKSPACE_DIR}/tasks"
    echo -e "  ${GREEN}Created:${NC} workspaces/${WORKSPACE_NAME}/tasks/"
fi

# Move archived/ if exists
if [ -d "${WORKAREA_ROOT}/archived" ]; then
    mv "${WORKAREA_ROOT}/archived" "${WORKSPACE_DIR}/archived"
    echo -e "  ${GREEN}Moved:${NC}   archived/ -> workspaces/${WORKSPACE_NAME}/archived/"
else
    mkdir -p "${WORKSPACE_DIR}/archived"
    echo -e "  ${GREEN}Created:${NC} workspaces/${WORKSPACE_NAME}/archived/"
fi

# Create bin symlink
ln -s "../../bin" "${WORKSPACE_DIR}/bin"
echo -e "  ${GREEN}Created:${NC} workspaces/${WORKSPACE_NAME}/bin -> ../../bin"

# Create workspace README
cat > "${WORKSPACE_DIR}/README.md" <<EOF
# Workspace: ${WORKSPACE_NAME}

Migrated from original workarea structure on $(date +%Y-%m-%d).

This workspace contains all tasks that were previously in the root tasks/ directory.

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
EOF
echo -e "  ${GREEN}Created:${NC} workspaces/${WORKSPACE_NAME}/README.md"

# Create archived/README.md if it doesn't exist
if [ ! -f "${WORKSPACE_DIR}/archived/README.md" ]; then
    cat > "${WORKSPACE_DIR}/archived/README.md" <<EOF
# Archived Tasks - ${WORKSPACE_NAME}

Completed tasks for this workspace.

| Task | Overview | Started | Completed | PR/Issue |
|------|----------|---------|-----------|----------|
<!-- New entries added above this line -->
EOF
    echo -e "  ${GREEN}Created:${NC} workspaces/${WORKSPACE_NAME}/archived/README.md"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Migration completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "New structure:"
echo "  workspaces/${WORKSPACE_NAME}/"
echo "  ├── bin -> ../../bin"
echo "  ├── tasks/"
if [ -d "${WORKSPACE_DIR}/tasks" ]; then
    for task in "${WORKSPACE_DIR}/tasks"/*/; do
        if [ -d "$task" ]; then
            echo "  │   └── $(basename "$task")/"
        fi
    done
fi
echo "  ├── archived/"
echo "  └── README.md"
echo ""
echo "Next steps:"
echo "  1. Update .gitignore (if not already done)"
echo "  2. Test the workspace:"
echo -e "     ${BLUE}cd workspaces/${WORKSPACE_NAME}${NC}"
echo -e "     ${BLUE}./bin/list-tasks.sh${NC}"
echo "  3. Commit the changes"
