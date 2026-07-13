public enum InteractionEvent: Equatable, Sendable {
    case engagementChanged(Bool)
    case pointerMoved(Point)
    case grabBegan(Point), grabMoved(Point), grabEnded(Point)
    case scroll(delta: Point)
    case zoom(scaleDelta: Double)
    case switchWorkspace(direction: Int)
    case overview(Bool)
    case minimizeSelected
    case dismissSelected
    case cancelled
}

public final class IntentArbiter {
    private let engagement: EngagementDetector
    private let gestures = TrackpadGestureRecognizer()

    public init(engagementConfig: EngagementConfig = EngagementConfig()) {
        engagement = EngagementDetector(config: engagementConfig)
    }

    public func process(hands: [RawHand], timestampMs: Double) -> [InteractionEvent] {
        let engagementEvents = engagement.process(hands, timestampMs: timestampMs)
        if let event = engagementEvents.first {
            _ = gestures.cancel()
            return [.engagementChanged(event == .engaged)]
        }
        guard engagement.isEngaged else { return [] }
        return gestures.process(hands).map(Self.map)
    }

    public func cancel() -> [InteractionEvent] {
        var events = gestures.cancel().map(Self.map)
        if !engagement.forceDisengage().isEmpty { events.append(.engagementChanged(false)) }
        events.append(.cancelled)
        return events
    }

    private static func map(_ event: TrackpadGestureEvent) -> InteractionEvent {
        switch event {
        case let .pointerMoved(point): return .pointerMoved(point)
        case let .grabBegan(point): return .grabBegan(point)
        case let .grabMoved(point): return .grabMoved(point)
        case let .grabEnded(point): return .grabEnded(point)
        case let .scroll(delta): return .scroll(delta: delta)
        case let .zoom(scale): return .zoom(scaleDelta: scale)
        case let .switchWorkspace(direction): return .switchWorkspace(direction: direction)
        case let .overview(active): return .overview(active)
        case .minimizeSelected: return .minimizeSelected
        case .dismissSelected: return .dismissSelected
        }
    }
}
