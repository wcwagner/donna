# Donna Development Phases

## Phase 0: Critical Foundation Fixes (Current)
*Fix blockers that prevent basic functionality*

### Sprint 1: Core Recording Architecture
- [x] **A-1**: Refactor to AudioRecordingIntent
  - Move all recording logic from DonnaApp to RecordNoteIntent
  - Set `openAppWhenRun = false`
  - Delete duplicate AudioRecordingManager
  - Ensure works with app terminated
  - Test: Kill app → trigger shortcut → verify recording starts

- [x] **L-1**: Fix Activity Request Timing  
  - Current (WRONG): startRecording() → Activity.request()
  - Fixed: Activity.request() → await success → startRecording()
  - Add error handling if Activity fails
  - Show clear error state to user

- [x] **O-2**: Fix Info.plist
  - Add missing CFBundleIdentifier
  - Verify all required capabilities

- [x] **N-1**: Live-Activity timer ticks every 1s
  - Replace 10s Timer with `Text(timerInterval:...style:.timer)`
  - Dynamic Island shows real-time counter
  - No more manual timer updates

- [x] **N-2**: Stop UI everywhere
  - Minimal/compact leading shows `stop.fill` button wired to `StopRecordingIntent`
  - Main-app Status row shows "Stop" button instead of "Open Shortcuts" when recording
  - Ensure stop button works from all contexts

- [x] **N-3**: Single-activity guard
  - Prevent multiple Live Activities when shortcut pressed repeatedly
  - Second shortcut press updates existing Activity instead of throwing visibility error
  - Check for existing activity before creating new one

- [x] **C-1**: CoreData history reset
  - Detect orphaned entity "Item" on dev builds
  - Wipe store and recreate if needed
  - Add lightweight migration path for beta

### Sprint 2: Robustness & Permissions
- [ ] **O-1**: Onboarding Flow
  - Create OnboardingIntent with ForegroundContinuableIntent
  - Microphone permission request
  - OpenAI API key entry → Keychain storage
  - Guide user through Shortcuts setup
  - Show success state when complete

- [ ] **S-3**: Audio Interruption Handling
  - Observe AVAudioSession.interruptionNotification
  - Gracefully stop recording
  - Update Live Activity with interruption reason
  - Save partial recording if possible

- [x] **L-2**: Optimize Update Frequency
  - Changed from 250ms → 10s updates
  - Will use ActivityKit timeline for auto-updating timer (via N-1)
  - Measure battery impact before/after

- [x] **C-2**: Delete sample widget code
  - Remove `DonnaActivityWidgetControl`
  - Remove `DonnaActivityWidget` timer demo
  - Clean up any other template/placeholder code

- [ ] **C-3**: Consolidate AudioRecordingManager
  - Remove duplicate definitions
  - Keep single source under Shared
  - Ensure both targets reference same code

- [x] **C-4**: Fix CFPrefs warning
  - Switch to standard `UserDefaults(suiteName:)`
  - Remove cross-user scope usage
  - Test that shared data still works correctly

### Sprint 3: iOS 18 Modern Patterns
- [ ] **I-1**: Create DonnaShared Swift Package
  - Move AudioRecordingManager to package
  - Move SharedTypes to package
  - Link package to both app and widget targets
  - Remove duplicate file copies

- [ ] **I-2**: Remove Darwin notifications for Stop
  - StopRecordingIntent should call AudioRecordingManager.shared directly
  - Remove CFNotificationCenter usage
  - Test stop works from all contexts

- [x] **I-3**: Actor-based AudioRecordingManager
  - Mark AudioRecordingManager as `actor`
  - Update all calls to use `await`
  - Enable Swift 6 strict concurrency checking

- [ ] **I-4**: Replace permission error handling
  - Use proper AppIntentError.permissionRequired pattern
  - Remove requestToContinueInForeground workaround
  - Test permission flow in Shortcuts

## Phase 1: MVP - Complete Voice Capture System
*Working shortcut → record → transcribe → reminder flow*

### Sprint 3: Main App UI
- [ ] Recording History List
  - SwiftData model for recordings (metadata only)
  - List view showing: date, duration, transcription status
  - Swipe actions: delete, share
  - Pull-to-refresh to sync from AppGroup

- [ ] Audio Playback
  - AVAudioPlayer for .m4a files from AppGroup
  - Playback controls: play/pause, scrubber
  - Show waveform visualization
  - Display transcription if available

- [ ] Settings Screen
  - API key management (edit/validate)
  - Recording quality options
  - Silence detection threshold
  - Debug info (Live Activity state, errors)

### Sprint 4: Transcription Pipeline
- [ ] OpenAI Whisper Integration
  - Add to AppIntent (not main app)
  - Queue failed transcriptions
  - Show progress in Live Activity
  - Update SwiftData on completion

- [ ] Basic Reminder Creation
  - Simple text → reminder (no smart parsing yet)
  - Use EventKit to create reminder
  - Let user pick reminder list
  - Show success in Live Activity

### Sprint 5: Polish & Ship
- [ ] Error States
  - No network → queue for later
  - API failures → clear messaging
  - Mic permission denied → guide to settings
  - Storage full → warning

- [ ] Testing & Optimization
  - Battery usage profiling
  - Memory leak detection
  - Stress test with 100+ recordings
  - TestFlight beta release

## Implementation Log

### 2025-01-06
- Architecture review completed (ULTRATHINK)
- Identified critical blockers: A-1, L-1, O-1, O-2
- Created two-file documentation system

### 2025-01-07  
- Completed cleanup tasks (removed boilerplate tests, unused models)
- Completed A-1: Moved all recording to RecordNoteIntent
- Completed L-1: Fixed Activity timing (request before audio)
- Completed O-2: Fixed Info.plist bundle identifier
- Added new tasks based on UX testing: N-1, N-2, N-3 (timer and stop UI)
- Completed N-1: Updated Live Activity to use timerInterval for real-time updates (iOS 18 pattern ✓)
- Completed N-2: Added stop buttons to Dynamic Island and main app
- Completed N-3: Added single-activity guard to prevent duplicates
- Completed C-1: Cleaned up orphaned CoreData entities
- Completed C-2: Removed all sample widget code
- Identified iOS 18 patterns to adopt: Swift Package (I-1), remove Darwin notifications (I-2), actor pattern (I-3)
- Completed I-3: Converted AudioRecordingManager to actor pattern with proper async/await
- Fixed critical issues from debug session:
  - Fixed timer display using proper timerInterval range
  - Fixed audio playback by using fileURLWithPath instead of URL(string:)
  - Added recording state verification logging
  - Implemented minimal-start pattern for reduced latency
  - Fixed CFPrefs warning (C-4) by using proper UserDefaults suite
  - Fixed Live Activity visibility error by adding LiveActivityStartingIntent conformance
  - Added pre-flight check for Live Activities being enabled
  - Added graceful fallback to continue recording without Live Activity

## Notes
- Keep focused on Phase 0 & 1 only
- Future phases (LLM parsing, email monitoring) tracked elsewhere
- Each task should be completable in <4 hours
- Test on real device, not just simulator