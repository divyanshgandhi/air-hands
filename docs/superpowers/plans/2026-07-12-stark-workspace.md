# Stark Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a demo-ready native macOS hand-controlled spatial overlay with safe engagement, trackpad-familiar gestures, floating panels, and selected macOS window control.

**Architecture:** Extend the pure Swift gesture kernel with engagement and semantic gesture state machines, then feed those events into a testable workspace model. A thin SwiftUI/AppKit app renders the overlay and delegates privileged window operations to a permission-aware Accessibility bridge.

**Tech Stack:** Swift 5.9, Swift Package Manager, AVFoundation, Vision, SwiftUI, AppKit, ApplicationServices, CoreGraphics, UserDefaults

## Global Constraints

- macOS 13+ and iOS 16+ remain the package platform floors.
- Keep `AirHandsCore` free of platform dependencies.
- Add no third-party dependencies.
- Preserve all existing golden-vector and native self-tests.
- Every privileged action requires engaged mode and valid confidence.
- Escape always disengages and releases active interaction.
- Voice, custom ML, 3D physics, visionOS, Quest, and plugins remain out of scope.

---

### Task 1: Full-Hand Frame Contract

**Files:**
- Modify: `Sources/AirHandsCore/Types.swift`
- Modify: `Sources/AirHandsVision/VisionHandPoseSource.swift`
- Modify: `Sources/ConformanceKit/ConformanceRunner.swift`

**Interfaces:**
- Produces: `HandJoint`, `HandPose`, and `RawHand.joints` for platform-independent recognizers.

- [ ] **Step 1: Add a failing self-test for full joint plumbing**

Add a self-test that creates a `RawHand` containing wrist, MCP, PIP, DIP, and tip points and asserts the points survive `HandFrameSource` delivery unchanged.

```swift
let pose = RawHand(hand: .right, joints: [.wrist: Point(x: 0.4, y: 0.8)])
guard pose.joints[.wrist] == Point(x: 0.4, y: 0.8) else { return "wrist missing" }
```

- [ ] **Step 2: Run the failing self-test**

Run: `swift run airhands-conformance --self`  
Expected: compile failure because `HandJoint` and `joints` do not exist.

- [ ] **Step 3: Add the minimal joint model**

```swift
public enum HandJoint: String, Codable, CaseIterable, Sendable {
    case wrist
    case thumbCMC, thumbMP, thumbIP, thumbTip
    case indexMCP, indexPIP, indexDIP, indexTip
    case middleMCP, middlePIP, middleDIP, middleTip
    case ringMCP, ringPIP, ringDIP, ringTip
    case littleMCP, littlePIP, littleDIP, littleTip
}

public struct RawHand: Sendable {
    public var hand: Hand
    public var joints: [HandJoint: Point]
    // Preserve existing fingertips, palmCenter, and handScale fields.
}
```

Map every confidence-qualified Vision joint into `RawHand.joints`; derive fingertips, palm center, and scale from that same dictionary so each callback represents one coherent frame.

- [ ] **Step 4: Verify current and new contracts**

Run: `swift run airhands-conformance && swift run airhands-conformance --self`  
Expected: 16 conformance scenarios and 7 self-tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/AirHandsCore/Types.swift Sources/AirHandsVision/VisionHandPoseSource.swift Sources/ConformanceKit/ConformanceRunner.swift
git commit -m "feat: expose complete native hand frames"
```

### Task 2: Engagement and Trackpad Gesture Semantics

**Files:**
- Create: `Sources/AirHandsCore/EngagementDetector.swift`
- Create: `Sources/AirHandsCore/TrackpadGestureRecognizer.swift`
- Create: `Sources/AirHandsCore/IntentArbiter.swift`
- Modify: `Sources/ConformanceKit/ConformanceRunner.swift`

**Interfaces:**
- Consumes: `[RawHand]` and monotonic timestamps.
- Produces: `EngagementEvent`, `InteractionEvent`, and `IntentArbiter.process(hands:timestampMs:)`.

- [ ] **Step 1: Add failing deterministic self-tests**

Cover stable two-open-palm engagement, repeated pose idempotence, disengagement, lost-hand cancellation, point, pinch ownership, two-finger scroll, two-finger zoom, three-finger switch, four-finger overview, and gesture exclusivity.

```swift
let events = arbiter.process(hands: [openPalm(.left), openPalm(.right)], timestampMs: 350)
guard events == [.engagementChanged(true)] else { return "did not engage" }
```

- [ ] **Step 2: Run tests and confirm missing types fail compilation**

Run: `swift run airhands-conformance --self`  
Expected: compile failure for `IntentArbiter`.

- [ ] **Step 3: Implement engagement as a debounced state machine**

```swift
public enum EngagementEvent: Equatable, Sendable { case engaged, disengaged }

public struct EngagementConfig: Sendable {
    public var holdMs = 300.0
    public var lostGraceMs = 120.0
}

public final class EngagementDetector {
    public func process(_ hands: [RawHand], timestampMs: Double) -> [EngagementEvent]
    public func forceDisengage() -> [EngagementEvent]
}
```

An open palm requires four extended non-thumb fingers. Two visible open palms held for `holdMs` toggle engagement. Require the pose to clear before another toggle.

- [ ] **Step 4: Implement semantic gesture recognition and arbitration**

```swift
public enum InteractionEvent: Equatable, Sendable {
    case engagementChanged(Bool)
    case pointerMoved(Point)
    case grabBegan(Point), grabMoved(Point), grabEnded(Point)
    case scroll(delta: Point)
    case zoom(scaleDelta: Double)
    case switchWorkspace(direction: Int)
    case overview(Bool)
    case cancelled
}

public final class IntentArbiter {
    public func process(hands: [RawHand], timestampMs: Double) -> [InteractionEvent]
    public func cancel() -> [InteractionEvent]
}
```

Priority is engagement transition, active grab, zoom, scroll, switch, overview, then pointer. Emit no manipulation events while dormant or recovering.

- [ ] **Step 5: Run all pure checks**

Run: `swift run airhands-conformance && swift run airhands-conformance --self`  
Expected: existing 16 scenarios and all new semantic self-tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/AirHandsCore Sources/ConformanceKit/ConformanceRunner.swift
git commit -m "feat: add engaged trackpad gesture semantics"
```

### Task 3: Testable Workspace Model

**Files:**
- Create: `Sources/StarkWorkspaceCore/WorkspacePanel.swift`
- Create: `Sources/StarkWorkspaceCore/WorkspaceModel.swift`
- Create: `Sources/StarkWorkspaceCore/WorkspaceController.swift`
- Create: `Tests/StarkWorkspaceCoreTests/WorkspaceModelTests.swift`
- Modify: `Package.swift`

**Interfaces:**
- Consumes: `InteractionEvent`.
- Produces: observable panel transforms and `WindowCommand` values without calling platform APIs.

- [ ] **Step 1: Add the target and failing model tests**

```swift
func testGrabMovesSelectedPanel() {
    let model = WorkspaceModel.demo
    let controller = WorkspaceController(model: model)
    controller.handle(.grabBegan(Point(x: 0.5, y: 0.5)))
    controller.handle(.grabMoved(Point(x: 0.6, y: 0.6)))
    assert(model.selectedPanel?.frame.origin == CGPoint(x: 0.55, y: 0.55))
}
```

Also test resize clamping, z-order, minimize, dismiss, switching, overview, and cancellation.

- [ ] **Step 2: Run the focused tests**

Run: `swift test --filter StarkWorkspaceCoreTests`  
Expected: failure because the target implementation does not exist.

- [ ] **Step 3: Implement the minimal model**

```swift
public struct WorkspacePanel: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var frame: NormalizedRect
    public var zIndex: Int
    public var isMinimized: Bool
    public var windowID: String?
}

public enum WindowCommand: Equatable, Sendable {
    case focus(String)
    case move(String, NormalizedRect)
    case resize(String, NormalizedRect)
}
```

Keep panel coordinates normalized so camera gestures, display layouts, and a future spatial renderer share one model.

- [ ] **Step 4: Verify the model and gesture suite**

Run: `swift test --filter StarkWorkspaceCoreTests && swift run airhands-conformance --self`  
Expected: all model and semantic checks pass.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/StarkWorkspaceCore Tests/StarkWorkspaceCoreTests
git commit -m "feat: add spatial workspace model"
```

### Task 4: Native Overlay and Synthetic Demo

**Files:**
- Create: `Sources/StarkWorkspaceApp/main.swift`
- Create: `Sources/StarkWorkspaceApp/AppDelegate.swift`
- Create: `Sources/StarkWorkspaceApp/OverlayWindow.swift`
- Create: `Sources/StarkWorkspaceApp/WorkspaceView.swift`
- Create: `Sources/StarkWorkspaceApp/AdaptiveHUD.swift`
- Create: `Sources/StarkWorkspaceApp/DemoEventSource.swift`
- Modify: `Package.swift`

**Interfaces:**
- Consumes: `WorkspaceModel` and either synthetic or camera `InteractionEvent` streams.
- Produces: a transparent native overlay with demo panels and visible engagement state.

- [ ] **Step 1: Add a macOS executable target that initially fails to compile**

```swift
.executableTarget(
    name: "StarkWorkspaceApp",
    dependencies: ["AirHandsCore", "AirHandsVision", "StarkWorkspaceCore"]
)
```

Run: `swift build --product stark-workspace`  
Expected: product or entry point missing.

- [ ] **Step 2: Implement the overlay host and HUD**

Use a borderless transparent `NSPanel` at `.statusBar` level with `.canJoinAllSpaces`, SwiftUI content, and an Escape local/global monitor that invokes `controller.cancel()` and disengages.

```swift
final class OverlayWindow: NSPanel {
    init(content: some View) {
        super.init(contentRect: NSScreen.main?.frame ?? .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
    }
}
```

- [ ] **Step 3: Add deterministic `--demo` playback**

`DemoEventSource` emits a repeating sequence that engages, points, grabs a panel, resizes it, switches panels, enters overview, exits overview, and disengages. Add keyboard shortcuts for replay and step-through so every interaction is demonstrable without permissions.

- [ ] **Step 4: Build and launch synthetic mode**

Run: `swift build --product stark-workspace`  
Expected: build succeeds.

Run: `swift run stark-workspace --demo`  
Expected: overlay opens with three panels and the deterministic sequence updates them without camera or Accessibility permission.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/StarkWorkspaceApp
git commit -m "feat: add native Stark workspace demo"
```

### Task 5: Camera, Calibration, and Diagnostics

**Files:**
- Create: `Sources/StarkWorkspaceApp/CameraInteractionSource.swift`
- Create: `Sources/StarkWorkspaceApp/CalibrationStore.swift`
- Create: `Sources/StarkWorkspaceApp/Diagnostics.swift`
- Modify: `Sources/StarkWorkspaceApp/AppDelegate.swift`
- Modify: `Sources/StarkWorkspaceApp/AdaptiveHUD.swift`

**Interfaces:**
- Consumes: `VisionHandPoseSource` frames.
- Produces: calibrated `InteractionEvent` values and latency/FPS diagnostics.

- [ ] **Step 1: Add calibration and diagnostics self-checks**

Verify active-region mapping clamps to `[0, 1]`, camera IDs isolate stored calibration, and rolling diagnostics compute FPS and capture-to-HUD latency.

- [ ] **Step 2: Implement camera-keyed calibration using UserDefaults**

```swift
struct CameraCalibration: Codable, Equatable {
    var minX: Double
    var maxX: Double
    var minY: Double
    var maxY: Double
    var sensitivity: Double
}
```

Use the active AVFoundation device unique ID as the key. Default to the existing central `[0.15, 0.85]` region.

- [ ] **Step 3: Connect Vision frames to the arbiter and model**

Keep Vision callbacks off-main. Dispatch only semantic events and current HUD data to the main actor. Track processed FPS and frame-to-main-thread latency.

- [ ] **Step 4: Verify build and pure checks**

Run: `swift build --product stark-workspace && swift run airhands-conformance --self`  
Expected: build and checks pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/StarkWorkspaceApp
git commit -m "feat: connect calibrated camera gestures"
```

### Task 6: Permission-Aware macOS Window Bridge

**Files:**
- Create: `Sources/StarkWorkspaceApp/WindowBridge.swift`
- Create: `Sources/StarkWorkspaceApp/PermissionState.swift`
- Modify: `Sources/StarkWorkspaceApp/WorkspaceView.swift`
- Modify: `Sources/StarkWorkspaceApp/AppDelegate.swift`

**Interfaces:**
- Consumes: `WindowCommand` from `WorkspaceController`.
- Produces: eligible window cards and safe focus/move/resize operations.

- [ ] **Step 1: Add tests around pure filtering and coordinate conversion**

Extract pure functions that reject the workspace app, hidden/system elements, missing titles, and invalid frames; test normalized-to-screen frame conversion across non-zero screen origins.

- [ ] **Step 2: Implement permission state and Accessibility bridge**

```swift
enum PermissionState: Equatable { case unknown, denied, granted }

final class WindowBridge {
    var permission: PermissionState { get }
    func eligibleWindows() -> [SystemWindow]
    func execute(_ command: WindowCommand) throws
}
```

Use `AXIsProcessTrustedWithOptions`, `AXUIElementCreateApplication`, standard window attributes, and `AXUIElementPerformAction`. Never request or execute bridge actions while dormant.

- [ ] **Step 3: Add graceful metadata-only cards**

When Accessibility is denied, show setup guidance and keep native demo panels fully usable. Do not make ScreenCaptureKit permission a launch requirement; window title/app cards are sufficient for v1.

- [ ] **Step 4: Verify build and denied-permission launch**

Run: `swift build --product stark-workspace`  
Expected: succeeds.

Run: `swift run stark-workspace --demo`  
Expected: demo remains functional without Accessibility permission.

- [ ] **Step 5: Commit**

```bash
git add Sources/StarkWorkspaceApp
git commit -m "feat: bridge selected macOS windows"
```

### Task 7: Demo Readiness and Documentation

**Files:**
- Modify: `README.md`
- Create: `docs/DEMO.md`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Produces: exact launch path, permission instructions, smoke checklist, and CI evidence.

- [ ] **Step 1: Document exact demo commands and controls**

Include:

```sh
swift run stark-workspace --demo
swift run stark-workspace
swift run airhands-conformance
swift run airhands-conformance --self
```

Document engage pose, every gesture, Escape, camera selection behavior, Accessibility setup, calibration reset, diagnostics, and degraded modes.

- [ ] **Step 2: Extend macOS CI**

Build `stark-workspace`, run the 16-vector suite, run all self-tests, and run `swift test`. CI must not launch the GUI or require permissions.

- [ ] **Step 3: Run the complete automated gate**

Run: `swift build --product stark-workspace && swift run airhands-conformance && swift run airhands-conformance --self && swift test`  
Expected: every command exits 0.

- [ ] **Step 4: Run the manual synthetic smoke**

Launch `swift run stark-workspace --demo`; verify engage indicator, pointer, grab/move, resize, switch, overview, recovery simulation, disengage, and Escape. Record observed results in `docs/DEMO.md` with the current date.

- [ ] **Step 5: Commit**

```bash
git add README.md docs/DEMO.md .github/workflows/ci.yml
git commit -m "docs: make Stark workspace demo ready"
```

### Task 8: Completion Audit

**Files:**
- Inspect: all files named above

**Interfaces:**
- Proves every design requirement with current code, test, build, or runtime evidence.

- [ ] **Step 1: Confirm a clean worktree and review commits**

Run: `git status --short --branch && git log --oneline -10`  
Expected: clean `main` worktree with the planned implementation commits.

- [ ] **Step 2: Re-run the complete automated gate from a clean build**

Run: `swift package clean && swift build --product stark-workspace && swift run airhands-conformance && swift run airhands-conformance --self && swift test`  
Expected: every command exits 0.

- [ ] **Step 3: Audit each spec requirement**

Map every item in `docs/superpowers/specs/2026-07-12-stark-workspace-design.md` to a source file and current verification result. Any missing or indirect evidence returns to its owning task before completion is claimed.
