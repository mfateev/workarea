#!/bin/bash
# E2E Test Gate Hook - Blocks git push unless E2E tests passed for current HEAD
#
# Reads the .e2e-passed marker file (written by TestMain on success) and
# compares the recorded SHA to the current HEAD. If they don't match or the
# file is missing, the push is blocked.
#
# Repos without an e2e/ directory are allowed through (non-E2E projects).

# Read hook input from stdin
INPUT=$(cat)

# Extract relevant fields
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Only activate on Bash tool with git push commands
if [[ "$TOOL_NAME" != "Bash" ]] || ! echo "$COMMAND" | grep -qE '^git push'; then
  exit 0
fi

# Find the git repo root
GIT_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$GIT_ROOT" ]]; then
  exit 0  # Not in a git repo, let other hooks handle it
fi

# Skip repos that don't have an e2e/ directory (non-E2E projects)
if [[ ! -d "$GIT_ROOT/e2e" ]]; then
  exit 0
fi

MARKER="$GIT_ROOT/.e2e-passed"
HEAD_SHA=$(git -C "$CWD" rev-parse HEAD 2>/dev/null)

# Check if marker exists
if [[ ! -f "$MARKER" ]]; then
  cat >&2 <<EOF
🛑 E2E Test Gate: Push blocked — no E2E test record found!

No .e2e-passed marker exists in: $GIT_ROOT

E2E tests must pass before pushing. Run them with:
  cd $GIT_ROOT
  go test -v ./e2e/...

The test suite will write .e2e-passed on success.
EOF
  exit 2
fi

# Check if marker SHA matches current HEAD
MARKER_SHA=$(tr -d '[:space:]' < "$MARKER")

if [[ "$MARKER_SHA" != "$HEAD_SHA" ]]; then
  cat >&2 <<EOF
🛑 E2E Test Gate: Push blocked — E2E tests are stale!

The .e2e-passed marker records SHA: $MARKER_SHA
But current HEAD is:               $HEAD_SHA

You've made commits since the last successful E2E run.
Re-run the tests:
  cd $GIT_ROOT
  go test -v ./e2e/...
EOF
  exit 2
fi

# SHA matches — E2E tests passed for this commit
exit 0
