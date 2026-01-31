#!/bin/bash
# Comprehensive test for git-safety-check.sh hook scenarios

# Don't use set -e because arithmetic operations can return non-zero

HOOK_SCRIPT="/home/sprite/workarea/.claude/hooks/git-safety-check.sh"
PASS=0
FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function to test hook
test_hook() {
  local test_name="$1"
  local tool_name="$2"
  local command="$3"
  local cwd="$4"
  local expected_exit="$5"

  local input="{\"tool_name\":\"$tool_name\",\"tool_input\":{\"command\":\"$command\"},\"cwd\":\"$cwd\"}"

  # Run hook and capture output and exit code
  local output
  output=$(echo "$input" | "$HOOK_SCRIPT" 2>&1)
  local actual_exit=$?

  if [[ $actual_exit -eq $expected_exit ]]; then
    echo -e "${GREEN}✓ PASS${NC}: $test_name (exit $actual_exit)"
    ((PASS++))
  else
    echo -e "${RED}✗ FAIL${NC}: $test_name"
    echo -e "  Expected exit: $expected_exit, got: $actual_exit"
    if [[ -n "$output" ]]; then
      echo -e "  Output: ${YELLOW}${output:0:100}...${NC}"
    fi
    ((FAIL++))
  fi
}

echo -e "${BLUE}Testing Git Safety Hook - All Scenarios${NC}"
echo "=========================================="
echo

# Setup test environment
TEST_ROOT="/tmp/workarea-hook-test"
rm -rf "$TEST_ROOT"
mkdir -p "$TEST_ROOT/workspaces/test-workspace/tasks/my-feature"
cd "$TEST_ROOT/workspaces/test-workspace"

# Initialize workspace repo
git init -q
git config user.email "test@test.com"
git config user.name "Test User"

# Create task metadata
echo '{"task_name":"my-feature"}' > tasks/my-feature/task.json
echo "# Task Status" > tasks/my-feature/TASK_STATUS.md
git add tasks/
git commit -q -m "Initial task"

# Create a mock worktree directory (sdk-java)
mkdir -p tasks/my-feature/sdk-java/src
echo "gitdir: $TEST_ROOT/repos/sdk-java/.git/worktrees/my-feature" > tasks/my-feature/sdk-java/.git
echo "public class Main {}" > tasks/my-feature/sdk-java/src/Main.java

echo -e "${BLUE}=== Scenario 1: Read-only commands (should always pass) ===${NC}"
test_hook "Git status" "Bash" "git status" "$TEST_ROOT/workspaces/test-workspace/tasks/my-feature" 0
test_hook "Git log" "Bash" "git log" "$TEST_ROOT/workspaces/test-workspace/tasks/my-feature" 0
test_hook "Git diff" "Bash" "git diff" "$TEST_ROOT/workspaces/test-workspace/tasks/my-feature" 0
test_hook "Git remote -v" "Bash" "git remote -v" "$TEST_ROOT/workspaces/test-workspace/tasks/my-feature" 0
echo

echo -e "${BLUE}=== Scenario 2: Committing task metadata (should pass) ===${NC}"
# Stage only task metadata
cd "$TEST_ROOT/workspaces/test-workspace/tasks/my-feature"
echo "Updated" >> TASK_STATUS.md
git add TASK_STATUS.md

test_hook "Commit task metadata only" "Bash" "git commit -m 'Update task status'" "$TEST_ROOT/workspaces/test-workspace/tasks/my-feature" 0
echo

echo -e "${BLUE}=== Scenario 3: Adding task metadata (should pass) ===${NC}"
git reset -q HEAD~1  # Undo previous commit
test_hook "Add task.json" "Bash" "git add task.json" "$TEST_ROOT/workspaces/test-workspace/tasks/my-feature" 0
test_hook "Add TASK_STATUS.md" "Bash" "git add TASK_STATUS.md" "$TEST_ROOT/workspaces/test-workspace/tasks/my-feature" 0
echo

echo -e "${BLUE}=== Scenario 4: Adding code files from wrong location (should block) ===${NC}"
test_hook "Add code file from task root" "Bash" "git add sdk-java/src/Main.java" "$TEST_ROOT/workspaces/test-workspace/tasks/my-feature" 2
test_hook "Add repository directory from task root" "Bash" "git add sdk-java/" "$TEST_ROOT/workspaces/test-workspace/tasks/my-feature" 2
echo

echo -e "${BLUE}=== Scenario 5: Committing code files from wrong location (should block) ===${NC}"
# Stage a code file from wrong location (simulate accidental add)
cd "$TEST_ROOT/workspaces/test-workspace"
echo "// Updated" >> tasks/my-feature/sdk-java/src/Main.java
git add tasks/my-feature/sdk-java/src/Main.java

test_hook "Commit code file from task root" "Bash" "git commit -m 'Update code'" "$TEST_ROOT/workspaces/test-workspace/tasks/my-feature" 2

# Reset
git reset -q HEAD
echo

echo -e "${BLUE}=== Scenario 6: Working from inside worktree (should pass) ===${NC}"
cd "$TEST_ROOT/workspaces/test-workspace/tasks/my-feature/sdk-java"
git init -q  # Make it a real git repo for testing
git config user.email "test@test.com"
git config user.name "Test User"

# Simulate worktree by having .git file instead of directory
rm -rf .git
echo "gitdir: /some/path/.git/worktrees/my-feature" > .git

test_hook "Commit from worktree" "Bash" "git commit -m 'Fix bug'" "$TEST_ROOT/workspaces/test-workspace/tasks/my-feature/sdk-java" 0
test_hook "Add from worktree" "Bash" "git add src/Main.java" "$TEST_ROOT/workspaces/test-workspace/tasks/my-feature/sdk-java" 0
test_hook "Push from worktree" "Bash" "git push origin feature" "$TEST_ROOT/workspaces/test-workspace/tasks/my-feature/sdk-java" 0
echo

echo -e "${BLUE}=== Scenario 7: Non-Bash tools (should pass) ===${NC}"
test_hook "Edit tool" "Edit" "git commit" "$TEST_ROOT/workspaces/test-workspace/tasks/my-feature" 0
test_hook "Write tool" "Write" "git push" "$TEST_ROOT/workspaces/test-workspace/tasks/my-feature" 0
echo

echo -e "${BLUE}=== Scenario 8: Non-git commands (should pass) ===${NC}"
test_hook "ls command" "Bash" "ls -la" "$TEST_ROOT/workspaces/test-workspace/tasks/my-feature" 0
test_hook "cat command" "Bash" "cat task.json" "$TEST_ROOT/workspaces/test-workspace/tasks/my-feature" 0
echo

echo -e "${BLUE}=== Scenario 9: Worktree location validation ===${NC}"

# Create worktree in correct location (inside tasks/<task>/<repo>/)
mkdir -p "$TEST_ROOT/workspaces/test-workspace/tasks/another-task/backend"
echo "gitdir: /some/path/.git/worktrees/backend" > "$TEST_ROOT/workspaces/test-workspace/tasks/another-task/backend/.git"

test_hook "Worktree in correct location (allowed)" "Bash" "git commit -m 'test'" "$TEST_ROOT/workspaces/test-workspace/tasks/another-task/backend" 0

# Create worktree in wrong location (not inside tasks/)
mkdir -p "$TEST_ROOT/workspaces/test-workspace/random-worktree"
echo "gitdir: /some/path/.git/worktrees/random" > "$TEST_ROOT/workspaces/test-workspace/random-worktree/.git"

test_hook "Worktree outside tasks/ (blocked)" "Bash" "git commit -m 'test'" "$TEST_ROOT/workspaces/test-workspace/random-worktree" 2

# Create worktree at wrong depth (tasks/<repo>/ instead of tasks/<task>/<repo>/)
mkdir -p "$TEST_ROOT/workspaces/test-workspace/tasks/wrong-depth"
echo "gitdir: /some/path/.git/worktrees/wrong" > "$TEST_ROOT/workspaces/test-workspace/tasks/wrong-depth/.git"

test_hook "Worktree at wrong depth (blocked)" "Bash" "git commit -m 'test'" "$TEST_ROOT/workspaces/test-workspace/tasks/wrong-depth" 2

# Create worktree completely outside workarea structure
mkdir -p "$TEST_ROOT/some-other-project"
echo "gitdir: /some/path/.git/worktrees/other" > "$TEST_ROOT/some-other-project/.git"

test_hook "Worktree outside workarea (blocked)" "Bash" "git commit -m 'test'" "$TEST_ROOT/some-other-project" 2
echo

# Cleanup
cd /
rm -rf "$TEST_ROOT"

echo "=========================================="
echo -e "${BLUE}Results Summary:${NC}"
echo -e "  ${GREEN}Passed: $PASS${NC}"
echo -e "  ${RED}Failed: $FAIL${NC}"
echo

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}Some tests failed!${NC}"
  exit 1
else
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
fi
