# Directory Structure Validation Hook

## Purpose

Enforces the workarea directory architecture, preventing Claude from creating directories or cloning repositories in unauthorized locations.

## What It Validates

The hook runs before every Bash command and validates:

### 1. Git Clone Location
- ✅ **Allowed**: Clone only into `repos/` directory
- ❌ **Blocked**: Cloning into workspaces/, tasks/, or workarea root

```bash
# Correct
git clone https://github.com/org/repo.git repos/repo

# Wrong
git clone https://github.com/org/repo.git repo           # workarea root
git clone https://github.com/org/repo.git workspaces/repo  # workspaces
```

### 2. Root Directory Creation
- ✅ **Allowed**: Only `workspaces/` and `repos/` directories at root
- ❌ **Blocked**: Any other directories at workarea root level

```bash
# Correct
mkdir workspaces  # OK
mkdir repos       # OK
mkdir bin/utils   # OK (subdirectory)

# Wrong
mkdir tasks       # NOT allowed at root
mkdir projects    # NOT allowed at root
```

### 3. Git Init Location Restrictions
- ✅ **Allowed**: git init in `repos/<repo>/` subdirectories (specific repositories)
- ✅ **Allowed**: git init in `workspaces/<name>/` (workspace directories, for metadata)
- ❌ **Blocked**: git init in `repos/` container itself
- ❌ **Blocked**: git init in `workspaces/` container itself
- ❌ **Blocked**: git init in task directories (must use worktrees)
- ❌ **Blocked**: git init at workarea root

```bash
# Correct
mkdir repos/sdk-java && cd repos/sdk-java && git init  # Initialize specific repo
cd workspaces/issues && git init                        # Initialize workspace

# Wrong - containers are not repositories
cd repos && git init                        # Blocked - repos/ is a container
cd workspaces && git init                   # Blocked - workspaces/ is a container

# Wrong - tasks must use worktrees
cd workspaces/issues/tasks && git init                    # Blocked
cd workspaces/issues/tasks/my-task && git init            # Blocked
cd workspaces/issues/tasks/my-task/sdk-java && git init   # Blocked

# To work in tasks, use worktrees:
git clone <url> repos/sdk-java
git -C repos/sdk-java worktree add workspaces/issues/tasks/my-task/sdk-java
```

### 4. Workspace Git Repository
- ✅ **Allowed**: git init/clone in workspace directories
- ✅ **Allowed**: git operations in initialized workspaces
- ❌ **Blocked**: git operations in uninitialized workspaces
- ❌ **Blocked**: git operations in workspaces/ container itself

```bash
# Correct
cd workspaces/issues && git init    # Initialize workspace
cd workspaces/issues && git commit  # Commit to initialized workspace

# Wrong
cd workspaces && git init          # In container, not workspace
cd workspaces/issues && git commit # If not initialized yet
```

## Architecture Enforced

```
workarea/                          ← Workarea root
├── bin/                          ✅ Tracked: Scripts
├── .claude/                      ✅ Tracked: Configuration
├── repos/                        ✅ Gitignored: Shared clones ONLY
│   ├── sdk-java/                ✅ OK here
│   └── frontend/                ✅ OK here
├── workspaces/                   ✅ Container (tracked: .gitkeep)
│   ├── issues/                  ✅ Workspace (must be git repo)
│   │   ├── .git/                ✅ Required
│   │   └── tasks/
│   └── projects/                ✅ Workspace (must be git repo)
│       ├── .git/                ✅ Required
│       └── tasks/
├── tasks/                        ❌ NOT allowed at root
├── projects/                     ❌ NOT allowed at root
└── random-dir/                   ❌ NOT allowed at root
```

## Example Blocked Operations

### Example 1: Clone to wrong location

```bash
$ git clone https://github.com/org/sdk-java.git sdk-java

🛑 Directory Structure Check: Clone target violates architecture!

You're trying to clone a repository outside the 'repos/' directory:
  Command: git clone https://github.com/org/sdk-java.git sdk-java
  Target: /workarea/sdk-java

Workarea architecture requires:
  ✅ Correct: Clone repositories into repos/
     Example: git clone <url> repos/sdk-java

  ❌ Wrong: Cloning into workspaces, tasks, or workarea root
     Current: /workarea/sdk-java

To fix: Specify the target as 'repos/<repo-name>'
```

### Example 2: Create unauthorized directory at root

```bash
$ mkdir tasks

🛑 Directory Structure Check: Invalid directory at workarea root!

You're trying to create/modify a directory at workarea root:
  Command: mkdir tasks
  Target: /workarea/tasks

Workarea root ONLY allows these directories:
  ✅ workspaces/  - Container for workspace repositories
  ✅ repos/       - Shared git repository clones

  ❌ tasks/       - Not allowed at root level

To fix: Use /new-workspace to create workspaces
```

### Example 3: Git operations in uninitialized workspace

```bash
$ cd workspaces/new-workspace
$ git commit -m "test"

🛑 Directory Structure Check: Workspace is not a git repository!

You're trying to run git commands in a workspace that's not initialized:
  Workspace: /workarea/workspaces/new-workspace
  Command: git commit -m "test"

Workspaces MUST be git repositories to track task metadata.

To fix:
  1. Initialize workspace: git init && git remote add origin <url>
  2. Or use /clone-workspace to clone an existing workspace
```

### Example 4: git init in repos/ container

```bash
$ cd repos
$ git init

🛑 Directory Structure Check: git init not allowed in repos/ container!

You're trying to initialize a git repository in the repos/ container:
  Directory: /workarea/repos
  Command: git init

The repos/ directory is just a container for repository clones.

Allowed locations for git init:
  ✅ repos/<repo>/       - Inside a specific repository directory
  ✅ workspaces/<name>/  - For workspace metadata tracking

  ❌ repos/              - Container directory (not a repository)

To initialize a repository:
  1. Create repository directory: mkdir repos/<repo>
  2. Navigate into it: cd repos/<repo>
  3. Initialize: git init
```

### Example 5: git init in task directory

```bash
$ cd workspaces/issues/tasks/my-task/sdk-java
$ git init

🛑 Directory Structure Check: git init not allowed in task directories!

You're trying to initialize a git repository inside a task directory:
  Directory: /workarea/workspaces/issues/tasks/my-task/sdk-java
  Command: git init

Task directories should ONLY use git worktrees, never initialize repos.

Allowed locations for git init:
  ✅ repos/              - For main repository clones
  ✅ repos/<repo>/       - Inside a repository
  ✅ workspaces/<name>/  - For workspace metadata tracking

  ❌ workspaces/<name>/tasks/               - Tasks container
  ❌ workspaces/<name>/tasks/<task>/        - Task root
  ❌ workspaces/<name>/tasks/<task>/<repo>/ - Worktree location

To work in a repository:
  1. Clone to repos/: git clone <url> repos/sdk-java
  2. Use /resume-task to create worktrees in task directories

Worktrees link to repos/ and should be created with:
  git worktree add <path> <branch>
```

### Example 6: Git operations in workspaces container

```bash
$ cd workspaces
$ git init

🛑 Directory Structure Check: Git operation in workspaces container!

You're trying to run git commands in the workspaces/ container:
  Directory: /workarea/workspaces
  Command: git init

The workspaces/ directory is just a container. Git operations should happen:
  ✅ In specific workspaces: workspaces/<name>/
  ❌ Not in the container: workspaces/

To fix:
  1. Navigate to a specific workspace: cd workspaces/<name>
  2. Or create a new workspace: /new-workspace <name>
```

## Configuration

The hook is registered in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/directory-structure-check.sh",
            "statusMessage": "Validating directory structure..."
          },
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/git-safety-check.sh",
            "statusMessage": "Validating git operation..."
          }
        ]
      }
    ]
  }
}
```

## Testing

Run the test suite:

```bash
./.claude/hooks/test-directory-structure.sh
```

Test coverage includes:
- Git clone to various locations (4 tests)
- Directory creation at root (5 tests)
- Workspace git validation (4 tests)
- Non-Bash tools (2 tests)
- Operations outside workarea (2 tests)
- Safe operations (3 tests)
- Move/copy operations (3 tests)
- Git init location validation (7 tests)
  - repos/ container (blocked)
  - repos/<repo>/ (allowed)
  - workspaces/<name>/ (allowed)
  - workspaces/ container (blocked)
  - tasks directories (blocked)
  - workarea root (blocked)

**Total: 30 test scenarios, all passing ✅**

## How It Works

1. **Detects workarea root** by looking for `CLAUDE.md` and `bin/` directory
2. **Skips validation** if not in a workarea (allows normal operations elsewhere)
3. **Analyzes commands** for git clone, mkdir, mv, cp operations
4. **Validates paths** against allowed directory structure
5. **Blocks with exit 2** for violations
6. **Allows with exit 0** for compliant operations

## Interaction with Git Safety Hook

This hook runs **before** the git safety hook:

1. **directory-structure-check.sh** - Validates architecture (where things are)
2. **git-safety-check.sh** - Validates git operations (what you're doing)

Both hooks run in sequence for complete validation.

## Related Documentation

- [git-safety-check.sh](./README.md) - Git operation validation
- [CLAUDE.md](../CLAUDE.md) - Workarea architecture overview
- [Hooks Guide](https://code.claude.com/docs/en/hooks-guide.md) - Claude Code hooks
