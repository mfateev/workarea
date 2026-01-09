# Task Status: Heartbeat Timeout Testing

## Task Overview
- **Issue**: https://github.com/temporalio/sdk-go/issues/1282
- **Title**: Heartbeat timeout not raised while testing
- **Author**: miquelpuigmena
- **Labels**: potential-bug
- **State**: OPEN

## Problem Summary
The Go SDK test environment does not enforce heartbeat timeout for activities during unit testing. When an activity runs longer than the configured `HeartbeatTimeout` without sending heartbeats, the test should fail, but instead it passes.

## Current Status
- [x] Workspace set up
- [x] Investigation completed
- [x] Root cause identified
- [x] Fix implemented
- [x] Tests written
- [x] PR created: https://github.com/temporalio/sdk-go/pull/2142
- [ ] CI passing

## Root Cause Analysis

The test environment (`internal/internal_workflow_testsuite.go`) did not enforce heartbeat timeout because:

1. **`mockHeartbeatFn`** (line 341) only stored heartbeat details but didn't track timing
2. **`executeActivityWithRetryForTest`** (line 1454) only monitored `ScheduleToCloseTimeout`, not heartbeat timeout
3. **Activity context deadline** was only based on `StartToCloseTimeout`/`ScheduleToCloseTimeout`

In production, the **Temporal server** monitors heartbeat timing and fails activities that don't heartbeat within the timeout. The test environment's mock service didn't replicate this behavior.

## Implementation

### Changes Made

1. **Modified `testActivityHandle` struct** (line 67-75):
   - Added `heartbeatTimeout time.Duration`
   - Added `lastHeartbeatTime time.Time`
   - Added `heartbeatTimedOut bool`
   - Added `cancelHeartbeat func()`

2. **Added `heartbeatTimeoutResult` type** (line 117-121):
   - Marker type to indicate heartbeat timeout
   - Stores last heartbeat details

3. **Modified `mockHeartbeatFn`** (line 341):
   - Now updates `lastHeartbeatTime` when heartbeat is received

4. **Modified `ExecuteActivity`** (line 1254-1351):
   - Initializes activity handle with heartbeat timeout info
   - Starts heartbeat monitoring goroutine if `HeartbeatTimeout > 0`
   - Monitoring goroutine checks every `HeartbeatTimeout/2` for timeout
   - When timeout occurs, marks `heartbeatTimedOut = true`
   - Activity completion checks this flag and returns heartbeat timeout error

5. **Modified `handleActivityResult`** (line 1736-1745):
   - Added case for `*heartbeatTimeoutResult`
   - Creates `TIMEOUT_TYPE_HEARTBEAT` error with last heartbeat details

### Tests Added

Three new tests in `internal/internal_workflow_testsuite_test.go`:

1. **`Test_ActivityHeartbeatTimeout`**: Activity without heartbeating times out
2. **`Test_ActivityHeartbeatTimeout_WithHeartbeat`**: Activity with regular heartbeats succeeds
3. **`Test_ActivityHeartbeatTimeout_WithDetails`**: Heartbeat details are preserved on timeout

## Files Changed

- `internal/internal_workflow_testsuite.go`
- `internal/internal_workflow_testsuite_test.go`

## Commands Reference

### Build and Test
```bash
cd tasks/heartbeat-timeout-testing/sdk-go
go build ./...
go test ./internal/... -run TestHeartbeat -v
go test ./internal/... -run Test_ActivityHeartbeatTimeout -v
```

## Next Steps

1. Run tests locally to verify fix works
2. Run full test suite to ensure no regressions
3. Create PR with changes
4. Address any CI failures

## Session Handoff Checklist
- [x] Read this status document
- [x] Reviewed implementation
- [ ] Run tests locally
- [ ] Create PR

---
*Last updated: Implementation complete*
