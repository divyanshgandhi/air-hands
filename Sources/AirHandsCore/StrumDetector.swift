public struct StrumConfig: Codable, Sendable {
    /// |vx| (units/s) that starts a strum.
    public var strumVelocity: Double
    /// |vx| mapped to velocity 1.0.
    public var vMax: Double
    /// Per finger+zone retrigger guard.
    public var cooldownMs: Double

    public init(strumVelocity: Double = 1.2, vMax: Double = 4, cooldownMs: Double = 80) {
        self.strumVelocity = strumVelocity
        self.vMax = vMax
        self.cooldownMs = cooldownMs
    }

    /// The koto profile from the reference implementation.
    public static let strings = StrumConfig()
}

private let exitRatio = 0.6
private let minVelocity = 0.15

/// Sweep-to-glissando. The StrikeFSM deliberately ignores horizontal motion;
/// this detector makes a FAST horizontal sweep a second deliberate gesture:
/// every zone the finger crosses is struck, velocity ∝ sweep speed.
/// Slow drift stays silent — hover never plays.
public final class StrumDetector {
    private struct FingerStrum {
        var strumming = false
        var lastZoneId: String?
        var lastHitMs: [String: Double] = [:]
    }

    private let zones: ZoneIndex
    /// Mutable for live tuning; applies from the next frame.
    public var config: StrumConfig
    private var fingers: [String: FingerStrum] = [:]

    public init(zones: ZoneIndex, config: StrumConfig) {
        self.zones = zones
        self.config = config
    }

    public func processFrame(_ frame: [TrackedFinger], nowMs: Double) -> [GestureEvent] {
        var events: [GestureEvent] = []
        var seen = Set<String>()

        for finger in frame {
            seen.insert(finger.id)
            var state = fingers[finger.id] ?? FingerStrum()

            let speed = abs(finger.vx)
            if !state.strumming && speed >= config.strumVelocity {
                state.strumming = true
            } else if state.strumming && speed < config.strumVelocity * exitRatio {
                state.strumming = false
                state.lastZoneId = nil
            }
            guard state.strumming else {
                fingers[finger.id] = state
                continue
            }

            guard let zone = zones.zoneAt(Point(x: finger.x, y: finger.y)),
                  zone.id != state.lastZoneId
            else {
                fingers[finger.id] = state
                continue
            }
            state.lastZoneId = zone.id

            if let lastHit = state.lastHitMs[zone.id], nowMs - lastHit < config.cooldownMs {
                fingers[finger.id] = state
                continue
            }
            state.lastHitMs[zone.id] = nowMs
            fingers[finger.id] = state

            let velocity = min(1, max(minVelocity, speed / config.vMax))
            events.append(.strike(zoneId: zone.id, velocity: velocity, fingerId: finger.id))
        }

        for id in fingers.keys where !seen.contains(id) {
            fingers.removeValue(forKey: id)
        }

        return events
    }

    public func reset() {
        fingers.removeAll()
    }
}
