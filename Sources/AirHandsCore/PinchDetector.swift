import Foundation

public struct PinchConfig: Codable, Equatable, Sendable {
    public var beginThreshold: Double
    public var endThreshold: Double
    public var minHoldMs: Double
    public var fallbackHandScale: Double

    public init(
        beginThreshold: Double = 0.35,
        endThreshold: Double = 0.55,
        minHoldMs: Double = 40,
        fallbackHandScale: Double = 0.25
    ) {
        self.beginThreshold = beginThreshold
        self.endThreshold = endThreshold
        self.minHoldMs = minHoldMs
        self.fallbackHandScale = fallbackHandScale
    }

    public static let `default` = PinchConfig()
}

public enum PinchEvent: Equatable, Sendable {
    case pinchBegan(hand: Hand, at: Point)
    case pinchMoved(hand: Hand, at: Point)
    case pinchEnded(hand: Hand, at: Point)
}

public final class PinchDetector {
    private enum Phase {
        case idle
        case candidate(sinceMs: Double)
        case active
    }

    private struct HandState {
        let fx: OneEuroFilter
        let fy: OneEuroFilter
        var phase: Phase = .idle
        var lastPoint: Point?
    }

    private let config: PinchConfig
    private var states: [Hand: HandState] = [:]

    public init(config: PinchConfig = .default) {
        self.config = config
    }

    public func process(_ hands: [RawHand], timestampMs: Double) -> [PinchEvent] {
        var events: [PinchEvent] = []

        for hand in hands {
            guard let sample = Self.pinchSample(for: hand, fallbackHandScale: config.fallbackHandScale) else {
                continue
            }

            var state = states[hand.hand] ?? HandState(
                fx: OneEuroFilter(),
                fy: OneEuroFilter()
            )
            let point = Point(
                x: state.fx.filter(sample.midpoint.x, timestampMs: timestampMs),
                y: state.fy.filter(sample.midpoint.y, timestampMs: timestampMs)
            )
            state.lastPoint = point

            switch state.phase {
            case .idle:
                if sample.strength <= config.beginThreshold {
                    state.phase = .candidate(sinceMs: timestampMs)
                    if config.minHoldMs <= 0 {
                        state.phase = .active
                        events.append(.pinchBegan(hand: hand.hand, at: point))
                    }
                }

            case let .candidate(sinceMs):
                if sample.strength > config.beginThreshold {
                    state.phase = .idle
                } else if timestampMs - sinceMs >= config.minHoldMs {
                    state.phase = .active
                    events.append(.pinchBegan(hand: hand.hand, at: point))
                }

            case .active:
                if sample.strength >= config.endThreshold {
                    state.phase = .idle
                    events.append(.pinchEnded(hand: hand.hand, at: point))
                } else {
                    events.append(.pinchMoved(hand: hand.hand, at: point))
                }
            }

            states[hand.hand] = state
        }

        return events
    }

    public func reset() {
        states.removeAll()
    }

    private static func pinchSample(
        for hand: RawHand,
        fallbackHandScale: Double
    ) -> (midpoint: Point, strength: Double)? {
        guard
            let thumb = hand.fingertips.first(where: { $0.finger == .thumb }),
            let index = hand.fingertips.first(where: { $0.finger == .index })
        else {
            return nil
        }

        let midpoint = Point(x: (thumb.x + index.x) / 2, y: (thumb.y + index.y) / 2)
        let distance = hypot(thumb.x - index.x, thumb.y - index.y)
        let scale = hand.handScale.flatMap { $0 > 0 && $0.isFinite ? $0 : nil }
            ?? fallbackHandScale
        return (midpoint, distance / scale)
    }
}
