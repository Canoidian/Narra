# NarraV2 — Project Outline

## Overview

NarraV2 is a native macOS voice-to-text application built with Swift + SwiftUI. It emphasizes intelligent post-processing to handle real-world speech patterns like self-corrections, restatements, and filler words. The app features a "liquid glass" UI aesthetic and supports both online (Grok API) and offline (local models) transcription and post-processing.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        NarraV2 App                           │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ Liquid Glass │  │  Transcript  │  │ Status / Settings│   │
│  │    View      │  │   Display    │  │    Indicators    │   │
│  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘   │
│         │                 │                    │             │
├─────────┼─────────────────┼────────────────────┼─────────────┤
│         │                 │                    │             │
│  ┌──────┴───────────────┐ │                    │             │
│  │   SwiftUI Frontend   │ │                    │             │
│  └──────┬───────────────┘ │                    │             │
│         │                 │                    │             │
├─────────┼─────────────────┼────────────────────┼─────────────┤
│         │                 │                    │             │
│  ┌──────┴──────────────────▼─────────────────────┴──────────┐│
│  │                  Transcription Pipeline                  ││
│  │  ┌────────────────┐  ┌────────────────┐  ┌───────────┐ ││
│  │  │ Audio Capture  │──▶│   Transcript   │──▶│   Post    │ ││
│  │  │   (Buffer)     │  │   Service      │  │Processing │ ││
│  │  └────────────────┘  │(Grok / Whisper)│  │(Grok/LLM) │ ││
│  │                       └────────────────┘  └───────────┘ ││
│  └─────────────────────────────────────────────────────────┘│
│                              │                              │
├──────────────────────────────┼──────────────────────────────┤
│                              │                               │
│  ┌───────────────────────────▼───────────────────────────┐  │
│  │                   Transcription Service                  │  │
│  │  ┌─────────────────────────┐  ┌─────────────────────┐  │  │
│  │  │ GrokTranscriptionService│  │ LocalTranscription  │  │  │
│  │  │    (Grok API STT)     │  │   (whisper.cpp)     │  │  │
│  │  └─────────────────────────┘  └─────────────────────┘  │  │
│  └─────────────────────────────────────────────────────────┘  │
│                              │                                  │
│  ┌───────────────────────────▼───────────────────────────┐     │
│  │                  Post-Processing Service               │     │
│  │  ┌─────────────────────────┐  ┌─────────────────────┐  │     │
│  │  │GrokPostProcessingService│  │LocalPostProcessing  │  │     │
│  │  │    (Grok API LLM)       │  │   (MLX Swift)       │  │     │
│  │  └─────────────────────────┘  └─────────────────────┘  │     │
│  └─────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────┘
```

## File Structure

```
NarraV2/
├── Sources/
│   └── NarraV2/
│       ├── NarraV2App.swift                    # App entry point
│       ├── main.swift                          # Swift Package entry
│       ├── Views/
│       │   ├── ContentView.swift               # Main app layout
│       │   ├── LiquidGlassView.swift           # Liquid glass UI effect
│       │   └── StatusIndicator.swift           # Recording status (convenience)
│       ├── Services/
│       │   ├── Transcription/
│       │   │   ├── TranscriptionService.swift  # Protocol definition
│       │   │   ├── GrokTranscriptionService.swift   # Grok API STT
│       │   │   └── LocalTranscriptionService.swift  # whisper.cpp
│       │   └── PostProcessing/
│       │       ├── PostProcessingService.swift      # Protocol
│       │       ├── GrokPostProcessingService.swift  # Grok API
│       │       └── LocalPostProcessingService.swift # MLX Swift
│       ├── Audio/
│       │   └── AudioCaptureManager.swift        # AVAudioEngine capture
│       ├── Models/
│       │   └── TranscriptSegment.swift           # Data model for transcript segments
│       └── Utils/
│           └── (utility files)
├── Package.swift
├── .gitignore
└── docs/
    └── superpowers/
        └── plans/
            └── voice-to-text-app.md              # This plan file
```

## Key Components

### Audio Layer
- **AudioCaptureManager**: Manages `AVAudioEngine` for real-time microphone capture
- Implements a rolling audio buffer for continuous streams
- Handles audio format conversion and level monitoring

### Transcription Layer
- **TranscriptionService** (Protocol): Abstracts audio chunking and STT calls
- **GrokTranscriptionService**: Sends audio chunks to Grok's STT endpoint (streaming)
- **LocalTranscriptionService**: Runs whisper.cpp locally for offline transcription

### Post-Processing Layer
- **PostProcessingService** (Protocol): Defines the post-processing interface
- **GrokPostProcessingService**: Sends text to Grok LLM for intelligent cleanup
- **LocalPostProcessingService**: Runs local LLM (MLX Swift) for offline cleanup

### Frontend Layer
- **LiquidGlassView**: Custom SwiftUI view implementing the liquid glass aesthetic
- **ContentView**: Main app layout with transcript display and controls
- **StatusIndicator**: Visual feedback for recording/listening state

### Smart Post-Processing Pipeline
1. **Raw STT** → Receive transcription from Grok or Whisper
2. **Pattern Filter** → Local regex/pattern detection for fillers, corrections
3. **LLM Refinement** → Grok/Local LLM intelligently cleans up remaining issues
4. **UI Update** → Stream corrected text to the display

## Dependencies

### Swift Package Manager
- `whisper.cpp` (Swift bindings) — Local STT fallback
- `mlx-swift` — Local LLM fallback (MLX framework)
- (Any additional UI helpers for liquid glass effects)

### External Requirements
- macOS 14.0+
- Microphone access permission
- Internet connection (for Grok API; offline mode works without)

## Build & Run

```bash
# Build the project
swift build

# Run the app
swift run

# Build and archive for distribution
xcodebuild -scheme NarraV2 -configuration Release archive
```

## Testing Strategy

- **Unit tests**: Audio buffer management, transcript segment manipulation
- **Integration tests**: End-to-end pipeline with sample audio
- **Manual QA**: Real-world speech with self-corrections, fillers, restatements
- **Offline QA**: Verify graceful fallback with no network connectivity

## Development Workflow

This project uses [Subagent-Driven Development](https://github.com/anthropics/claude-plugins/tree/main/superpowers/subagent-driven-development).

Each task is implemented by a fresh subagent with two-stage review (spec compliance → code quality). See `docs/superpowers/plans/voice-to-text-app.md` for the full plan.
