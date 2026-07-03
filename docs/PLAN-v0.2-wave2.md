# AirHands v0.2 — Wave 2: AirCursor demo + publication hygiene

Owner: Claude (planning/review) · Implementation: Codex · 2026-07-03

## Hard constraints (unchanged from wave 1)

Work only in `/Users/divyanshgandhi/air-hands`. No push/remotes/tags. CLT-only
machine: verify with `swift build`, `swift run airhands-conformance`, and
`swift run airhands-conformance --self`. Golden vectors must stay CONFORMANT.

## Work items

0. **PinchDetector lost-hand handling (review finding from wave 1).** If a hand
   with an ACTIVE pinch is absent from `process()` input for more than
   `lostGraceMs` (new `PinchConfig` field, default 120), emit
   `pinchEnded(hand, at: lastPoint)` and reset that hand to idle — a vanished
   hand must never leave a drag stuck down. A hand in `candidate` phase that
   disappears resets to idle immediately, no event. Add two `--self` scenarios:
   (a) active pinch, hand absent 100ms → no event yet; absent 150ms → exactly
   one pinchEnded at the last filtered midpoint; (b) candidate hand disappears
   → no events ever.

1. **AirCursor demo executable** (`Sources/aircursor/`, macOS-only via
   `#if os(macOS)`, new `.executableTarget(name: "aircursor",
   dependencies: ["AirHandsCore", "AirHandsVision"])`).
   Behavior: VisionHandPoseSource → FingertipTracker with `.pointer` profile
   params → right-hand index fingertip drives the mouse cursor; PinchDetector
   (right hand) maps pinchBegan → leftMouseDown, pinchMoved → leftMouseDragged
   (only while pinched; otherwise mouseMoved), pinchEnded → leftMouseUp, all
   posted via CGEvent to the main display.
   Coordinate mapping: the central region of camera space (x,y ∈ [0.15, 0.85])
   maps to the full main-display bounds, clamped — full-arm reach should not be
   required. Flags: `--dry-run` prints events instead of posting CGEvents.
   On start, print: camera + Accessibility permission requirements (the
   invoking terminal needs both), the control scheme, and "Ctrl+C to quit".
   Requires no third-party deps. Runtime cannot be exercised on CI or in the
   sandbox — verification is compile + conformance + self-tests; document a
   manual test script in the README section.

2. **CI workflow** (`.github/workflows/ci.yml`): macos-14 (or latest) runner:
   `swift build`, `swift run airhands-conformance`,
   `swift run airhands-conformance --self`, `swift test` (works on CI because
   Xcode provides Swift Testing). Trigger: push to main + pull_request — this
   repo has no deploy pipeline, plain CI is safe.

3. **CONTRIBUTING.md**: the conformance contract (vectors are the spec; how to
   run both runners; vectors regenerate from the air-music TypeScript reference
   via `bun scripts/export-gesture-vectors.ts`), code style (match existing),
   and the rule that engine-semantics changes require regenerated vectors plus
   a rationale.

4. **README**: AirCursor section (what it does, permissions, `swift run
   aircursor`, `--dry-run`), CI badge placeholder, roadmap updates.

## Definition of done

All three verification commands green; aircursor builds on macOS; work in ≥4
logical commits (or uncommitted with a note if the sandbox blocks git).
