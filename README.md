# AirHands

**Instrument-grade hand-gesture events from any camera.** A Swift package that
turns hand tracking into velocity-sensitive *strikes*, *holds*, *releases*, and
*strums* — the difference between "my hand is at (x, y)" and "I just struck
that key at velocity 0.72".

Extracted from [air-music](https://github.com/divyanshgandhi/air-music), where
the same engine plays a piano, drum kit, koto, and handpan in the browser.

## Why

Every platform hands you 21 hand landmarks. None of them tell you when a
gesture *means* something. AirHands is the layer in between:

- **Strikes, not hovers.** A note fires only on a downward-velocity flick —
  sweeping or hovering over a zone stays silent. No ghost notes.
- **Real dynamics.** Strike velocity is derived from peak descent speed —
  play soft, play loud.
- **Stability without mush.** One Euro filtering, hysteresis on zone exits,
  and a grace window for tracking dropouts.
- **Strums.** A fast horizontal sweep is its own gesture: every zone crossed
  fires, velocity proportional to sweep speed.

## Usage

```swift
import AirHandsCore
import AirHandsVision

// Define zones (normalized 0–1): a one-octave keyboard, a drum pad grid, UI buttons…
let zones = (0..<8).map { i in
    Zone(id: "pad-\(i)", rect: Rect(x: Double(i) / 8, y: 0.4, width: 1.0 / 8, height: 0.5), layer: 0)
}

let session = GestureSession(
    source: VisionHandPoseSource(),   // AVFoundation + Apple Vision (macOS 13+ / iOS 16+)
    zones: zones,
    config: .keys,                    // or .percussion, or roll your own GestureConfig
    strumConfig: .strings,            // optional: enables sweep-to-glissando
    profile: .crisp                   // .crisp | .balanced | .stable latency trade-off
)
session.onEvent = { event in
    switch event {
    case let .strike(zoneId, velocity, _): play(zoneId, velocity: velocity)
    case let .release(zoneId, _): stop(zoneId)
    }
}
session.onFingers = { fingers in updateCursors(fingers) }   // filtered, per-frame
try session.start()
```

Bring your own landmark source by conforming to `HandPoseSource` — MediaPipe,
ARKit, a replay file — the engine doesn't care where fingertips come from.

## The conformance suite (how "the feel" stays portable)

The gesture engine has a TypeScript reference implementation (air-music). It
exports **golden vectors** — frame sequences plus the exact event streams the
engine emitted (16 scenarios covering strike lifecycles, hysteresis, dropout
grace, strum cooldowns, and filter output down to raw doubles). This port
reproduces them exactly:

```
$ swift run airhands-conformance
ran 16 scenarios (8 fsm, 5 strum, 3 one-euro)
CONFORMANT — Swift engine matches the TypeScript reference exactly
```

Ports to other languages start by passing the same vectors. `swift test` wraps
the same suite for Xcode environments (Command Line Tools ship no test
framework — use the runner there).

## Package layout

| Target | Contents |
|---|---|
| `AirHandsCore` | Pure Swift, zero platform deps: One Euro filter, fingertip tracker, strike FSM, strum detector, zones, `GestureSession` |
| `AirHandsVision` | `VisionHandPoseSource`: AVFoundation camera → `VNDetectHumanHandPoseRequest` → normalized fingertips |
| `ConformanceKit` + `airhands-conformance` | Golden-vector verification |

## Roadmap

- visionOS adapter (ARKit `HandTrackingProvider`, 3D strikes with real depth)
- Demo app (macOS SwiftUI)
- Kotlin/Android port against the same vectors
- MIDI event output

## License

MIT
