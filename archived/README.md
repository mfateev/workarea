# Archived Tasks

This folder contains completed tasks for historical reference and activity tracking.

## Purpose

- Track completed work over time
- Generate activity reports for specific time periods
- Maintain context for future reference
- Document what was accomplished and when

## Task Archive

| Task | Overview | Started | Completed | PR/Issue |
|------|----------|---------|-----------|----------|
| [metricstest-flake](metricstest-flake/) | Fix flaky MetricsTest.testUnhandledCommand - test server not matching real server behavior for UNHANDLED_COMMAND | 2026-01-06 | 2026-01-07 | [PR #2757](https://github.com/temporalio/sdk-java/pull/2757) |
<!-- New entries added above this line -->

## Usage

### Generating Activity Reports

To see what was done in a specific time period:

```bash
# List tasks completed in January 2026
grep "2026-01" archived/README.md

# View details of a specific archived task
cat archived/<task-name>/TASK_STATUS.md
```

### Archive Entry Format

When archiving a task, add a row to the table above with:
- **Task**: Task folder name (linked to folder)
- **Overview**: Brief description (1-2 sentences)
- **Started**: Date from task.json `created` field
- **Completed**: Date task was archived
- **PR/Issue**: Link to PR or issue (if applicable)

---

*This archive is maintained automatically by Claude Code when tasks are completed.*
