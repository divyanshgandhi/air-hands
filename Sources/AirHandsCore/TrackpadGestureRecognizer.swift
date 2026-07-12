import Foundation

public enum TrackpadGestureEvent: Equatable, Sendable {
    case pointerMoved(Point)
    case grabBegan(Point), grabMoved(Point), grabEnded(Point)
    case scroll(delta: Point)
    case zoom(scaleDelta: Double)
    case switchWorkspace(direction: Int)
    case overview(Bool)
}

public final class TrackpadGestureRecognizer {
    private var previousCenter: Point?
    private var previousSpread: Double?
    private var isGrabbing = false
    private var overviewActive = false

    public init() {}

    public func process(_ hands: [RawHand]) -> [TrackpadGestureEvent] {
        guard let hand = hands.first(where: { $0.hand == .right }) ?? hands.first,
              let index = hand.joints[.indexTip] else {
            return endGrabIfNeeded()
        }

        if isPinched(hand) {
            previousCenter = index
            if isGrabbing { return [.grabMoved(index)] }
            isGrabbing = true
            return [.grabBegan(index)]
        }
        if isGrabbing {
            isGrabbing = false
            previousCenter = index
            return [.grabEnded(index)]
        }

        let extended = extendedFingers(hand)
        if extended >= 4 {
            previousCenter = index
            guard !overviewActive else { return [] }
            overviewActive = true
            return [.overview(true)]
        }
        if overviewActive {
            overviewActive = false
            return [.overview(false)]
        }

        let center = fingerCenter(hand) ?? index
        defer { previousCenter = center; previousSpread = fingerSpread(hand) }
        guard let previousCenter else { return [.pointerMoved(index)] }
        let delta = Point(x: center.x - previousCenter.x, y: center.y - previousCenter.y)

        if extended == 3, abs(delta.x) > 0.03 {
            return [.switchWorkspace(direction: delta.x > 0 ? 1 : -1)]
        }
        if extended == 2 {
            if let spread = fingerSpread(hand), let previousSpread,
               abs(spread - previousSpread) > 0.02 {
                return [.zoom(scaleDelta: spread / max(previousSpread, 0.001))]
            }
            return [.scroll(delta: delta)]
        }
        return [.pointerMoved(index)]
    }

    public func cancel() -> [TrackpadGestureEvent] {
        defer {
            isGrabbing = false
            previousCenter = nil
            previousSpread = nil
            overviewActive = false
        }
        return endGrabIfNeeded()
    }

    private func endGrabIfNeeded() -> [TrackpadGestureEvent] {
        guard isGrabbing else { return [] }
        isGrabbing = false
        return [.grabEnded(previousCenter ?? Point(x: 0.5, y: 0.5))]
    }

    private func isPinched(_ hand: RawHand) -> Bool {
        guard let thumb = hand.joints[.thumbTip], let index = hand.joints[.indexTip] else { return false }
        return hypot(thumb.x - index.x, thumb.y - index.y) / max(hand.handScale ?? 0.25, 0.001) < 0.35
    }

    private func extendedFingers(_ hand: RawHand) -> Int {
        let pairs: [(HandJoint, HandJoint)] = [
            (.indexPIP, .indexTip), (.middlePIP, .middleTip),
            (.ringPIP, .ringTip), (.littlePIP, .littleTip),
        ]
        return pairs.reduce(0) { count, pair in
            guard let pip = hand.joints[pair.0], let tip = hand.joints[pair.1] else { return count }
            return count + (tip.y < pip.y ? 1 : 0)
        }
    }

    private func fingerCenter(_ hand: RawHand) -> Point? {
        let points = [hand.joints[.indexTip], hand.joints[.middleTip]].compactMap { $0 }
        guard !points.isEmpty else { return nil }
        return Point(x: points.map(\.x).reduce(0, +) / Double(points.count),
                     y: points.map(\.y).reduce(0, +) / Double(points.count))
    }

    private func fingerSpread(_ hand: RawHand) -> Double? {
        guard let index = hand.joints[.indexTip], let middle = hand.joints[.middleTip] else { return nil }
        return hypot(index.x - middle.x, index.y - middle.y)
    }
}
