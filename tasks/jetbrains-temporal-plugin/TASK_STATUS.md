# Task Status: JetBrains Temporal Plugin

## Task Overview
- **Goal**: Create a JetBrains plugin for Temporal.io
- **Phase**: Design complete, ready for Phase 1 implementation
- **Repository**: https://github.com/mfateev/temporal-intellij-plugin (private)

## Current Status
- [x] Project structure created with Gradle
- [x] IntelliJ Platform Gradle Plugin 2.2.1 configured
- [x] Hello World action implemented
- [x] Build successful
- [x] Test running in IDE sandbox - **VERIFIED WORKING**
- [x] Create GitHub repository
- [x] Temporal tool window with logo
- [x] Dark/light theme icon support
- [x] Server connection settings UI
- [x] Test Connection functionality (in Settings dialog)
- [x] **Design proposal completed** (docs/PLUGIN_PROPOSAL.md)
- [x] **Phase 1: Workflow Execution Inspector** - COMPLETE
- [x] **Automated UI Testing** - Remote-Robot setup working
- [x] **Workflow ID Picker** - Browse recent workflows dialog
- [x] **Phase 2: Event History + Query execution** - COMPLETE
- [x] **Auto-Refresh** - Automatic workflow updates with configurable interval
- [x] **Tabbed UI** - Separate tabs for Overview, History, and Query
- [x] **Tree-based Event History** - Expandable events with details
- [x] Phase 3: Stack trace view (in Query tab)
- [ ] Phase 4: Polish (payload decoding, more filters)

## Features Implemented

### 1. Tool Window (Right Sidebar)
- Temporal logo icon (dark/light theme support)
- Workflow Inspector as main content
- Connection status bar at bottom (address, namespace, TLS indicator)
- "Settings" button for quick access to configuration

### 2. Settings (Preferences > Tools > Temporal)
- **Connection Settings:**
  - Server address (default: localhost:7233)
  - Namespace (default: "default")
  - API Key (password field)
- **TLS Settings:**
  - Enable TLS checkbox
  - Client certificate path
  - Client key path
  - Server CA certificate path
  - Server name override
  - Disable host verification
- "Test Connection" button with progress dialog

### 3. Test Connection
- Uses Temporal SDK GetSystemInfo API
- Shows server version on success
- Detailed error messages for common failures:
  - Server unavailable
  - Authentication failed
  - Permission denied
  - Connection timeout

### 4. Workflow Execution Inspector (Phase 1)
- **Workflow ID Input**: Enter workflow ID to inspect
- **Browse Button [...]**: Opens dialog showing recent workflows for selection
- **Inspect Button**: Load workflow execution details
- **Execution Info Panel**:
  - Workflow ID and Run ID
  - Execution status (Running/Completed/Failed/etc.)
  - Task Queue
  - Workflow Type
  - Start Time
  - Close Time (if completed)
- **Pending Activities Panel**:
  - Activity ID and Type
  - Current Attempt
  - Last Heartbeat Time
  - Scheduled/Started/Last Failure timestamps
  - Last Failure Message (if any)
- **WorkflowService**: Encapsulates gRPC calls to Temporal

### 5. Tabbed UI Layout
- **Overview Tab**: Execution info, pending activities, pending children
- **History Tab**: Event history with expandable tree
- **Query Tab**: Query execution and stack trace

### 6. Event History Tree (Phase 2)
- **Expandable Tree Nodes**: Click events to see details (input, result, failure, etc.)
- **Event Filtering**: Filter by category (All, Workflow, Activity, Timer, Signal, Child Workflow)
- **Color-Coded Event Types**: Visual distinction by event category
- **Millisecond Timestamps**: Precise timing for each event
- **Pagination Support**: API supports loading more events

### 7. Query Execution Panel (Phase 2)
- **Custom Query Execution**: Enter query type and JSON arguments
- **Stack Trace Button**: Quick access to `__stack_trace` built-in query
- **Result Display**: Formatted JSON output with pretty-printing
- **Status Indicators**: Success/error feedback

### 8. Auto-Refresh (Phase 4)
- **Toggle Checkbox**: Enable/disable automatic updates
- **Configurable Interval**: 3s, 5s, 10s, or 30s refresh rates
- **Silent Updates**: Background refresh without progress dialogs
- **Last Refresh Timestamp**: Shows when data was last updated
- **Automatic Cleanup**: Timer stops on dispose or error

### 9. Automated UI Testing
- **Remote-Robot Framework**: JetBrains UI testing library (v0.11.23)
- **Test Setup**:
  - Start IDE: `./gradlew runIdeForUiTests`
  - Run Tests: `./gradlew uiTest`
  - Tests FAIL (not skip) when IDE not running
- **Test Files**:
  - `BaseUiTest.kt` - Base class with IDE connection
  - `IdeInspector.kt` - Utility for inspecting IDE state
  - `IdeInspectorTest.kt` - Verifies plugin is loaded
  - `TemporalToolWindowTest.kt` - Tests tool window UI
  - `UiFixtures.kt` - Custom fixtures for Temporal components
- **JDK17 Fix**: Uses `--add-opens` JVM argument for GSON/Retrofit

## Project Structure
```
temporal-intellij-plugin/
├── build.gradle.kts              # Gradle build + Temporal SDK 1.27.0
├── settings.gradle.kts
├── gradle.properties
├── gradlew / gradlew.bat
├── testProject/                  # Test project for UI tests
└── src/
    ├── main/kotlin/io/temporal/intellij/
    │   ├── HelloWorldAction.kt
    │   ├── TemporalIcons.kt
    │   ├── settings/
    │   │   ├── TemporalSettings.kt
    │   │   ├── TemporalSettingsConfigurable.kt
    │   │   └── TemporalConnectionTester.kt
    │   ├── toolwindow/
    │   │   ├── TemporalToolWindowFactory.kt
    │   │   └── TemporalToolWindowPanel.kt
    │   └── workflow/
    │       ├── WorkflowService.kt             # gRPC API calls
    │       ├── WorkflowInspectorPanel.kt      # Main inspector UI (tabbed)
    │       ├── WorkflowChooserDialog.kt       # Browse workflows dialog
    │       ├── EventHistoryTreePanel.kt       # Tree-based event history
    │       └── QueryPanel.kt                  # Query execution
    ├── main/resources/
    │   ├── META-INF/plugin.xml
    │   └── icons/
    └── test/kotlin/io/temporal/intellij/ui/   # UI Tests
        ├── BaseUiTest.kt
        ├── SharedIdeManager.kt
        ├── IdeInspector.kt
        ├── IdeInspectorTest.kt
        ├── UiFixtures.kt
        └── TemporalToolWindowTest.kt
```

## Plugin Configuration
- **Plugin ID**: `io.temporal.intellij`
- **Plugin Name**: Temporal
- **Platform**: IntelliJ IDEA Community (IC) 2024.1
- **Compatibility**: 241.* to 251.*
- **Language**: Kotlin
- **JDK**: 17
- **Dependencies**: Temporal SDK 1.27.0

## Commands Reference

### Build
```bash
cd tasks/jetbrains-temporal-plugin/temporal-intellij-plugin
./gradlew build
```

### Run in IDE Sandbox
```bash
./gradlew runIde
```

### Run UI Tests
```bash
# Terminal 1: Start IDE with Robot Server
./gradlew runIdeForUiTests

# Terminal 2: Run UI tests (after IDE is ready)
./gradlew uiTest
```

### Build Plugin Distribution
```bash
./gradlew buildPlugin
# Output: build/distributions/temporal-intellij-plugin-*.zip
```

## Reference Repository
- sdk-java worktree at `tasks/jetbrains-temporal-plugin/sdk-java/`
- Used for temporal-envconfig API reference

## Design Proposal

A comprehensive design proposal has been created: **[docs/PLUGIN_PROPOSAL.md](temporal-intellij-plugin/docs/PLUGIN_PROPOSAL.md)**

**Focus**: Developer-focused, read-only visibility into a single workflow execution during development.

### Key Features Proposed
1. **Workflow Execution Inspector** - Main panel showing workflow state, pending activities/children/timers
2. **Event History Timeline** - Chronological view of workflow events
3. **Query Execution Panel** - Execute workflow queries and view results
4. **Workflow Selector** - Quick access to recent/related workflows
5. **Stack Trace View** - Debug stuck workflows

### Technical Approach
- Uses Java SDK's `WorkflowServiceStubs` gRPC client (not CLI)
- Key APIs: `DescribeWorkflowExecution`, `GetWorkflowExecutionHistory`, `QueryWorkflow`, `ListWorkflowExecutions`
- All operations are read-only

## Next Steps
1. ~~**Phase 1 (MVP)**~~: ✅ Workflow ID input + Describe Workflow display + Pending activities
2. ~~**Phase 2**~~: ✅ Event History list + Query execution
3. **Phase 3**: Stack trace view (already implemented as part of Query panel)
4. **Phase 4**: Polish (auto-refresh, filtering, payload decoding)

## Reference Repositories
- `sdk-java/` - Temporal Java SDK (with proto submodules initialized)
- `temporal-cli/` - Temporal CLI (cloned for API reference)

## Commits
1. `b14e403` - Initial commit: Hello World plugin
2. `c19df7b` - Add Temporal tool window with official branding
3. `8520358` - Add Temporal server connection settings
4. `06eb5ad` - Add Test Connection button to verify server settings
5. `98ea784` - Add plugin proposal document for developer workflow visibility

## Session Handoff Checklist
- [x] Project compiles successfully
- [x] Task documentation created
- [x] Verified plugin runs in sandbox
- [x] Pushed to GitHub
- [x] Tool window with Temporal branding
- [x] Settings UI with connection configuration
- [x] Test Connection functionality working
- [x] Design proposal document created (docs/PLUGIN_PROPOSAL.md)
- [x] Java SDK proto submodules initialized for API reference
- [x] Phase 1 implementation (Workflow Execution Inspector)
- [x] Automated UI testing with Remote-Robot
- [x] Phase 2 implementation (Event History + Query execution)
- [x] Phase 3 implementation (Stack trace in Query tab)
- [x] Auto-refresh functionality
- [x] Tabbed UI with Overview/History/Query tabs
- [x] Tree-based event history with expandable events
- [ ] Phase 4 implementation (Polish - payload decoding, more filters)
