# Task Status: Fix Build Issues in samples-java

## Task Overview
- **Repository**: [temporalio/samples-java](https://github.com/temporalio/samples-java)
- **Goal**: Fix build failures in the samples-java repository

## Current Status
**Status**: PR Created - CI Passed

- **PR**: https://github.com/temporalio/samples-java/pull/765
- **Branch**: `mfateev:task/fix-build-issues-samples-java`
- **CI**: All checks passed (Unit Tests, Code format, Semgrep, CLA)

## Issue 1: NotJavadoc Warnings (Fixable)

**Files affected:**
- `core/src/main/java/io/temporal/samples/envconfig/LoadFromFile.java` (lines 3, 83)
- `core/src/main/java/io/temporal/samples/envconfig/LoadProfile.java` (lines 3, 91)

**Root cause:** These files use `/**` block comments for SNIP markers (documentation extraction), which ErrorProne's `NotJavadoc` check flags as warnings. With `-Werror`, these become errors.

**Fix:** Change `/**` to `//` single-line comments for SNIP markers:
```java
// Before:
/**
 * @@@SNIPSTART java-env-config-profile
 */

// After:
// @@@SNIPSTART java-env-config-profile
```

**Note:** Using `/*` multi-line comments doesn't work because Spotless reformats them back to `/**`.

## Issue 2: SpringBoot Test Failure (Pre-existing)

**Test:** `HelloSampleTestMockedActivity`
**Error:** `TypeAlreadyRegisteredException: "Hello" activity type is already registered with the worker`

**Root cause:** The test uses `@MockBean` to mock `HelloActivityImpl`, but since `HelloActivityImpl` has `@ActivityImpl(taskQueues = "HelloSampleTaskQueue")` annotation, Temporal's Spring Boot integration registers BOTH the original class AND the mock as the same activity type.

**This is a pre-existing issue** - the test was already failing on the main branch before any changes. CI shows the most recent successful run was Dec 9, 2025, but an earlier run on Dec 4, 2025 failed.

## What I Tried (and reverted)

### Attempt 1: ComponentScan exclude filter
Added `@ComponentScan.Filter(type = FilterType.ASSIGNABLE_TYPE, classes = HelloActivityImpl.class)` to exclude the real implementation. **Result:** Still failed because `@MockBean` creates a mock of `HelloActivityImpl` which still has the `@ActivityImpl` annotation.

### Attempt 2: Remove @MockBean, use plain Mockito mock
Tried to use `Mockito.mock(HelloActivity.class)` with `@Bean` and `@ActivityImpl`. **Result:** `@ActivityImpl` annotation is not applicable to methods, only classes.

### Attempt 3: Create inner class with @Component
Created `MockHelloActivity` inner class with `@Component` and `@ActivityImpl`. **Result:** The `@Component` was picked up by ALL tests (not just this one), causing 6 tests to fail instead of 1.

## Recommendation

1. **Fix Issue 1** (NotJavadoc) - Simple change to comment style
2. **For Issue 2** - Either:
   - Skip/disable the test temporarily and file an issue
   - Investigate proper way to mock activities in Temporal Spring Boot tests (may require changes to temporal-spring-boot-starter)

## Commands Reference
```bash
# Build
./gradlew build

# Run specific module tests
./gradlew :springboot:test

# Run core compile only
./gradlew :core:compileJava
```

## Session Notes
- Fork remote: mfateev (https://github.com/mfateev/temporal-java-samples)
- Branch: task/fix-build-issues-samples-java
