# workarea-tasks

List available workspaces (from root) or tasks (from within a workspace).

## Usage

```
/workarea-tasks
```

No arguments required - behavior depends on current location.

## Purpose

Provides an overview of workspaces and tasks, helping you:
- See available workspaces when at root
- See tasks within a workspace
- Choose which task to work on
- Quickly resume work

**Best Practice:** Run this command at the start of each session.

## Instructions

When this command is invoked:

### 1. Execute list-tasks script

Run `./bin/list-tasks.sh` to display workspaces or tasks.

The script automatically detects context:
- **At workarea root**: Shows available workspaces
- **Inside a workspace**: Shows tasks in that workspace

### 2. Handle the output based on context

#### If showing workspaces (not in a workspace):

```
=== Available Workspaces ===

1. default
   4 task(s)
   Migrated from original workarea structure

2. temporal
   2 task(s)
   Temporal SDK development

Commands:
  cd workspaces/<name>      - Navigate to a workspace
  /new-workspace <name>     - Create a new workspace
```

**Action:** Present workspace selection:
- List all workspaces with task count
- Add "Create new workspace" option
- After selection: Navigate to workspace and run `/workarea-tasks` again

#### If showing tasks (in a workspace):

```
=== Tasks in workspace: default ===

1. 🔴 my-feature
   PR #123
   Implement new feature...
   Status: CI Failing | Last updated: 1h ago

2. 🟡 feature-auth
   New feature...
   Status: In Progress | Last updated: 1d ago
```

**Action:** Present task selection:
- List all task names with status
- Add "Create new task" option
- Add "Skip (just browsing)" option
- After selection: Execute `/resume-task <task-name>`

### 3. Handle selection

**For workspace selection:**
- Navigate: `cd workspaces/<selected>`
- Then run `/workarea-tasks` again to show tasks

**For task selection:**
- If task selected: Execute `/resume-task <task-name>`
- If "Create new task": Execute `/new-task` and prompt for details
- If "Skip": Just show the list and exit

### 4. After resuming task

- Navigate to task directory
- Show git status
- Display quick status from TASK_STATUS.md
- Suggest next steps

## Example Interactions

### Example 1: From Workarea Root

```
User: /workarea-tasks

Claude: [Runs ./bin/list-tasks.sh from workarea root]

=== Available Workspaces ===

1. default
   4 task(s)
   Migrated from original workarea structure

2. temporal
   2 task(s)
   Temporal SDK development

Which workspace would you like to use?

Options:
1. default (4 tasks)
2. temporal (2 tasks)
3. Create new workspace
4. Skip

User: 1

Claude: Navigating to workspace: default
cd workspaces/default

[Runs ./bin/list-tasks.sh again]

=== Tasks in workspace: default ===

1. 🔴 my-feature
   PR #123
   Implement new feature...
   Status: CI Failing | Last updated: 1h ago

2. 🟡 feature-auth
   Status: In Progress | Last updated: 1d ago

Which task would you like to work on?
```

### Example 2: From Within Workspace

```
User: /workarea-tasks

Claude: [Runs ./bin/list-tasks.sh from workspaces/default]

=== Tasks in workspace: default ===

1. 🔴 my-feature
   PR #123
   Implement new feature...
   Status: CI Failing | Last updated: 1h ago

Which task would you like to work on?

Options:
1. my-feature (🔴 CI Failing - needs attention)
2. Create new task
3. Skip (just browsing)

User: 1

Claude: Resuming task: my-feature
[Executes /resume-task my-feature]
```

### Example 3: No Workspaces Found

```
User: /workarea-tasks

Claude: [Runs ./bin/list-tasks.sh]

=== Available Workspaces ===

No workspaces found.

Create your first workspace:
  /new-workspace <name>

Example:
  /new-workspace personal
  /new-workspace work

Would you like to create a workspace now? I'll run /new-workspace for you.
```

## Status Indicators

| Indicator | Meaning | Detection |
|-----------|---------|-----------|
| 🔴 | CI Failing | "❌" or "FAILED" in TASK_STATUS.md |
| 🟡 | In Progress | "Investigation", "WIP", "TODO" present |
| 🟢 | Passing/Done | "✅" or "PASSING" or "completed" |
| ⚪ | Unknown | Can't determine from TASK_STATUS.md |

## Smart Recommendations

When showing tasks, suggest priority based on:
1. **Failing CI** - Highest priority
2. **Recent activity** - You were just working on it
3. **Blockers** - Has "BLOCKED" in status
4. **Oldest task** - Been sitting for a while

## Related Commands

- `/new-workspace` - Create a new workspace
- `/new-task` - Create a new task (must be in workspace)
- `/resume-task` - Resume a specific task (must be in workspace)

## Workflow

```bash
cd workarea
/workarea-tasks          # Shows workspaces
# Select workspace
cd workspaces/<name>
/workarea-tasks          # Shows tasks
# Select task to work on
```
