# Stark Workspace Demo

## Fastest Demo

```sh
cd ~/Work/Sides/air-hands
swift run stark-workspace --demo
```

Synthetic mode requires no permissions. It opens a transparent native overlay
with three panels and cycles through engage, pointer, grab/move, resize, switch,
overview, and return. Press `Ctrl+C` in the launching terminal to quit.

## Live Camera Demo

```sh
swift run stark-workspace
```

Grant Camera access to the terminal when macOS asks. For real Mac window cards,
also enable the terminal under **System Settings → Privacy & Security →
Accessibility**, then relaunch.

### Controls

| Gesture | Action |
|---|---|
| Hold two open palms for 300 ms | Engage or disengage |
| Right index movement | Point and select |
| Thumb-index pinch | Grab, drag, release |
| Two extended fingers moving together | Scroll |
| Two-finger spread/compress | Resize selected panel |
| Three-finger horizontal swipe | Switch panel/window |
| Three-finger downward swipe | Minimize selected panel |
| Three-finger upward swipe | Dismiss selected panel |
| Four extended fingers | Enter overview |
| Lower fingers after overview | Exit overview |
| Escape | Immediate cancel and disengage |

The top HUD always shows engagement state. In camera mode it also reports
processed FPS and frame-to-HUD latency. Tracking loss releases active grabs and
disengages after the grace interval rather than guessing.

## Permission Degradation

- No Camera: the app reports `Camera unavailable` and emits no actions.
- No Accessibility: native panels work; Mac window cards and control are disabled.
- No screen recording: no impact; v1 uses title/app metadata rather than previews.

## Verification Recorded 2026-07-12

- Native product built successfully with `swift build --product stark-workspace`.
- Synthetic overlay launched and was visually inspected from a captured screen.
- It showed three translucent native panels, selected-panel highlighting,
  engagement HUD, pointer feedback, and animated overview/layout transitions.
- The automated completion gate must remain green before release.
