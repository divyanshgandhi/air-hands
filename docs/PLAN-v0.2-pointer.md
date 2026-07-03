# AirHands v0.2 — Pointer-Grade Gestures (wave 1)

Owner: Claude (planning/review) · Implementation: Codex agents · 2026-07-03

## Goal

Evolve the engine from instrument strikes toward **OS-control precision**: the
gesture vocabulary and stability needed to eventually drive a macOS cursor and
move windows by hand (pinch = click/grab). This wave delivers the core
primitives; the AirCursor demo app is wave 2.

## Hard constraints

- Work only in `/Users/divyanshgandhi/air-hands`.
- Machine has Command Line Tools only: **no XCTest, no Swift Testing**. All
  verification must run via `swift build` and `swift run airhands-conformance`.
- The existing conformance suite MUST stay green and byte-identical in meaning:
  `swift run airhands-conformance` → `CONFORMANT`. Do not change StrikeFSM,
  StrumDetector, OneEuroFilter, ZoneIndex, or FingertipTracker semantics.
- Do not push, create remotes, or tag. Commit granularly with clear messages.
- Keep `GestureSession`'s existing initializer source-compatible (additive
  parameters with defaults are fine).

## Work items

1. **Hand-frame model.** Add `RawHand { hand: Hand; fingertips: [RawFingertip];
   palmCenter: Point?; handScale: Double? }` (handScale = a stable intra-hand
   distance, e.g. wrist→middle-MCP, in normalized units). Add an additive
   `onHands: (([RawHand], Double) -> Void)?` to `HandPoseSource` via a protocol
   extension-friendly design (keep `onFrame` working). Update
   `VisionHandPoseSource` to populate palmCenter (wrist or middle-MCP joint) and
   handScale from `recognizedPoints(.all)`.
2. **PinchDetector** (new file in AirHandsCore). Per hand: pinch strength =
   distance(thumbTip, indexTip) / handScale (fall back to a fixed reference
   0.25 if handScale is nil). Config: `beginThreshold 0.35`, `endThreshold 0.55`
   (hysteresis), `minHoldMs 40` (debounce). Events:
   `pinchBegan(hand, at: Point)`, `pinchMoved(hand, at: Point)`,
   `pinchEnded(hand, at: Point)` where `at` is the thumb/index midpoint,
   filtered. Deterministic, pure, no platform deps.
3. **`.pointer` latency profile** on `LatencyProfile`: heavy low-speed
   stabilization for cursor dwell — OneEuroParams(minCutoff: 0.15, beta: 1.2,
   dCutoff: 1.0), and it should NOT change maxDescentMs (strikes are not the
   pointer use case).
4. **Self-test suite.** Because no test framework exists on CLT: add
   `swift run airhands-conformance --self` which runs pure-Swift scenario tests
   for PinchDetector (begin/end hysteresis, debounce, scale normalization —
   same pinch distance at half handScale must yield the same strength) and the
   RawHand plumbing. Exit non-zero on failure, print scenario names. Also add
   pinch coverage to the guarded `#if canImport(Testing)` test file (compiles
   only in Xcode environments).
5. **Docs.** Update README (pinch usage snippet + roadmap tick) and
   docs/DESIGN.md (Hand-frame + PinchDetector sections, pointer profile).

## Definition of done

`swift build` clean, `swift run airhands-conformance` prints CONFORMANT,
`swift run airhands-conformance --self` passes all new scenarios, docs updated,
work committed in ≥3 logical commits.
