#!/bin/bash
# PR Base Check Hook - Blocks PR creation if branch is not based on latest main
#
# Prevents creating PRs from branches whose merge-base with main doesn't match
# main's HEAD. This avoids history divergence between the branch and main.
#
# The user should merge or rebase onto main before creating a PR.

# Read hook input from stdin
INPUT=$(cat)

# Extract relevant fields
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Only activate on Bash tool with gh pr create commands
if [[ "$TOOL_NAME" != "Bash" ]] || ! echo "$COMMAND" | grep -qE 'gh pr create'; then
  exit 0
fi

# Find the git repo root
GIT_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$GIT_ROOT" ]]; then
  exit 0  # Not in a git repo
fi

# Determine the main branch name (main or master)
MAIN_BRANCH=""
for candidate in main master; do
  if git -C "$GIT_ROOT" rev-parse --verify "$candidate" &>/dev/null; then
    MAIN_BRANCH="$candidate"
    break
  fi
done

if [[ -z "$MAIN_BRANCH" ]]; then
  # No main/master branch found — skip check (might be a repo without one)
  exit 0
fi

# Get current branch
CURRENT_BRANCH=$(git -C "$GIT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)
if [[ "$CURRENT_BRANCH" == "$MAIN_BRANCH" ]]; then
  # Creating PR from main itself — skip check
  exit 0
fi

# Fetch latest main from remote to ensure we're comparing against up-to-date state
git -C "$GIT_ROOT" fetch origin "$MAIN_BRANCH" --quiet 2>/dev/null

# Use origin/main as the reference (latest remote state)
MAIN_HEAD=$(git -C "$GIT_ROOT" rev-parse "origin/$MAIN_BRANCH" 2>/dev/null)
if [[ -z "$MAIN_HEAD" ]]; then
  # No remote main — fall back to local main
  MAIN_HEAD=$(git -C "$GIT_ROOT" rev-parse "$MAIN_BRANCH" 2>/dev/null)
  if [[ -z "$MAIN_HEAD" ]]; then
    exit 0  # Can't determine main HEAD, let it through
  fi
fi

# Get the merge base between current branch and main
MERGE_BASE=$(git -C "$GIT_ROOT" merge-base HEAD "$MAIN_HEAD" 2>/dev/null)
if [[ -z "$MERGE_BASE" ]]; then
  cat >&2 <<EOF
🛑 PR Base Check: Push blocked — no common ancestor with $MAIN_BRANCH!

Cannot find a merge-base between HEAD and origin/$MAIN_BRANCH.
The branch may have been created from an unrelated history.
EOF
  exit 2
fi

# Check if merge base matches main HEAD
if [[ "$MERGE_BASE" != "$MAIN_HEAD" ]]; then
  BEHIND_COUNT=$(git -C "$GIT_ROOT" rev-list --count "$MERGE_BASE".."$MAIN_HEAD" 2>/dev/null)
  cat >&2 <<EOF
🛑 PR Base Check: PR creation blocked — branch is not based on latest $MAIN_BRANCH!

Branch:     $CURRENT_BRANCH
Merge base: ${MERGE_BASE:0:12}
Main HEAD:  ${MAIN_HEAD:0:12} (origin/$MAIN_BRANCH)
Behind by:  $BEHIND_COUNT commit(s)

Your branch diverged from $MAIN_BRANCH. Merge main into your branch first:

  git merge origin/$MAIN_BRANCH

Then retry creating the PR.
EOF
  exit 2
fi

# Merge base matches main HEAD — branch is properly based
exit 0
