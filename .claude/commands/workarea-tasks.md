# workarea-tasks

List all available tasks in the workarea with their status and details.

## Usage

```
/workarea-tasks
```

No arguments required - shows all tasks.

## Purpose

Provides an overview of all tasks in the workarea, helping you:
- See what work is in progress
- Choose which task to work on
- Understand task context at a glance
- Quickly resume work

**Best Practice:** Run this command at the start of each session to choose which task to work on.

## Instructions

When this command is invoked:

1. **Execute list-tasks script**
   - Run `./bin/list-tasks.sh` to display all tasks
   - This shows:
     - Task number and name
     - Status indicator (🔴 failing, 🟡 in progress, 🟢 passing, ⚪ unknown)
     - Description from task.json
     - PR number and URL if applicable
     - Last updated time (relative: "1h ago", "2d ago")
     - Available commands

2. **Ask user to select a task**
   - Present multiple choice question:
     - List all task names from the output
     - Add "Create new task" option
     - Add "Skip (just browsing)" option
   - Example options:
     1. async-await (🔴 CI Failing - PR #2751)
     2. feature-auth (🟡 In Progress)
     3. Create new task
     4. Skip

3. **Handle selection**
   - If task selected: Execute `/resume-task <task-name>`
   - If "Create new task": Execute `/new-task` and prompt for details
   - If "Skip": Just show the list and exit

4. **After resuming task**
   - Navigate to task directory
   - Show git status
   - Display quick status from TASK_STATUS.md (first 10 lines)
   - Suggest next steps

## Example Interaction

```
User: /workarea-tasks

Claude: [Runs ./bin/list-tasks.sh]

=== Available Tasks ===

1. 🔴 async-await
   PR #2751
   Add Async.await() for non-blocking condition wa...
   Status: CI Failing | Last updated: 1h ago
   https://github.com/temporalio/sdk-java/pull/2751

2. 🟡 feature-auth
   New feature
   Implement user authentication with JWT tokens
   Status: In Progress | Last updated: 1d ago

Commands:
  /resume-task <task-name>  - Restore and work on a task
  /new-task <description>   - Create a new task

Which task would you like to work on?

Options:
1. async-await (🔴 CI Failing - needs attention)
2. feature-auth (🟡 In Progress)
3. Create new task
4. Skip (just browsing)

User: 1

Claude: Resuming task: async-await

[Executes /resume-task async-await]

✓ Repository restored: repos/sdk-java
✓ Fork remote: mfateev
✓ Worktree ready: tasks/async-await/sdk-java

Task Status Preview:
> # Task Status: Async.await() PR #2751
>
> **CI Status:** ❌ 1 FAILING CHECK
> - MetricsTest::testUnhandledCommand
>   Expected: 1, Got: 2
>
> **Next Steps:**
> - Investigate why metrics count is 2 instead of 1
> - Check if Async.await() creates additional metrics

Ready to work! Location: tasks/async-await/sdk-java
```

## Display Format Options

### Compact View (default)
```
Tasks (3 active):
1. 🔴 async-await          [PR #2751] Add Async.await()...          2h ago
2. 🟡 feature-auth         [New] Implement user auth...             1d ago
3. 🟢 fix-pagination       [Done] Fix pagination bug...             3d ago
```

### Detailed View (with `-v` or when few tasks)
Shows full details with CI status, repositories, and next steps.

## Status Indicators

Parse TASK_STATUS.md to determine status:

| Indicator | Meaning | Detection |
|-----------|---------|-----------|
| 🔴 | CI Failing | "❌" or "FAILED" or "failing" in CI section |
| 🟡 | In Progress | "Investigation", "WIP", "TODO" present |
| 🟢 | Passing/Done | "✅" or "PASSING" or "completed" |
| ⚪ | Unknown | Can't determine from TASK_STATUS.md |

## Smart Recommendations

Suggest which task to work on based on:
1. **Failing CI** - Highest priority (needs fixing)
2. **Recent activity** - You were just working on it
3. **Blockers** - Has "BLOCKED" or "waiting" in status
4. **Oldest task** - Been sitting for a while

## No Tasks Found

```
User: /workarea-tasks

Claude: No tasks found in workarea.

You can:
1. Start a new task: /new-task <description or PR URL>
2. Clone an existing task from another machine (see CROSS_MACHINE_WORKFLOW.md)

Example:
  /new-task https://github.com/org/repo/pull/123
```

## Integration with Startup

**Recommended Setup:**
Add to your shell profile or create a reminder to run `/workarea-tasks` when starting work:

```bash
# In ~/.zshrc or ~/.bashrc
alias work="cd /Users/maxim/ai/workarea && echo 'Run /workarea-tasks to see available work'"
```

**Or create a startup message:**
The command could be configured to run automatically when:
- Starting Claude Code in the workarea directory
- Running `claude` CLI in workarea
- Using a custom hook or alias

## Error Handling

### Missing task.json
```
Task "old-task" is missing configuration (task.json not found).
This may be an old task. Options:
  - Skip this task (it won't be restored)
  - Delete: rm -rf tasks/old-task
  - Manually inspect: cat tasks/old-task/TASK_STATUS.md
```

### Corrupted task.json
```
Warning: task.json is invalid for "broken-task"
Error: JSON parse error at line 5
Skipping this task in list.
```

### Empty tasks directory
```
No tasks found. Start with: /new-task
```

## Advanced Features

### Filtering
```
/workarea-tasks --failing    # Show only tasks with failing CI
/workarea-tasks --active     # Show only in-progress tasks
/workarea-tasks --recent     # Show tasks modified in last 7 days
```

### Sorting
```
/workarea-tasks --sort date       # Sort by last modified
/workarea-tasks --sort name       # Sort alphabetically
/workarea-tasks --sort status     # Sort by status (failing first)
```

### Search
```
/workarea-tasks auth             # Show tasks matching "auth"
/workarea-tasks pr:2751          # Show task for PR #2751
```

## Related Commands

- `/new-task` - Create a new task
- `/resume-task` - Resume a specific task
- `/workarea-tasks` - List and choose tasks (this command)

## Implementation Notes

### Performance
- Cache task.json parsing (read once, use many times)
- Limit TASK_STATUS.md preview to first 50 lines
- Show progress indicator for scanning many tasks

### Extensibility
Could be enhanced with:
- GitHub API integration to show real-time CI status
- Task completion percentage
- Estimated time to complete (based on commits)
- Collaboration indicators (who else worked on this)

### Data Sources
Aggregates information from:
1. `tasks/*/task.json` - Configuration
2. `tasks/*/TASK_STATUS.md` - Human notes and status
3. File modification times - Last activity
4. Git history in worktrees (if present) - Commit activity

## Workflow Integration

**Daily workflow:**
```bash
# Morning: Start work session
cd ~/ai/workarea
/workarea-tasks              # See what's available
# Select task #1
# ... work happens ...

# Afternoon: Check other tasks
/workarea-tasks              # Quick status check
# Maybe switch to different task

# Evening: Update status before ending
vim tasks/current-task/TASK_STATUS.md
git add tasks/current-task/TASK_STATUS.md
git commit -m "EOD: Updated task status"
git push
```

This command becomes your **work dashboard** for managing multiple ongoing tasks!
