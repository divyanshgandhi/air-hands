// Velocity is noisier than position; a fixed low-pass keeps strikes detectable
// without letting single-frame spikes through.
private let velocityAlpha = 0.5

public final class FingertipTracker {
    private struct Entry {
        let fx: OneEuroFilter
        let fy: OneEuroFilter
        var state: TrackedFinger
        var hasPrev: Bool
        var prevX: Double
        var prevY: Double
        var prevTimeMs: Double
    }

    private let params: OneEuroParams
    private var fingers: [String: Entry] = [:]
    private var order: [String] = []

    public init(params: OneEuroParams = .default) {
        self.params = params
    }

    public func update(_ tips: [RawFingertip], timestampMs: Double) -> [TrackedFinger] {
        for tip in tips {
            let id = tip.id
            var entry = fingers[id] ?? {
                order.append(id)
                return Entry(
                    fx: OneEuroFilter(params: params),
                    fy: OneEuroFilter(params: params),
                    state: TrackedFinger(id: id, x: tip.x, y: tip.y, vx: 0, vy: 0, lastSeenMs: timestampMs),
                    hasPrev: false,
                    prevX: 0,
                    prevY: 0,
                    prevTimeMs: timestampMs
                )
            }()

            let x = entry.fx.filter(tip.x, timestampMs: timestampMs)
            let y = entry.fy.filter(tip.y, timestampMs: timestampMs)

            // Velocity comes from RAW positions: deriving it from the filtered ones
            // stacks two lags and under-reads fast strikes.
            if entry.hasPrev && timestampMs > entry.prevTimeMs {
                let dtSec = (timestampMs - entry.prevTimeMs) / 1000
                let rawVx = (tip.x - entry.prevX) / dtSec
                let rawVy = (tip.y - entry.prevY) / dtSec
                entry.state.vx += velocityAlpha * (rawVx - entry.state.vx)
                entry.state.vy += velocityAlpha * (rawVy - entry.state.vy)
            }

            entry.state.x = x
            entry.state.y = y
            entry.state.lastSeenMs = timestampMs
            entry.prevX = tip.x
            entry.prevY = tip.y
            entry.prevTimeMs = timestampMs
            entry.hasPrev = true
            fingers[id] = entry
        }

        return order.compactMap { fingers[$0]?.state }
    }

    public func prune(olderThanMs: Double, nowMs: Double) {
        for (id, entry) in fingers where nowMs - entry.state.lastSeenMs > olderThanMs {
            fingers.removeValue(forKey: id)
        }
        order.removeAll { fingers[$0] == nil }
    }
}
