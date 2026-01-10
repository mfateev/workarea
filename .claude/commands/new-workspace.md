# new-workspace

Create a new workspace for organizing related tasks.

## Usage

```
/new-workspace <workspace-name> [description]
```

## Examples

```
/new-workspace personal "My personal open source projects"
/new-workspace work "Work-related tasks and PRs"
/new-workspace temporal "Temporal SDK development"
/new-workspace bugfixes
```

## Instructions

When this command is invoked:

1. **Parse the input**
   - Extract workspace name (required)
   - Extract description (optional, defaults to "Workspace for <name>")

2. **Validate workspace name**
   - Must be lowercase letters, numbers, and dashes only
   - Cannot start or end with a dash
   - Examples of valid names: `personal`, `work-tasks`, `sdk`, `my-project`
   - Examples of invalid names: `Work`, `my_project`, `-test`, `test-`

3. **Check if workspace already exists**
   - Look in `workspaces/<name>`
   - If exists, inform user and suggest alternatives

4. **Execute the creation script**
   - Run: `./bin/new-workspace.sh <name> "<description>"`
   - The script creates:
     - `workspaces/<name>/` directory
     - `workspaces/<name>/tasks/` for active tasks
     - `workspaces/<name>/archived/` for completed tasks
     - `workspaces/<name>/bin` symlink to `../../bin`
     - `workspaces/<name>/README.md` with workspace info
     - `workspaces/<name>/archived/README.md` for task history

5. **Confirm creation and show next steps**
   - Display the created structure
   - Navigate to the new workspace directory
   - Suggest creating a task with `/new-task`

## Example Interaction

```
User: /new-workspace temporal "Temporal SDK development"

Claude: Creating workspace: temporal

Running setup...

  Created: workspaces/temporal/
  Created: workspaces/temporal/tasks/
  Created: workspaces/temporal/archived/
  Created: workspaces/temporal/bin -> ../../bin
  Created: workspaces/temporal/README.md
  Created: workspaces/temporal/archived/README.md

Workspace ready!

Structure:
  workspaces/temporal/
  ├── bin -> ../../bin     # Shared scripts
  ├── tasks/               # Your tasks go here
  ├── archived/            # Completed tasks
  └── README.md

Next steps:
  cd workspaces/temporal
  /new-task https://github.com/org/repo/pull/123
```

## Notes

- **Isolation**: Each workspace has its own tasks/ and archived/ directories
- **Shared repos**: All workspaces share the same `repos/` directory at the workarea root
- **Gitignored**: Workspace contents are gitignored (local only)
- **Portable tooling**: The `bin` symlink ensures scripts work from within the workspace
- **Multiple workspaces**: You can create as many workspaces as needed for different projects or purposes
