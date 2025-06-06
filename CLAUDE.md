# Donna iOS App - Architecture & Design Principles

## 🎯 Phase 1 Goal
A **headless voice capture system** that reliably records audio via iOS Shortcuts without app foregrounding, transcribes it using OpenAI Whisper, and creates structured reminders—all while providing clear visual feedback through Live Activities.

**Success Criteria:**
- User hits shortcut → records thought → sees transcription in Dynamic Island → reminder created
- Main app shows recording history with playback for verification
- Works reliably even when app is terminated
- <2 second latency from speech end to reminder creation

## 🏗️ Core Architecture Principles

### 1. Headless-First Design
- Recording MUST happen in AppIntent extensions, not main app
- Main app provides settings, history view, and playback only
- Use `openAppWhenRun = false` for all recording intents

### 2. Fail-Safe Audio Pipeline
- Single actor-backed recording service (no duplicate pipelines)
- Explicit state machine: idle → preparing → recording → processing
- Always handle interruptions (calls, AirPods disconnect, app termination)

### 3. Live Activity as Primary UI
- Request Activity BEFORE starting audio session (iOS 18 requirement)
- Update maximum every 10-15 seconds (system throttles <5s anyway)
- Use timer views for auto-advancing time display
- Activity is the user's window into system state

### 4. Data Flow Clarity
- Audio files → AppGroup container (shared storage)
- Metadata only → SQLite/SwiftData
- Settings → UserDefaults with AppGroup suite
- Never store audio blobs in database

## 🚫 Invariants (NEVER VIOLATE)

1. **No recording in main app** - All audio capture happens in extensions
2. **Activity before audio** - Activity.request() must succeed before AVAudioSession.start()
3. **Respect system limits** - Live Activity updates ≥10s intervals
4. **Handle all interruptions** - Phone calls, AirPods, app termination
5. **AppGroup for shared data** - All cross-process data uses AppGroup container

## 📱 Main App Requirements

The main app MUST provide:
- List of all recordings with metadata (date, duration, transcription status)
- Audio playback controls for each recording
- Settings screen (API key management, preferences)
- Debug view showing Live Activity state
- NO recording functionality (only extensions record)

## 🔄 Current Sprint

Working on critical blockers from ULTRATHINK review:
- [ ] A-1: Move recording to AudioRecordingIntent 
- [ ] L-1: Fix Activity timing (request → record → update)
- [ ] O-1: Add onboarding flow
- [ ] O-2: Fix missing bundle identifier

For detailed task breakdown: read development-phases.md when needed

## 📝 Implementation Notes

When implementing any feature:
1. Check it doesn't violate invariants above
2. Ensure it works when app is terminated
3. Test interruption scenarios
4. Verify Live Activity updates properly
5. Consider battery impact

# Commands
- Build: `xcodebuild -scheme Donna`
- Test: `swift test`
- See issues: `/memory` then open development-phases.md