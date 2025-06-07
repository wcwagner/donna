# Donna · iOS 18 Modern Idioms Cheat‑Sheet

*A quick reference for upgrading older‑style code and mental models to current best practice. Focused on tasks in Phase 0 → Phase 1, with a peek at Phase 2+ so we don’t paint ourselves into a corner.*

---

## 🗂 Project Structure & Sharing

* **Shared Swift Package for core logic**
  ➜ Move `AudioRecordingManager`, models, and helpers into **`DonnaShared`** so App & Intents link the *same* source.
  ⬅︎ *(Old)* Duplicate classes copied into each target.
* **SwiftData over CoreData**
  ➜ Use `@Model` + `ModelContainer` (already in place) and rely on *lightweight migration* instead of manual Persistent History.
  ⬅︎ *(Old)* Custom CoreData stacks + entity pruning warnings.
* **App Group only for binary blobs & simple prefs**
  ➜ Store audio files + small JSON dictionaries; everything else lives in SwiftData.

---

## 🚀 Execution Contexts & Intents

* **App Intents are the entry point**
  ➜ `RecordNoteIntent : AudioRecordingIntent` (✓) and `StopRecordingIntent` handle all user gestures.
  ⬅︎ *(Old)* Custom URL callbacks & `UIApplication.shared.open()` hacks.
* **`ForegroundContinuableIntent` only for permission flows**
  Ex: `OnboardingIntent` can ask for mic permission, then return to Shortcuts without foregrounding the app.
* **Delete Darwin ping for Stop**
  `Button(intent:)` already spins up the intent extension; just call the singleton directly.

---

## 🎙 Audio Capture Pipeline

* **Start Live Activity *before* `AVAudioSession.activate()`** (✓)
* **Category** `.playAndRecord` + `.mixWithOthers` + `.allowHapticsAndSystemSoundsDuringRecording`
  Keeps system sounds & haptics intact.
* **Silence detection**
  Replace custom timer with *AsyncSequence* of `AudioRecorderMeter.readings` once Apple exposes it (beta 3+). Until then, 500 ms Combine timer is fine.
* **Background processing**
  Use **`BGProcessingTaskRequest`** for Whisper transcription so it runs when plugged in or on Wi‑Fi.

---

## 🏝 Live Activity & Dynamic Island

| Need            | Modern idiom                                      | Deprecated / avoid                                   |
| --------------- | ------------------------------------------------- | ---------------------------------------------------- |
| Real‑time timer | `Text(timerInterval:… style: .timer)`             | Manual Timer → `Activity.update()` every N seconds   |
| User controls   | `Button(intent:)` & `linkIntent()`                | `.widgetURL` to deep‑link app                        |
| Remote updates  | ActivityKit **pushType liveactivity** via APNs    | Silent push → Notification Service Ext → update      |
| Dismissing      | `await activity.end(dismissalPolicy: .immediate)` | Manually updating attribute + hoping system hides UI |

> **Battery tip**  Let the system coalesce updates (< once / 15 s) – no polling timers in widget code.

---

## 🔔 Notifications & IPC

* **Local, in‑process** → Swift `async` / Combine → actors.
* **Cross‑process, same device** → **AppIntent invocation** » Darwin note » XPC service hierarchy.
* **Cross‑device** → **APNs Activity push** for UI, classic push for reminders.

Future: for streaming partial transcription results, explore **URPipe** (new in iOS 18) to stream small payloads from intent to widget without polling.

---

## 🛡 Permissions & Privacy

* **Mic**: Use `AVAudioApplication.recordPermission` (new wrapper) and handle `.denied` by returning an `.error` result that Shortcuts surfaces automatically.
* **Background Audio**: Declare `audio` in `UIBackgroundModes` *only* for the widget/intent targets that *actually* record.
* **Push Tokens**: Register for `Activity.pushTokenUpdates` → store in SwiftData → sync to server.

---

## ⚙️ Build & Concurrency Flags

* Enable **Swift 6 strict‑concurrency**; mark `AudioRecordingManager` as `actor`.
* Turn on **`DEAD_CODE_STRIPPING = YES`** to drop unused template code.
* Adopt **`@Observable`** in views instead of manual `@State` where possible (SwiftUI 3).

---

## 🌅 Looking ahead (Phase 2+)

* **LLM parsing** runs in a *BackgroundProcessingTask* with incremental JSON results streamed via ActivityKit push if user watches.
* **Server‑triggered reminders** → Use *pushToStartActivity* tokens to *create* Activities remotely when a calendar event fires.
* **Multimodal**: iOS 18’s **CaptureSessionMic & Camera fusion** could let Donna attach a quick photo to the voice note (vision OS style) – keep storage layer flexible.

---

> **Rule of thumb:** If you find yourself writing timers, dispatch queues, or NotificationCenter observers, ask “Does iOS 18 already have an `async` primitive or an Intent‑driven alternative?”  Nine times out of ten, it does.
