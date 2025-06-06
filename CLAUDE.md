# Donna - Executive Function Assistant

## Vision & Design Philosophy
Donna is inspired by Donna Moss from The West Wing - an assistant who anticipates needs, persists without being annoying, and handles the mundane so you can focus.

### Core Principles
- **Frictionless**: One button press, no app switching, no UI unless needed
- **Always Available**: Action Button = instant access, no "opening apps"
- **Voice-First**: Talk naturally, Donna figures out the rest
- **Ambient**: Lives in Dynamic Island, not demanding attention
- **Persistent**: Like a good assistant, follows up without nagging
- **Delightful**: Small animations, thoughtful feedback, feels alive

### The Experience
When I press the Action Button, Donna just starts listening. No Siri UI, no app launch. A subtle Dynamic Island animation shows she's listening. I speak naturally: "remind me to get the food scale from storage" or "water the plants at 4pm". When I pause or say "Roger", she confirms with a gentle haptic and disappears. The reminder just appears in my system - no further interaction needed.

## Technical Implementation (iOS 18)

### Project Structure
- Donna/ (main app)
  - DonnaApp.swift - main app entry
  - ContentView.swift - minimal UI for settings/history
- DonnaActivityWidget/ (widget extension)
  - Live Activity for recording state
  - App Intent for Action Button

### Current Focus: MVP Recording Pipeline
1. Action Button triggers App Intent (no UI)
2. Background audio recording starts
3. Live Activity shows in Dynamic Island
4. Silence detection ends recording
5. Audio stored in SQLite
6. (Later: Whisper transcription, commitment extraction)

[Rest of technical details...]