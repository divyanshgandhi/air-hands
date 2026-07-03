# Contributing

AirHands ports gesture semantics from the TypeScript reference in
`air-music`. The golden vectors are the spec: if engine behavior changes, the
vectors and the rationale must change with it.

## Verification

Run these before opening a PR:

```sh
swift build
swift run airhands-conformance
swift run airhands-conformance --self
```

On Xcode-equipped machines and CI, also run:

```sh
swift test
```

Command Line Tools-only machines may not provide XCTest or Swift Testing; on
those machines, the two `airhands-conformance` commands are the required test
mechanism.

## Golden Vectors

`Tests/AirHandsCoreTests/Vectors/*.json` are exported from the TypeScript
reference implementation in `air-music`:

```sh
bun scripts/export-gesture-vectors.ts
```

Changes to `StrikeFSM`, `StrumDetector`, `OneEuroFilter`, `ZoneIndex`, or
`FingertipTracker` semantics require regenerated vectors plus a clear rationale
in the PR. Do not adjust vectors to hide a porting bug.

## Code Style

Match the existing Swift style:

- keep `AirHandsCore` pure Swift with no platform dependencies;
- keep platform adapters in their own targets;
- prefer small deterministic types over broad abstractions;
- add focused self-test scenarios for behavior not covered by golden vectors;
- avoid unrelated refactors in behavior changes.

New camera or platform integrations should adapt landmarks into
`RawFingertip` or `RawHand` frames and leave the core gesture logic unchanged.
