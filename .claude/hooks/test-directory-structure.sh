#!/bin/bash
# Test suite for directory-structure-check.sh hook

set +e  # Don't exit on test failures

HOOK_SCRIPT="$(dirname "$0")/directory-structure-check.sh"
PASS=0
FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Testing Directory Structure Hook${NC}"
echo "========================================"
echo ""

# Test helper function
test_hook() {
  local test_name="$1"
  local tool_name="$2"
  local command="$3"
  local cwd="$4"
  local expected_exit="$5"

  local input="{\"tool_name\":\"$tool_name\",\"tool_input\":{\"command\":\"$command\"},\"cwd\":\"$cwd\"}"
  local output
  output=$(echo "$input" | "$HOOK_SCRIPT" 2>&1)
  local actual_exit=$?

  if [[ $actual_exit -eq $expected_exit ]]; then
    echo -e "${GREEN}✓ PASS${NC}: $test_name (exit $actual_exit)"
    ((PASS++))
  else
    echo -e "${RED}✗ FAIL${NC}: $test_name"
    echo "  Expected exit: $expected_exit, got: $actual_exit"
    if [[ -n "$output" ]]; then
      echo -e "  Output: ${YELLOW}${output:0:100}...${NC}"
    fi
    ((FAIL++))
  fi
}

# Setup test environment
TEST_ROOT="/tmp/workarea-structure-test"
rm -rf "$TEST_ROOT"
mkdir -p "$TEST_ROOT/bin"
mkdir -p "$TEST_ROOT/workspaces/test-workspace"
echo "# Test" > "$TEST_ROOT/CLAUDE.md"

# Initialize workspace as git repo
cd "$TEST_ROOT/workspaces/test-workspace"
git init -q 2>/dev/null
git config user.email "test@test.com" 2>/dev/null
git config user.name "Test" 2>/dev/null

echo ""
echo -e "${BLUE}=== Scenario 1: Git clone operations ===${NC}"
test_hook "Clone to repos/ (allowed)" "Bash" "git clone https://github.com/org/repo.git repos/repo" "$TEST_ROOT" 0
test_hook "Clone to workarea root (blocked)" "Bash" "git clone https://github.com/org/repo.git repo" "$TEST_ROOT" 2
test_hook "Clone to workspaces/ (blocked)" "Bash" "git clone https://github.com/org/repo.git workspaces/repo" "$TEST_ROOT" 2
test_hook "Clone to tasks/ (blocked)" "Bash" "git clone https://github.com/org/repo.git tasks/repo" "$TEST_ROOT/workspaces/test-workspace" 2

echo ""
echo -e "${BLUE}=== Scenario 2: Directory creation at root ===${NC}"
test_hook "Create repos/ directory (allowed)" "Bash" "mkdir repos" "$TEST_ROOT" 0
test_hook "Create workspaces/ directory (allowed)" "Bash" "mkdir workspaces" "$TEST_ROOT" 0
test_hook "Create tasks/ at root (blocked)" "Bash" "mkdir tasks" "$TEST_ROOT" 2
test_hook "Create random/ at root (blocked)" "Bash" "mkdir random-dir" "$TEST_ROOT" 2
test_hook "Create bin/ subdirectory (allowed)" "Bash" "mkdir bin/utils" "$TEST_ROOT" 0

echo ""
echo -e "${BLUE}=== Scenario 3: Workspace git validation ===${NC}"
test_hook "Git commit in initialized workspace (allowed)" "Bash" "git commit -m test" "$TEST_ROOT/workspaces/test-workspace" 0
test_hook "Git init in workspace (allowed)" "Bash" "git init" "$TEST_ROOT/workspaces/new-workspace" 0
test_hook "Git operations in workspaces container (blocked)" "Bash" "git init" "$TEST_ROOT/workspaces" 2
test_hook "Git commit in workspaces container (blocked)" "Bash" "git commit -m test" "$TEST_ROOT/workspaces" 2

echo ""
echo -e "${BLUE}=== Scenario 4: Non-Bash tools (should pass) ===${NC}"
test_hook "Edit tool" "Edit" "any command" "$TEST_ROOT" 0
test_hook "Write tool" "Write" "any command" "$TEST_ROOT" 0

echo ""
echo -e "${BLUE}=== Scenario 5: Outside workarea (should pass) ===${NC}"
test_hook "Commands outside workarea" "Bash" "mkdir anything" "/tmp" 0
test_hook "Git clone outside workarea" "Bash" "git clone https://github.com/org/repo.git" "/home/user" 0

echo ""
echo -e "${BLUE}=== Scenario 6: Safe operations (should pass) ===${NC}"
test_hook "ls command" "Bash" "ls -la" "$TEST_ROOT" 0
test_hook "cd command" "Bash" "cd workspaces" "$TEST_ROOT" 0
test_hook "cat command" "Bash" "cat CLAUDE.md" "$TEST_ROOT" 0

echo ""
echo -e "${BLUE}=== Scenario 7: Move/copy operations ===${NC}"
test_hook "mv within workspace (allowed)" "Bash" "mv tasks/old tasks/new" "$TEST_ROOT/workspaces/test-workspace" 0
test_hook "cp to repos/ (allowed)" "Bash" "cp -r /tmp/repo repos/new-repo" "$TEST_ROOT" 0
test_hook "mv to create root dir (blocked)" "Bash" "mv /tmp/stuff mydir" "$TEST_ROOT" 2

echo ""
echo -e "${BLUE}=== Scenario 8: git init location validation ===${NC}"
mkdir -p "$TEST_ROOT/repos/test-repo"
mkdir -p "$TEST_ROOT/workspaces/test-workspace/tasks/my-task"
test_hook "git init in repos/ container (blocked)" "Bash" "git init" "$TEST_ROOT/repos" 2
test_hook "git init in repos/repo/ (allowed)" "Bash" "git init" "$TEST_ROOT/repos/test-repo" 0
test_hook "git init in workspace root (allowed)" "Bash" "git init" "$TEST_ROOT/workspaces/test-workspace" 0
test_hook "git init in workspaces/ container (blocked)" "Bash" "git init" "$TEST_ROOT/workspaces" 2
test_hook "git init in tasks/ (blocked)" "Bash" "git init" "$TEST_ROOT/workspaces/test-workspace/tasks" 2
test_hook "git init in task root (blocked)" "Bash" "git init" "$TEST_ROOT/workspaces/test-workspace/tasks/my-task" 2
test_hook "git init at workarea root (blocked)" "Bash" "git init" "$TEST_ROOT" 2

# Cleanup
rm -rf "$TEST_ROOT"

echo ""
echo "========================================"
echo -e "${BLUE}Results Summary:${NC}"
echo -e "  ${GREEN}Passed: $PASS${NC}"
echo -e "  ${RED}Failed: $FAIL${NC}"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed!${NC}"
  exit 1
fi
