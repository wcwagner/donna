# Donna Development Phases

## Phase 0: Critical Foundation Fixes (Current)
*Fix blockers that prevent basic functionality*

### Sprint 1: Core Recording Architecture
- [ ] **A-1**: Refactor to AudioRecordingIntent
  - Move all recording logic from DonnaApp to RecordNoteIntent
  - Set `openAppWhenRun = false`
  - Delete duplicate AudioRecordingManager
  - Ensure works with app terminated
  - Test: Kill app → trigger shortcut → verify recording starts

- [ ] **L-1**: Fix Activity Request Timing  
  - Current (WRONG): startRecording() → Activity.request()
  - Fixed: Activity.request() → await success → startRecording()
  - Add error handling if Activity fails
  - Show clear error state to user

- [ ] **O-2**: Fix Info.plist
  - Add missing CFBundleIdentifier
  - Verify all required capabilities

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

- [ ] **L-2**: Optimize Update Frequency
  - Change from 250ms → 10s updates
  - Use ActivityKit timeline for auto-updating timer
  - Measure battery impact before/after

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
- [YOUR UPDATES HERE]

## Notes
- Keep focused on Phase 0 & 1 only
- Future phases (LLM parsing, email monitoring) tracked elsewhere
- Each task should be completable in <4 hours
- Test on real device, not just simulator