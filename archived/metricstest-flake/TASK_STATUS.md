# Task Status: MetricsTest Flake Fix

## Task Overview
- **Type**: Bug fix - Flaky test
- **Repository**: temporalio/sdk-java
- **Test**: `io.temporal.client.functional.MetricsTest.testUnhandledCommand`
- **PR**: https://github.com/temporalio/sdk-java/pull/2757

## Status: COMPLETED

PR merged on 2026-01-07.

## Root Cause Analysis

The flake was in `testUnhandledCommand` test which verifies that `WORKFLOW_COMPLETED_COUNTER` is exactly 1, but was getting 2.

**Problem**: The test server was not matching real Temporal server behavior for UNHANDLED_COMMAND:

1. Real server: Returns `INVALID_ARGUMENT: UnhandledCommand` error, which causes SDK to skip applying completion metrics
2. Test server: Returned success but silently recorded WORKFLOW_TASK_FAILED in history

This caused the SDK to apply completion metrics for task 1 (before learning it was rejected), then apply them again for task 2 (the retry that succeeded).

## Solution

Made the test server throw `INVALID_ARGUMENT: UnhandledCommand` error to match real server behavior.

**Validation approach**: Ran the test against real Temporal server at localhost first to confirm the expected behavior, then fixed the test server to match.

## Files Changed

### 1. `temporal-test-server/src/main/java/io/temporal/internal/testservice/TestWorkflowMutableStateImpl.java`
```java
if (unhandledCommand(request) || unhandledMessages(request)) {
    // Record the failure in history, then throw an error to the caller
    // (matching real server behavior).
    failWorkflowTaskWithAReason(...);
    ctx.setExceptionIfEmpty(
        Status.INVALID_ARGUMENT.withDescription("UnhandledCommand").asRuntimeException());
    return;
}
```

### 2. `temporal-sdk/src/test/java/io/temporal/client/functional/MetricsTest.java`
Added `registry.clear()` in setUp for clean state between tests.

## Merge Details
- **Commit**: `2322bd0da735fe310b7291f3b7fbeda10bdf5e40`
- **Merged**: 2026-01-07T21:26:55Z
- **Reviewer**: maciejdudko

## Commands Used
```bash
# Run test against real server
USE_DOCKER_SERVICE=true ./gradlew :temporal-sdk:test --tests "io.temporal.client.functional.MetricsTest.testUnhandledCommand"

# Run all MetricsTest tests
./gradlew :temporal-sdk:test --tests "io.temporal.client.functional.MetricsTest"
```
