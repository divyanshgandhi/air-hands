#if os(macOS)
import AirHandsCore
import AirHandsVision
import CoreGraphics
import Foundation

private let cameraMin = 0.15
private let cameraMax = 0.85
private let rightIndexID = "right-index"

private enum MouseAction: String {
    case moved = "mouseMoved"
    case leftDown = "leftMouseDown"
    case leftDragged = "leftMouseDragged"
    case leftUp = "leftMouseUp"
}

private final class MouseDriver {
    private let dryRun: Bool
    private let source = CGEventSource(stateID: .hidSystemState)

    init(dryRun: Bool) {
        self.dryRun = dryRun
    }

    func post(_ action: MouseAction, at point: CGPoint) {
        if dryRun {
            print(String(format: "%@ x=%.1f y=%.1f", action.rawValue, point.x, point.y))
            return
        }

        let type: CGEventType
        switch action {
        case .moved:
            type = .mouseMoved
        case .leftDown:
            type = .leftMouseDown
        case .leftDragged:
            type = .leftMouseDragged
        case .leftUp:
            type = .leftMouseUp
        }

        CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: .left
        )?.post(tap: .cghidEventTap)
    }
}

private final class AirCursor {
    private let source = VisionHandPoseSource()
    private let tracker = FingertipTracker(
        params: OneEuroParams(minCutoff: 0.15, beta: 1.2, dCutoff: 1.0)
    )
    private let pinch = PinchDetector()
    private let mouse: MouseDriver
    private let displayBounds = CGDisplayBounds(CGMainDisplayID())
    private var currentPoint: CGPoint?
    private var isPinched = false

    init(dryRun: Bool) {
        self.mouse = MouseDriver(dryRun: dryRun)
    }

    func start() throws {
        printStartupText()

        source.onFrame = { [weak self] tips, timestampMs in
            self?.processFingertips(tips, timestampMs: timestampMs)
        }
        source.onHands = { [weak self] hands, timestampMs in
            self?.processHands(hands, timestampMs: timestampMs)
        }

        try source.start()
        RunLoop.main.run()
    }

    private func processFingertips(_ tips: [RawFingertip], timestampMs: Double) {
        let tracked = tracker.update(tips, timestampMs: timestampMs)
        tracker.prune(olderThanMs: 500, nowMs: timestampMs)

        guard let index = tracked.first(where: { $0.id == rightIndexID }) else { return }
        let point = mapToDisplay(Point(x: index.x, y: index.y))
        currentPoint = point
        mouse.post(isPinched ? .leftDragged : .moved, at: point)
    }

    private func processHands(_ hands: [RawHand], timestampMs: Double) {
        let rightHands = hands.filter { $0.hand == .right }
        for event in pinch.process(rightHands, timestampMs: timestampMs) {
            switch event {
            case let .pinchBegan(hand, at):
                guard hand == .right else { continue }
                let point = currentPoint ?? mapToDisplay(at)
                currentPoint = point
                isPinched = true
                mouse.post(.leftDown, at: point)

            case let .pinchMoved(hand, at):
                guard hand == .right else { continue }
                let point = currentPoint ?? mapToDisplay(at)
                currentPoint = point
                mouse.post(.leftDragged, at: point)

            case let .pinchEnded(hand, at):
                guard hand == .right else { continue }
                let point = currentPoint ?? mapToDisplay(at)
                currentPoint = point
                isPinched = false
                mouse.post(.leftUp, at: point)
            }
        }
    }

    private func mapToDisplay(_ point: Point) -> CGPoint {
        let x = Self.normalize(point.x)
        let y = Self.normalize(point.y)
        return CGPoint(
            x: displayBounds.minX + x * displayBounds.width,
            y: displayBounds.minY + y * displayBounds.height
        )
    }

    private static func normalize(_ value: Double) -> Double {
        min(1, max(0, (value - cameraMin) / (cameraMax - cameraMin)))
    }

    private func printStartupText() {
        print("""
        AirCursor
        Requires camera permission and Accessibility permission for the invoking terminal.
        Right-hand index fingertip moves the cursor.
        Right-hand thumb-index pinch sends left mouse down, drag, and up.
        Camera region x,y in [0.15, 0.85] maps to the full main display.
        Ctrl+C to quit.
        """)
    }
}

@main
private enum AirCursorMain {
    static func main() {
        let dryRun = CommandLine.arguments.dropFirst().contains("--dry-run")
        do {
            let app = AirCursor(dryRun: dryRun)
            try app.start()
        } catch {
            fputs("aircursor error: \(error)\n", stderr)
            exit(1)
        }
    }
}
#else
@main
private enum AirCursorMain {
    static func main() {
        print("aircursor is macOS-only")
    }
}
#endif
