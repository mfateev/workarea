#!/bin/bash
# Test script for git-safety-check.sh hook

set -e

HOOK_SCRIPT=".claude/hooks/git-safety-check.sh"
PASS=0
FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper function to test hook
test_hook() {
  local test_name="$1"
  local tool_name="$2"
  local command="$3"
  local cwd="$4"
  local expected_exit="$5"

  local input="{\"tool_name\":\"$tool_name\",\"tool_input\":{\"command\":\"$command\"},\"cwd\":\"$cwd\"}"

  # Run hook and capture exit code
  echo "$input" | "$HOOK_SCRIPT" >/dev/null 2>&1
  local actual_exit=$?

  if [[ $actual_exit -eq $expected_exit ]]; then
    echo -e "${GREEN}✓ PASS${NC}: $test_name (exit $actual_exit)"
    ((PASS++))
  else
    echo -e "${RED}✗ FAIL${NC}: $test_name (expected exit $expected_exit, got $actual_exit)"
    ((FAIL++))
  fi
}

echo "Testing Git Safety Hook"
echo "======================="
echo

# Test 1: Non-git commands should pass
test_hook "Non-git command" "Bash" "ls -la" "/any/directory" 0

# Test 2: Read-only git commands should pass
test_hook "Git status (read-only)" "Bash" "git status" "/any/directory" 0
test_hook "Git log (read-only)" "Bash" "git log" "/any/directory" 0
test_hook "Git diff (read-only)" "Bash" "git diff" "/any/directory" 0
test_hook "Git remote -v (read-only)" "Bash" "git remote -v" "/any/directory" 0

# Test 3: Git commands in task root with task.json should be blocked
mkdir -p /tmp/test-workspace/tasks/test-task
echo '{}' > /tmp/test-workspace/tasks/test-task/task.json
mkdir -p /tmp/test-workspace/tasks/test-task/.git  # Make it look like a git repo

test_hook "Git commit from task root (blocked)" "Bash" "git commit -m test" "/tmp/test-workspace/tasks/test-task" 2
test_hook "Git add from task root (blocked)" "Bash" "git add file.txt" "/tmp/test-workspace/tasks/test-task" 2

# Cleanup
rm -rf /tmp/test-workspace

# Test 4: Git commands inside worktree (has .git file, not directory) should pass
mkdir -p /tmp/test-worktree
echo "gitdir: /some/path" > /tmp/test-worktree/.git  # Worktree marker

test_hook "Git commit from worktree (allowed)" "Bash" "git commit -m test" "/tmp/test-worktree" 0
test_hook "Git add from worktree (allowed)" "Bash" "git add file.txt" "/tmp/test-worktree" 0

# Cleanup
rm -rf /tmp/test-worktree

# Test 5: Non-Bash tools should pass
test_hook "Edit tool (not Bash)" "Edit" "git commit" "/any/directory" 0
test_hook "Write tool (not Bash)" "Write" "git push" "/any/directory" 0

echo
echo "======================="
echo -e "Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
echo

if [[ $FAIL -gt 0 ]]; then
  exit 1
else
  exit 0
fi
