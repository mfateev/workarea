#!/bin/bash

# Script to find tasks across all workspaces by name or partial match
# Usage: find-task.sh <pattern>
#
# Searches all workspaces for tasks matching the pattern.
# Returns structured output with workspace, task name, and path.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =============================================================================
# Helper Functions
# =============================================================================

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

# =============================================================================
# Configuration
# =============================================================================

WORKAREA_ROOT="$(resolve_workarea_root)"
WORKSPACES_DIR="${WORKAREA_ROOT}/workspaces"

usage() {
    echo "Usage: $0 <pattern>"
    echo ""
    echo "Search for tasks across all workspaces."
    echo ""
    echo "Arguments:"
    echo "  pattern    Task name or partial match (case-insensitive)"
    echo ""
    echo "Examples:"
    echo "  $0 airflow          # Finds 'temporal-airflow'"
    echo "  $0 async            # Finds 'async-await'"
    echo "  $0 PR-2751          # Finds task for PR #2751"
    echo ""
    echo "Output format:"
    echo "  MATCH:<workspace>:<task-name>:<full-path>"
    exit 1
}

# Parse arguments
if [ $# -ne 1 ]; then
    usage
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

PATTERN="$1"
PATTERN_LOWER=$(echo "$PATTERN" | tr '[:upper:]' '[:lower:]')

# Track matches
declare -a MATCHES=()

# =============================================================================
# Search Logic
# =============================================================================

# Search all workspaces
if [ -d "$WORKSPACES_DIR" ]; then
    for workspace_dir in "$WORKSPACES_DIR"/*/; do
        [ -d "$workspace_dir" ] || continue

        workspace_name=$(basename "$workspace_dir")
        tasks_dir="${workspace_dir}tasks"

        if [ -d "$tasks_dir" ]; then
            for task_dir in "$tasks_dir"/*/; do
                [ -d "$task_dir" ] || continue

                task_name=$(basename "$task_dir")
                task_name_lower=$(echo "$task_name" | tr '[:upper:]' '[:lower:]')

                # Check various matching strategies
                match_found=false

                # 1. Exact match
                if [ "$task_name_lower" = "$PATTERN_LOWER" ]; then
                    match_found=true
                fi

                # 2. Contains pattern (substring)
                if [[ "$task_name_lower" == *"$PATTERN_LOWER"* ]]; then
                    match_found=true
                fi

                # 3. Check task.json for PR number match
                if [ -f "${task_dir}task.json" ] && command -v jq &> /dev/null; then
                    pr_number=$(jq -r '.pr_number // empty' "${task_dir}task.json" 2>/dev/null || true)
                    if [ -n "$pr_number" ]; then
                        # Match "PR-123" or just "123" or "2751"
                        if [[ "$PATTERN" =~ ^[Pp][Rr][-#]?([0-9]+)$ ]]; then
                            pr_search="${BASH_REMATCH[1]}"
                            if [ "$pr_number" = "$pr_search" ]; then
                                match_found=true
                            fi
                        elif [[ "$PATTERN" =~ ^[0-9]+$ ]] && [ "$pr_number" = "$PATTERN" ]; then
                            match_found=true
                        fi
                    fi
                fi

                if [ "$match_found" = true ]; then
                    # Remove trailing slash from task_dir
                    task_path="${task_dir%/}"
                    MATCHES+=("${workspace_name}:${task_name}:${task_path}")
                fi
            done
        fi
    done
fi

# =============================================================================
# Output Results
# =============================================================================

if [ ${#MATCHES[@]} -eq 0 ]; then
    echo -e "${RED}No tasks found matching \"${PATTERN}\"${NC}"
    echo ""
    echo "Available tasks:"
    echo ""

    if [ -d "$WORKSPACES_DIR" ]; then
        for workspace_dir in "$WORKSPACES_DIR"/*/; do
            [ -d "$workspace_dir" ] || continue

            workspace_name=$(basename "$workspace_dir")
            tasks_dir="${workspace_dir}tasks"

            if [ -d "$tasks_dir" ] && [ "$(ls -A "$tasks_dir" 2>/dev/null)" ]; then
                echo -e "${CYAN}${workspace_name}:${NC}"
                for task_dir in "$tasks_dir"/*/; do
                    [ -d "$task_dir" ] || continue
                    task_name=$(basename "$task_dir")

                    # Try to get PR info
                    pr_info=""
                    if [ -f "${task_dir}task.json" ] && command -v jq &> /dev/null; then
                        pr_number=$(jq -r '.pr_number // empty' "${task_dir}task.json" 2>/dev/null || true)
                        if [ -n "$pr_number" ]; then
                            pr_info=" (PR #${pr_number})"
                        fi
                    fi

                    echo "  - ${task_name}${pr_info}"
                done
            fi
        done
    fi

    exit 1
fi

if [ ${#MATCHES[@]} -eq 1 ]; then
    # Single match - output in machine-readable format
    IFS=':' read -r ws_name task_name task_path <<< "${MATCHES[0]}"
    echo -e "${GREEN}Found task:${NC}"
    echo "  Workspace: ${ws_name}"
    echo "  Task: ${task_name}"
    echo "  Path: ${task_path}"
    echo ""
    echo "MATCH:${ws_name}:${task_name}:${task_path}"
else
    # Multiple matches - list them all
    echo -e "${YELLOW}Multiple tasks found matching \"${PATTERN}\":${NC}"
    echo ""

    i=1
    for match in "${MATCHES[@]}"; do
        IFS=':' read -r ws_name task_name task_path <<< "$match"
        echo -e "${BLUE}${i}.${NC} ${ws_name}/${task_name}"
        echo "   Path: ${task_path}"

        # Show PR info if available
        if [ -f "${task_path}/task.json" ] && command -v jq &> /dev/null; then
            pr_url=$(jq -r '.pr_url // empty' "${task_path}/task.json" 2>/dev/null || true)
            if [ -n "$pr_url" ]; then
                echo "   PR: ${pr_url}"
            fi
        fi
        echo ""
        ((i++))
    done

    echo "Specify which task to resume by number or use a more specific pattern."

    # Output all matches for parsing
    for match in "${MATCHES[@]}"; do
        IFS=':' read -r ws_name task_name task_path <<< "$match"
        echo "MATCH:${ws_name}:${task_name}:${task_path}"
    done
fi
