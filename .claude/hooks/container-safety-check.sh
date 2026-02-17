#!/bin/bash
# Container Safety Hook - Blocks destructive container operations without explicit user approval
#
# Destructive operations (rm, delete, stop, prune, kill) destroy container state
# including cloned repos, build artifacts, and uncommitted work that isn't on
# a mounted volume. This hook blocks these operations so the user is prompted.

# Read hook input from stdin
INPUT=$(cat)

# Extract relevant fields
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only validate Bash tool container commands
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

# Check if the command starts with 'container ' (the CLI tool, not just the word in a string)
if [[ ! "$COMMAND" =~ ^container[[:space:]] ]]; then
  exit 0
fi

# Allow safe read-only and non-destructive commands
if echo "$COMMAND" | grep -qE '^container (list|ls|inspect|stats|exec|logs|image|build|run|create|start|network|volume|registry|builder|system|--help|-h)'; then
  exit 0
fi

# Block destructive commands
if echo "$COMMAND" | grep -qE '^container (rm|delete|stop|kill|prune)'; then
  # Extract container name if present
  CONTAINER_NAME=$(echo "$COMMAND" | grep -oE '(rm|delete|stop|kill)\s+\S+' | awk '{print $2}')

  case "$COMMAND" in
    *prune*)
      cat >&2 <<EOF
BLOCKED: container prune removes ALL stopped containers!

This will destroy all data inside stopped containers (repos, build artifacts,
uncommitted work) that is not on a mounted volume.

If you want to proceed, ask the user for explicit approval first.
EOF
      exit 2
      ;;
    *rm*|*delete*)
      cat >&2 <<EOF
BLOCKED: container rm/delete destroys the container and all its data!

  Command: $COMMAND
  Container: ${CONTAINER_NAME:-unknown}

This will permanently destroy everything inside the container that is not
on a mounted volume, including:
  - Cloned repositories and uncommitted changes
  - Build artifacts and caches
  - Installed packages and tools (beyond the base image)

If you want to proceed, ask the user for explicit approval first.
EOF
      exit 2
      ;;
    *stop*)
      cat >&2 <<EOF
BLOCKED: container stop halts the container.

  Command: $COMMAND
  Container: ${CONTAINER_NAME:-unknown}

The container can be restarted with 'container start', but verify with
the user before stopping as it interrupts any running processes.

If you want to proceed, ask the user for explicit approval first.
EOF
      exit 2
      ;;
    *kill*)
      cat >&2 <<EOF
BLOCKED: container kill forcefully terminates the container!

  Command: $COMMAND
  Container: ${CONTAINER_NAME:-unknown}

This is more aggressive than 'stop' and may corrupt in-progress writes.

If you want to proceed, ask the user for explicit approval first.
EOF
      exit 2
      ;;
  esac
fi

# Allow everything else
exit 0
