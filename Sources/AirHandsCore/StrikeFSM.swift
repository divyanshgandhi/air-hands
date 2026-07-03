private let minVelocity = 0.15

private func fingerType(_ fingerId: String) -> FingerID? {
    let parts = fingerId.split(separator: "-")
    guard parts.count >= 2 else { return nil }
    return FingerID(rawValue: String(parts[1]))
}

/// Per-finger strike detection. Consumes TrackedFinger frames, emits
/// strike/release events. A note fires only on a downward-velocity gesture —
/// hovering or sweeping across zones is silent.
public final class StrikeFSM {
    private struct Phase {
        var isHeld: Bool
        var zoneId: String
        var peakVy: Double
        var startMs: Double
        var heldSinceMs: Double
        var lastSeenMs: Double
    }

    private let zones: ZoneIndex
    /// Mutable for live tuning; applies from the next frame.
    public var config: GestureConfig
    private var phases: [String: Phase] = [:]

    public init(zones: ZoneIndex, config: GestureConfig) {
        self.zones = zones
        self.config = config
    }

    public func processFrame(_ fingers: [TrackedFinger], nowMs: Double) -> [GestureEvent] {
        var events: [GestureEvent] = []
        let cfg = config
        var seen = Set<String>()

        for finger in fingers {
            if let allowed = cfg.fingers {
                guard let type = fingerType(finger.id), allowed.contains(type) else { continue }
            }
            seen.insert(finger.id)
            let point = Point(x: finger.x, y: finger.y)

            guard var phase = phases[finger.id] else {
                // IDLE → DESCENT
                if finger.vy > cfg.strikeVelocity, let zone = zones.zoneAt(point) {
                    phases[finger.id] = Phase(
                        isHeld: false,
                        zoneId: zone.id,
                        peakVy: finger.vy,
                        startMs: nowMs,
                        heldSinceMs: 0,
                        lastSeenMs: finger.lastSeenMs
                    )
                }
                continue
            }

            phase.lastSeenMs = finger.lastSeenMs

            if !phase.isHeld {
                if !zones.contains(phase.zoneId, point, inflateBy: cfg.hysteresisMargin) {
                    // Drifted off the target mid-descent — abort silently.
                    phases.removeValue(forKey: finger.id)
                    continue
                }
                phase.peakVy = max(phase.peakVy, finger.vy)
                let decelerated = finger.vy < phase.peakVy / 2
                let timedOut = nowMs - phase.startMs > cfg.maxDescentMs
                if decelerated || timedOut {
                    let velocity = min(1, max(minVelocity, phase.peakVy / cfg.vMax))
                    events.append(.strike(zoneId: phase.zoneId, velocity: velocity, fingerId: finger.id))
                    phase.isHeld = true
                    phase.heldSinceMs = nowMs
                }
                phases[finger.id] = phase
                continue
            }

            // HELD → release?
            let flickedUp = finger.vy < -cfg.releaseVelocity
            let leftZone = !zones.contains(phase.zoneId, point, inflateBy: cfg.hysteresisMargin)
            let autoReleased = cfg.autoReleaseMs.map { nowMs - phase.heldSinceMs > $0 } ?? false
            if flickedUp || leftZone || autoReleased {
                events.append(.release(zoneId: phase.zoneId, fingerId: finger.id))
                phases.removeValue(forKey: finger.id)
            } else {
                phases[finger.id] = phase
            }
        }

        // Fingers with active phases that vanished from the frame.
        for (fingerId, phase) in phases where !seen.contains(fingerId) {
            if !phase.isHeld {
                phases.removeValue(forKey: fingerId) // never struck — nothing to release
                continue
            }
            let lostForMs = nowMs - phase.lastSeenMs
            let autoReleased = config.autoReleaseMs.map { nowMs - phase.heldSinceMs > $0 } ?? false
            if lostForMs > config.lostGraceMs || autoReleased {
                events.append(.release(zoneId: phase.zoneId, fingerId: fingerId))
                phases.removeValue(forKey: fingerId)
            }
        }

        return events
    }

    public func reset() {
        phases.removeAll()
    }

    public func heldZones() -> Set<String> {
        Set(phases.values.filter(\.isHeld).map(\.zoneId))
    }
}
