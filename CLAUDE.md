# CLAUDE.md - AI Agent Field Guide for Donna iOS

> Donna iOS 26 – voice-first ADHD recording app
> Reference architecture: `ARCHITECTURE.md` (Donna iOS 26 Architecture Guide)
> This guide enables autonomous development by AI agents

---

## 0. Mission & Context

You are working on Donna, a voice-first recording app for users with ADHD. The app leverages iOS 26's SpeechAnalyzer, App Intents, and Live Activities to provide instant, frictionless audio capture.

**Your objectives:**

- Implement, extend, and maintain a Swift-concurrency-strict iOS 26 application
- Keep all tests green and respect architectural invariants
- Use ONLY the Makefile commands provided - never shell out ad-hoc
- If a Make target is missing, add it to the Makefile first

**Key architectural decisions:**

- iOS 26 minimum (no backwards compatibility)
- Direct AAC streaming (35% latency improvement)
- Strict concurrency compliance
- Voice-first interaction (Siri, Action Button, hardware triggers)

---

## 1. Repository Layout & Naming Conventions

### Directory Structure

```
Donna/
├── Donna.xcworkspace      # Xcode workspace (always use this)
├── DonnaApp/              # SwiftUI host app (iOS 26+)
│   ├── DonnaApp.xcodeproj # DO NOT EDIT .pbxproj directly
│   └── Info.plist         # Edit via Xcode only
├── DonnaCore/             # Audio + transcription actors
├── DonnaKit/              # SPM package: protocols + App Intents
├── DonnaWidgets/          # Live Activity widgets
├── Tests/                 # All test targets
│   ├── Unit/              # Pure Swift tests
│   ├── Integration/       # Actor + concurrency tests
│   └── UITests/           # End-to-end automation
├── Makefile               # Canonical build commands
├── CLAUDE.md              # You are reading this
├── ios-4.md               # Architecture reference (read-only)
└── .ci/                   # CI scripts (mirror Makefile)
```

### Naming Conventions

**UpperCamelCase** for:

- Targets and frameworks: `DonnaApp`, `DonnaCore`, `DonnaKit`, `DonnaWidgets`
- Swift packages and modules
- Xcode groups and top-level folders
- Any type or module-level concept

**lowerCamelCase or kebab-case** for:

- Helper scripts: `run-tests.sh`
- Resource directories: `resources/`
- Non-Swift files and utilities

### Bundle ID Strategy

Root: `com.williamwagner` (lowercase, reverse-DNS) Pattern: `<root>.<product>.<qualifier>`

|Target|Bundle ID|
|---|---|
|Main App|`com.williamwagner.Donna`|
|DonnaKit|`com.williamwagner.Donna.DonnaKit`|
|DonnaCore|`com.williamwagner.Donna.DonnaCore`|
|DonnaWidgets|`com.williamwagner.Donna.DonnaWidgets`|
|Tests|`com.williamwagner.Donna.Tests`|
|UITests|`com.williamwagner.Donna.UITests`|

**AIDEV-NOTE**: Bundle IDs are case-sensitive. Keep root lowercase, product TitleCase.

---

## 2. Critical Ground Rules

### Concurrency

- **Always** maintain `StrictConcurrency = complete`
- Treat all concurrency warnings as errors
- AVAudioPCMBuffer → Data conversion before actor hops
- Use proper Sendable patterns (see Section 7)

### Platform

- iOS 26.0 minimum - no `#available` checks
- Use direct AAC streaming via `AVAudioFile`
- No private APIs (`os_proc_available_memory` is banned)

### Code Style

- Commits: `<area>: <imperative> (fix #ticket)`
- Example: `audio: fix sendability in tap callback (fix #127)`
- Tag AI-assisted commits: `[AI]` for >50%, `[AI-minor]` for <50%
- PR must pass: build, lint, test, ui-test, smoke-shortcut

### Testing Philosophy

- Every behavior must have a test
- Integration tests use fakes, not mocks
- UI tests must be idempotent
- No test should depend on external state
- **NEVER let AI write or modify tests**

---

## 3. Anchor Comments

Add specially formatted comments throughout the codebase as breadcrumbs for AI navigation and context preservation.

### Guidelines

- Use `AIDEV-NOTE:`, `AIDEV-TODO:`, or `AIDEV-QUESTION:` prefixes
- Keep them concise (≤ 120 chars)
- **Always search for existing anchors** before modifying code: `grep -r "AIDEV-" .`
- **Update anchors** when modifying associated code
- **Never remove `AIDEV-NOTE`s** without explicit human instruction

### When to Add Anchors

Add anchor comments when code is:

- Too long or complex
- Performance-critical
- Has non-obvious business logic
- Could be confusing to future developers/AI
- Has known issues unrelated to current task

### Examples

```swift
// AIDEV-NOTE: perf-critical - handles 100k events/sec, no allocations allowed
func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
    // AIDEV-QUESTION: Why convert to Data here instead of in tap?
    // A: Sendability requirement - buffer isn't Sendable
    let data = buffer.toData()
    
    // AIDEV-TODO: Add buffer pooling to reduce allocations (PERF-234)
    Task { await fileCoordinator.write(data) }
}

// AIDEV-NOTE: Never modify - encodes $10k/month business logic
func calculateSubscriptionTier(usage: Usage) -> Tier {
    // Complex tier calculation verified by finance team
}
```

---

## 4. Build & Test Commands

### Daily Development Workflow

```bash
# Check concurrency compliance
make concurrency-check

# Run linter and formatter
make lint

# Run all unit + integration tests
make test

# Run UI automation suite
make ui-test

# Quick smoke test (does recording land on disk?)
make smoke-shortcut

# Clean build artifacts
make clean
```

### Interactive Development

```bash
# Install and run app with live logs
make run

# Trigger Siri in simulator
xcrun simctl siri booted "Start recording in Donna"

# Simulate memory pressure
xcrun simctl spawn booted memory_pressure --simulate-critical 60
```

### Git Workflow for AI Development

```bash
# Create isolated workspace for experiments
git worktree add ../donna-ai-experiments/feature-x -b ai/feature-x

# Work in isolated environment
cd ../donna-ai-experiments/feature-x
# Let AI experiment freely here

# Cherry-pick successful changes back
cd ../../donna
git cherry-pick <commit-sha>

# Clean up when done
git worktree remove ../donna-ai-experiments/feature-x
```

---

## 5. Architecture Quick Reference

### Key Components

1. **AudioRecorderManager** (actor)

    - Manages AVAudioEngine with dual taps
    - Converts PCM buffers to Data for Sendability
    - Handles interruptions and hardware events
    - AIDEV-NOTE: Critical actor - all audio flows through here
2. **FileCoordinator** (actor)

    - Isolates all file I/O from audio thread
    - Uses AsyncChannel to prevent unbounded tasks
    - Implements two-phase commit for crash safety
    - AIDEV-NOTE: Never do file I/O outside this actor
3. **App Intents**

    - StartRecordingIntent (creates Live Activity)
    - StopCurrentRecordingIntent (parameter-less for hardware)
    - All view-returning intents need @MainActor
    - AIDEV-NOTE: Intents run in separate process - keep lightweight
4. **Live Activities**

    - 8 updates per 15 min (with NSSupportsLiveActivitiesFrequentUpdates)
    - 32 RMS samples max (memory constraint)
    - Timer uses .timer() - costs zero pushes
    - AIDEV-NOTE: ContentState must be <4KB compressed

### Memory Budgets

|Device|RSS Target|Jetsam Limit|
|---|---|---|
|A12 (iPhone XS)|24 MB|28 MB|
|A14 (iPhone 12)|32 MB|40 MB|
|A17 (iPhone 15 Pro)|45 MB|50 MB|

---

## 6. Test Architecture

### Test Pyramid

```
┌────────────────────────────────────┐
│  End-to-end UI/Shortcut (10-15)   │  make ui-test
└────────────────────────────────────┘
┌────────────────────────────────────┐
│  Integration Tests (50-100)        │  make test
└────────────────────────────────────┘
┌────────────────────────────────────┐
│  Unit Tests (500+)                 │  make test
└────────────────────────────────────┘
```

> **See Tests/CLAUDE.md** for detailed testing guidance, framework choices, and patterns

### Writing Tests (HUMANS ONLY)

> **CRITICAL**: AI must NEVER write or modify test files. Tests encode human understanding and business logic that AI cannot fully grasp.

#### Unit Test Example

```swift
// AIDEV-NOTE: Sacred ground - tests encode business requirements
import XCTest
@testable import DonnaCore

final class MarkerFileTests: XCTestCase {
    func testTwoPhaseCommitTransitions() throws {
        // This test encodes our crash-safety requirements
        var marker = RecordingMarker(
            id: UUID(),
            startTime: .now,
            state: .inProgress,
            activityId: nil,
            expectedLocation: URL(fileURLWithPath: "/tmp/test.m4a")
        )
        
        // Transition through states
        marker.state = .finalizing
        marker.state = .complete
        
        XCTAssertEqual(marker.state, .complete)
    }
}
```

---

## 7. Common Implementation Patterns

### Sendability Pattern for Audio

```swift
// AIDEV-NOTE: Always convert AVAudioPCMBuffer to Data immediately
inputNode.installTap(...) { [weak self] buffer, time in
    // Convert in tap callback (render thread)
    let data = buffer.toData()
    
    // Now safe to cross actor boundary
    Task {
        await self?.processBuffer(data, time: time)
    }
}
```

### Actor Property Exposure

```swift
// AIDEV-NOTE: Pattern for protocol conformance with actors
actor AudioRecorderManager: AudioRecordingService {
    private var _currentSession: RecordingSession?
    
    // Correct pattern for protocol conformance
    nonisolated var currentSession: RecordingSession? {
        actorIsolated { _currentSession }
    }
    
    private func actorIsolated<T>(_ body: () -> T) -> T { body() }
}
```

### Memory Monitoring

```swift
// AIDEV-NOTE: Check memory before large operations
func checkMemoryPressure() async {
    if let footprint = currentFootprint(), 
       footprint.availMemory < 8_000_000 {
        // Flush buffers immediately
        await fileCoordinator.flushAllBuffers()
    }
}
```

### Direct AAC File Creation

```swift
// AIDEV-NOTE: iOS 26+ only - 35% faster than CAF export
func makeStreamingAACFile(url: URL) throws -> AVAudioFile {
    let settings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 1,
        AVEncoderBitRateKey: 128_000,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
    
    return try AVAudioFile(forWriting: url,
                          settings: settings,
                          commonFormat: .pcmFormatFloat32,
                          interleaved: false)
}
```

---

## 8. Architectural Invariants (DO NOT VIOLATE)

1. **File Writing**: Direct AAC to `.m4a.tmp`, then atomic rename
2. **FileCoordinator**: Owns ALL AVAudioFile operations
3. **Live Activities**: Maximum 8 pushes per 15 minutes
4. **Crash Recovery**: Blocks app launch ≤ 200ms
5. **Memory**: Stay under device-specific Jetsam limits
6. **Concurrency**: All cross-actor data must be Sendable

---

## 9. Files and Patterns to NEVER Modify

### Sacred Files (NO AI MODIFICATIONS)

#### Test Files

```swift
// Tests/**/*.swift - NEVER TOUCH
// Tests encode human understanding of requirements
// AI cannot understand business context deeply enough
```

#### Xcode Project Files

```
// *.xcodeproj/project.pbxproj - NEVER EDIT DIRECTLY
// Use Xcode GUI or xcodebuild commands only
// Manual edits break project file integrity
```

#### Database Migrations

```swift
// Migrations/*.sql - NEVER MODIFY AFTER COMMIT
// Migrations are immutable once deployed
// Mistakes = data loss = career impact
```

#### Security-Critical Code

```swift
// Auth/**/*.swift - HUMAN REVIEW REQUIRED
// Keychain/**/*.swift - SECURITY TEAM ONLY
// Crypto/**/*.swift - NO AI SUGGESTIONS
```

#### API Contracts

```swift
// OpenAPI.yaml - REQUIRES VERSION BUMP
// Breaking changes need 3-month deprecation
// Mobile apps can't force-update instantly
```

#### Configuration Files

```
// Info.plist - Edit via Xcode only
// *.entitlements - Capability changes need review
// Secrets/*.swift - Obviously never touch
```

### Anti-Patterns to Avoid

```swift
// ❌ NEVER: Let AI "fix" failing tests
test.expectedValue = actualValue  // This hides bugs!

// ❌ NEVER: Bypass type safety
as! SomeType  // Without explicit approval
try! someCall()  // Crashes in production

// ❌ NEVER: Add network calls in audio path
// Audio thread has ~23ms budget at 44.1kHz

// ❌ NEVER: Store state outside designated actors
var globalCache = [String: Data]()  // Race condition!
```

---

## 10. Adding New Features

### Before Writing Code

1. Read the architecture document (`ios-4.md`)
2. Search for relevant AIDEVcomments: `grep -r "AIDEV-" DonnaCore/`
3. Check if similar patterns exist in codebase
4. Write tests first (TDD) - HUMAN ONLY
5. Ensure Makefile has necessary targets

### Implementation Checklist

- [ ] Add AIDEV-NOTE comments for complex logic
- [ ] Feature builds with `make concurrency-check`
- [ ] Unit tests pass (human-written)
- [ ] Integration tests cover actor interactions
- [ ] UI test validates user-visible behavior
- [ ] Memory usage profiled on A12 device
- [ ] No new concurrency warnings
- [ ] Update relevant AIDEVcomments

### Adding Make Targets

If you need a new build/test command:

```make
# Add to Makefile with clear documentation
## description of what this does
new-target:
	command with proper error handling
```

---

## 11. Debugging Common Issues

### Sendability Errors

```
Error: Passing argument of non-Sendable type 'AVAudioPCMBuffer'
```

**Fix**: Convert to Data in the tap before Task boundary **Look for**: AIDEV-NOTE comments about Sendability

### Actor Isolation

```
Error: Actor-isolated property 'currentSession' can not be referenced
```

**Fix**: Use nonisolated computed property pattern **Look for**: AIDEV-NOTE: Pattern for protocol conformance

### Memory Warnings

```
Received memory pressure notification
```

**Fix**: Check footprint with currentFootprint(), flush buffers **Look for**: AIDEV-NOTE: perf-critical sections

### Live Activity Throttling

```
Activity update failed: TooManyUpdates
```

**Fix**: Batch updates, respect 8/15min limit **Look for**: AIDEV-NOTE: ContentState constraints

---

## 12. Emergency Procedures

### Build Broken?

1. `make clean`
2. `git checkout main && git pull`
3. `make bootstrap`
4. `make concurrency-check`
5. Search for recent AIDEV-TODO comments that might indicate WIP

### Tests Flaky?

1. Check for hardcoded delays - replace with proper waits
2. Ensure tests use `-UITest_` launch arguments
3. Clean simulator state: `xcrun simctl erase booted`
4. NEVER modify tests to make them pass - fix the code instead

### Performance Regression?

1. Profile with Instruments (memory + time profiler)
2. Check buffer sizes (512 vs 1024)
3. Verify direct AAC streaming is enabled
4. Look for AIDEV-NOTE: perf comments

---

## 13. Git Commit Standards

### Commit Message Format

```
<type>: <description> [AI-tag]

<body explaining what and why>

AI assistance: <what AI did vs what you did>
```

### AI Tags

- `[AI]` - Significant AI assistance (>50% generated)
- `[AI-minor]` - Minor AI assistance (<50% generated)
- `[AI-review]` - AI used for code review only

### Example

```
feat: implement memory pressure monitoring [AI]

Add currentFootprint() using public task_vm_info API to monitor
memory usage and trigger buffer flushes when approaching limits.

AI assistance: Generated task_vm_info boilerplate and struct definitions.
Human: Designed threshold strategy and integration points.
```

---

## 14. Communication

- Architecture questions → Create issue with `[Architecture]` prefix
- Build failures → Check CI logs first, then create issue
- New patterns → Propose in PR with tests demonstrating usage
- AIDEVcomments → Use for inline questions/notes

**Remember**:

- The Makefile is the single source of truth for commands
- The architecture document is read-only reference
- All code must pass strict concurrency checks
- Tests are sacred - humans only
- When in doubt, add an AIDEV-QUESTION comment

---

## Quick Start for New Task

```bash
# 1. Update your local copy
git checkout main && git pull

# 2. Search for relevant context
grep -r "AIDEV-" . | grep -i "your-feature-area"

# 3. Create feature branch (or use worktree for experiments)
git checkout -b feature/your-feature
# OR for experimental work:
git worktree add ../donna-experiments/your-feature -b ai/your-feature

# 4. Verify clean state
make clean && make concurrency-check

# 5. Make changes with TDD
# - Human writes failing test
# - Implement feature (AI can help here)
# - Make test pass
# - Add AIDEV- comments for complex parts

# 6. Validate everything
make lint && make test && make ui-test

# 7. Commit with proper AI attribution
git commit -m "feat: your feature [AI-minor]"

# 8. Create PR with green CI
```

Happy coding! Remember: when in doubt, check the architecture document, search for AIDEVcomments, and follow existing patterns.