# Task Status: Async.await() PR #2751

**Last Updated:** 2026-01-06
**PR:** https://github.com/temporalio/sdk-java/pull/2751
**Branch:** `async-await` (from fork: mfateev/temporal-java-sdk)

## Task Overview

Add `Async.await()` methods for non-blocking condition waiting in the Temporal Java SDK.

### PR Summary
- Add `Async.await(Supplier<Boolean>)` and `Async.await(Duration, Supplier<Boolean>)` methods for non-blocking condition waiting that return a `Promise`
- Add comprehensive tests for cancellation behavior and condition exception handling
- Add cross-reference `@see` Javadoc tags between `Workflow.sleep`, `Workflow.newTimer`, `Workflow.await`, and `Async.await` to help developers discover blocking vs non-blocking alternatives

### Test Plan from PR
- [x] Unit tests for `Async.await()` with immediate condition satisfaction
- [x] Unit tests for timed `Async.await()` with timeout expiration
- [x] Unit tests for cancellation behavior (CanceledFailure propagation)
- [x] Unit tests for condition throwing exceptions
- [x] All existing AsyncAwaitTest and WorkflowTest tests pass

## Current Status

### Workspace Setup
- Repository cloned at: `/Users/maxim/ai/workarea/repos/sdk-java`
- Task worktree at: `/Users/maxim/ai/workarea/tasks/async-await/sdk-java`
- Current branch: `async-await`
- Latest commit: `ad5576f6 - Add AwaitOptions with timerSummary for Async.await() and Workflow.await()`
- Remote added: `mfateev` (https://github.com/mfateev/temporal-java-sdk.git)

### CI Status

**Overall:** 1 FAILING, 13 PASSING

#### ❌ Failing Check
**Test:** `Unit test with in-memory test service [Edge]`
**Duration:** 7m32s
**URL:** https://github.com/temporalio/sdk-java/actions/runs/20735291771/job/59625693079

**Specific Failure:**
```
io.temporal.client.functional.MetricsTest::testUnhandledCommand

junit.framework.AssertionFailedError: expected:<1> but was:<2>
    at io.temporal.client.functional.MetricsTest.assertSingleMeterCountForMultiScenario(MetricsTest.java:261)
    at io.temporal.client.functional.MetricsTest.testUnhandledCommand(MetricsTest.java:256)
```

**Analysis:**
- The test expects a meter count of 1 but receives 2
- This is a metrics/telemetry assertion failure
- Related to unhandled workflow commands scenario
- Occurring in the "Edge" test configuration (tests with edge dependency versions)
- The new `Async.await()` methods might be generating additional metrics events

#### ✅ Passing Checks (13 total)
- Code format
- Unit test with cloud
- Unit test with docker service [JDK8]
- Build native test server (6 platform variants)
- features-test / test
- Gradle wrapper validation
- Check for CODEOWNERS
- license/cla
- semgrep-cloud-platform/scan

## Investigation Needed

### Immediate Next Steps
1. **Examine the failing test:**
   - File: `temporal-sdk/src/test/java/io/temporal/client/functional/MetricsTest.java`
   - Focus on: `testUnhandledCommand()` method (line 256)
   - Check: `assertSingleMeterCountForMultiScenario()` method (line 261)

2. **Understand what metrics are being generated:**
   - Review the new `Async.await()` implementation
   - Check if it's emitting additional telemetry/metrics events
   - Compare with expected behavior in the test

3. **Review related changes:**
   - Look at commits in the PR that might affect metrics
   - Check if `Async.await()` is creating timers or other tracked operations

### Key Questions to Answer
- Why is the metrics count 2 instead of 1?
- Is this a legitimate bug in the implementation or does the test need updating?
- Are the new `Async.await()` methods creating additional workflow commands/timers?
- Should the test expectations be updated to account for the new behavior?

## Repository Structure (Relevant Paths)

```
temporal-sdk/
├── src/
│   ├── main/java/io/temporal/
│   │   ├── workflow/Async.java           # Main implementation location
│   │   └── workflow/Workflow.java        # Related blocking await methods
│   └── test/java/io/temporal/
│       ├── client/functional/
│       │   └── MetricsTest.java          # FAILING TEST
│       └── workflow/
│           └── AsyncAwaitTest.java       # PR's new tests
```

## Commands Reference

### Build & Test
```bash
cd /Users/maxim/ai/workarea/tasks/async-await/sdk-java

# Run all tests
./gradlew test

# Run specific test
./gradlew test --tests "io.temporal.client.functional.MetricsTest.testUnhandledCommand"

# Run with edge dependencies (matches CI)
./gradlew test -P edgeDepsTest

# Build only
./gradlew build
```

### Git Operations
```bash
# Check current status
git status

# View recent commits
git log --oneline -10

# Compare with master
git diff master...HEAD

# Push changes
git push mfateev async-await
```

## Notes

- This is testing on JDK 23 in the Edge configuration
- The failure is specific to metrics/telemetry, not core functionality
- All other tests pass, including the new `AsyncAwaitTest` tests
- The PR description mentions comprehensive tests were added and pass
- This might be an existing test that needs adjustment for the new behavior

## Resolution Strategy

1. Read and understand the failing test
2. Trace through the implementation to see what metrics are being emitted
3. Determine if this is:
   - A bug in the implementation (fix the code)
   - An outdated test expectation (update the test)
   - A legitimate change in behavior (update test + verify it's acceptable)
4. Run tests locally to verify the fix
5. Push changes and verify CI passes

## Session Handoff Checklist

When picking up this task:
- [ ] Navigate to: `cd /Users/maxim/ai/workarea/tasks/async-await/sdk-java`
- [ ] Verify branch: `git branch --show-current` (should be `async-await`)
- [ ] Check latest CI: `gh pr checks 2751 --repo temporalio/sdk-java`
- [ ] Read this document for context
- [ ] Start with investigating the failing test at MetricsTest.java:256
