# Task Status: Async.await() PR #2751

**Last Updated:** 2026-01-07
**PR:** https://github.com/temporalio/sdk-java/pull/2751
**Branch:** `async-await` (from fork: mfateev/temporal-java-sdk)

## Task Overview

Add `Async.await()` methods for non-blocking condition waiting in the Temporal Java SDK.

### PR Summary
- Add `Async.await(Supplier<Boolean>)` and `Async.await(Duration, Supplier<Boolean>)` methods for non-blocking condition waiting that return a `Promise`
- Add `AwaitOptions` with `timerSummary` support for both `Async.await()` and `Workflow.await()`
- Add comprehensive tests for cancellation behavior and condition exception handling
- Add cross-reference `@see` Javadoc tags between `Workflow.sleep`, `Workflow.newTimer`, `Workflow.await`, and `Async.await` to help developers discover blocking vs non-blocking alternatives

## Current Status

### CI Status: ALL PASSING ✅

**15/15 checks passing**

- Unit test with in-memory test service [Edge] ✅
- Unit test with docker service [JDK8] ✅
- Unit test with cloud ✅
- Build native test server (6 platform variants) ✅
- Code format ✅
- features-test / test ✅
- Gradle wrapper validation ✅
- Check for CODEOWNERS ✅
- license/cla ✅
- semgrep-cloud-platform/scan ✅

### Previous Issue (Resolved)
The `MetricsTest::testUnhandledCommand` failure was a pre-existing issue fixed by PR #2757 ("Fix test server to return INVALID_ARGUMENT for UNHANDLED_COMMAND"). The branch was rebased on master after that fix was merged.

## PR Ready Status

The PR is **ready for merge**:
- All `Async.await()` functionality implemented
- `AwaitOptions` with `timerSummary` added (per reviewer feedback)
- All tests passing
- All CI checks green
- Review feedback addressed

## Workspace Setup
- Task worktree: `/Users/maxim/workarea/tasks/async-await/sdk-java`
- Branch: `async-await`
- Latest commit: `2d6d26f5 - Simplify awaitAsync and condition watcher implementation`
- Remote: `mfateev` (https://github.com/mfateev/temporal-java-sdk.git)

## Commands Reference

```bash
cd /Users/maxim/workarea/tasks/async-await/sdk-java

# Build & test
./gradlew test
./gradlew test -PedgeDepsTest

# Git
git status
git log --oneline -10
git push mfateev async-await
```
