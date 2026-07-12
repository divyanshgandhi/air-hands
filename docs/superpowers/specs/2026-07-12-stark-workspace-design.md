# Stark Workspace Design

**Status:** Approved for implementation  
**Target:** macOS first; visionOS later  
**Principle:** Native, low-latency direct manipulation using familiar Mac trackpad gestures

## Product Goal

Build a demo-ready macOS experience where an explicit engage pose reveals an adaptive spatial overlay. The user can manipulate floating panels and selected real Mac windows with natural hand gestures. The experience must feel immediate, legible, and safe rather than merely recognizing poses.

## V1 Scope

- Support built-in Mac cameras and iPhone Continuity Camera through AVFoundation.
- Gate every action behind a deliberate engage/disengage pose.
- Show an adaptive HUD: minimal intent feedback normally, richer skeleton/confidence feedback during engagement, calibration, and tracking recovery.
- Support pointing, pinch click/grab, pinch drag, two-finger scroll, two-finger zoom, three-finger horizontal switching, and four-finger overview.
- Support floating native panels that can be selected, moved, resized, stacked, minimized, and dismissed.
- Bridge selected macOS windows into the overlay and support focus, move, resize, switch, and overview actions through Accessibility APIs.
- Save camera-specific calibration and expose a quick recalibration path.
- Provide an immediate kill switch and always-visible engaged state.

## Explicitly Deferred

- Voice or conversational AI
- Custom Core ML or MediaPipe hand models
- RealityKit or Metal-based 3D scene physics
- visionOS and Quest deployment
- General plugin framework

The existing tracking source boundary preserves a later custom-model adapter. The workspace model preserves a later RealityKit or Metal renderer without burdening v1.

## Architecture

The runtime is a single directional pipeline:

`AVFoundation -> Apple Vision -> AirHandsCore -> IntentArbiter -> WorkspaceModel -> NativeShell`

### AirHandsCore

Retain the current pure Swift core and golden-vector contract. Add only platform-independent state machines:

- `EngagementDetector`: stable engage/disengage pose with debounce and lost-hand cancellation.
- `GestureRecognizer`: trackpad-style gesture events derived from full hand landmarks.
- `IntentArbiter`: ensures one interaction owns a hand at a time and resolves priority, cancellation, and mode transitions.

The recognizers emit semantic events and never call AppKit, Accessibility, or Core Graphics directly.

### AirHandsVision

Extend the current adapter to expose the confidence-gated joints needed by the gesture recognizers. Keep capture and Vision processing off the main thread, discard late frames, and publish one coherent timestamped frame.

### StarkWorkspace macOS App

Add one native app target containing:

- `WorkspaceModel`: panels, z-order, selection, transforms, and interaction state.
- `OverlayWindow`: transparent always-on-top AppKit host with SwiftUI content.
- `AdaptiveHUD`: engagement, pointer, grab, gesture, calibration, and recovery feedback.
- `WindowBridge`: permission-aware Accessibility wrapper for enumerating, focusing, moving, and resizing eligible windows.
- `CalibrationStore`: camera-keyed active region and sensitivity stored with `UserDefaults`.

No plugin layer or renderer abstraction is added. The workspace model itself is the seam for a future renderer.

## Interaction Model

### Modes

1. **Dormant:** camera may track, but no system action is possible and the overlay is hidden.
2. **Engaging:** the engage pose is visible and stable for the debounce interval; calibration HUD appears.
3. **Engaged:** direct manipulation and command gestures are enabled; a persistent indicator remains visible.
4. **Recovering:** confidence or hands are temporarily lost; active grabs are released and actions are suppressed.

Escape immediately returns to Dormant and releases every synthetic input or window operation.

### Gesture Mapping

- Right index movement: point and hover.
- Thumb-index pinch: click, grab, drag, and release.
- Index-middle parallel movement: scroll.
- Two-finger distance change: zoom or resize the selected panel.
- Three extended fingers moving horizontally: switch panel or eligible Mac window.
- Four-finger spread: enter overview; collapse exits overview.
- Two open palms held in the engage pose: toggle engagement after debounce.

Gesture ownership is exclusive. Pinch/grab outranks scroll and zoom; engagement transitions outrank all manipulation; loss of confidence cancels rather than guesses.

## Native Window Integration

The Accessibility bridge operates only after permission is granted. It filters out the workspace app, hidden/system-only elements, and non-actionable windows. It reads and writes standard window position and size attributes and raises selected windows. ScreenCaptureKit previews are optional enhancement data; the first demo remains functional with title/icon representations if capture permission is absent.

## Performance Targets

- Keep camera processing off the main thread and always discard late frames.
- Target 30 processed hand frames per second on supported Apple Silicon Macs.
- Target under 50 ms from captured frame timestamp to visible HUD update under normal load.
- Render the overlay at display cadence independently from Vision inference.
- Avoid allocations in per-frame recognizer hot paths where practical.

These targets are measured in the demo app and reported in a compact diagnostics overlay.

## Error Handling and Safety

- Camera unavailable: show setup state; emit no actions.
- Camera permission denied: provide the exact System Settings destination.
- Accessibility denied: spatial panels remain usable; Mac window controls stay disabled with a visible explanation.
- Screen capture denied: use metadata-only window cards.
- Tracking confidence drops: release grabs, stop synthetic events, enter Recovering.
- App resigns active or exits: release all held input and window interactions.
- Escape: unconditional disengage and cleanup.

## Verification

- Preserve all existing 16 golden-vector scenarios and 6 native self-tests.
- Add focused pure Swift checks for engagement debounce, disengagement, gesture exclusivity, scroll, zoom, switching, overview, and lost-hand cancellation.
- Add model checks for panel movement, resize limits, z-order, minimize, dismiss, and overview transitions.
- Build the macOS app target from the command line.
- Provide a `--demo` mode using deterministic synthetic hand events so the overlay and panel interactions can be demonstrated without camera permissions.
- Provide a manual camera smoke checklist covering engage, point, grab, scroll, zoom, switch, overview, recovery, and Escape.

## Demo Definition of Done

The repository is demo-ready when a fresh build launches the native app; synthetic demo mode exercises every panel interaction; camera mode supports engagement and direct manipulation; denied permissions degrade visibly and safely; all automated checks pass; and the README contains exact launch, permission, calibration, and demo instructions.
