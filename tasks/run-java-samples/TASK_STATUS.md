# Task Status: Run Java Samples

## Task Overview
- **Purpose**: Workspace for running and exploring Temporal Java samples
- **Repository**: https://github.com/temporalio/samples-java

## Current Status
- [x] Workspace created
- [ ] Build samples project
- [ ] Explore available samples

## Available Samples Categories
*To be populated after exploration*

## Commands Reference

### Build the project
```bash
cd tasks/run-java-samples/samples-java
./gradlew build
```

### Run a specific sample
```bash
# Start a worker (in one terminal)
./gradlew -q execute -PmainClass=<package>.<WorkerClassName>

# Start a workflow (in another terminal)
./gradlew -q execute -PmainClass=<package>.<StarterClassName>
```

### List all samples
```bash
find . -name "*.java" -path "*/src/main/*" | head -50
```

## Notes
- Requires a running Temporal server (can use `temporal server start-dev`)
- Java 11+ required
