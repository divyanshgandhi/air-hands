public enum EngagementEvent: Equatable, Sendable {
    case engaged
    case disengaged
}

public struct EngagementConfig: Sendable {
    public var holdMs: Double
    public var lostGraceMs: Double

    public init(holdMs: Double = 300, lostGraceMs: Double = 120) {
        self.holdMs = holdMs
        self.lostGraceMs = lostGraceMs
    }
}

public final class EngagementDetector {
    public private(set) var isEngaged = false
    private let config: EngagementConfig
    private var candidateSinceMs: Double?
    private var poseMustClear = false
    private var lastHandsMs: Double?

    public init(config: EngagementConfig = EngagementConfig()) {
        self.config = config
    }

    public func process(_ hands: [RawHand], timestampMs: Double) -> [EngagementEvent] {
        if !hands.isEmpty { lastHandsMs = timestampMs }
        let hasPose = hands.count >= 2 && hands.allSatisfy(Self.isOpenPalm)

        if poseMustClear {
            if !hasPose {
                poseMustClear = false
                candidateSinceMs = nil
            }
            return lostHandsIfNeeded(hands, timestampMs: timestampMs)
        }

        guard hasPose else {
            candidateSinceMs = nil
            return lostHandsIfNeeded(hands, timestampMs: timestampMs)
        }

        guard let since = candidateSinceMs else {
            candidateSinceMs = timestampMs
            return []
        }
        guard timestampMs - since >= config.holdMs else { return [] }

        isEngaged.toggle()
        poseMustClear = true
        candidateSinceMs = nil
        return [isEngaged ? .engaged : .disengaged]
    }

    public func forceDisengage() -> [EngagementEvent] {
        candidateSinceMs = nil
        poseMustClear = false
        guard isEngaged else { return [] }
        isEngaged = false
        return [.disengaged]
    }

    private func lostHandsIfNeeded(_ hands: [RawHand], timestampMs: Double) -> [EngagementEvent] {
        guard isEngaged, hands.isEmpty, let lastHandsMs,
              timestampMs - lastHandsMs > config.lostGraceMs else { return [] }
        return forceDisengage()
    }

    private static func isOpenPalm(_ hand: RawHand) -> Bool {
        let fingers: [(HandJoint, HandJoint)] = [
            (.indexPIP, .indexTip), (.middlePIP, .middleTip),
            (.ringPIP, .ringTip), (.littlePIP, .littleTip),
        ]
        return fingers.allSatisfy { pip, tip in
            guard let pipPoint = hand.joints[pip], let tipPoint = hand.joints[tip] else { return false }
            return tipPoint.y < pipPoint.y
        }
    }
}
