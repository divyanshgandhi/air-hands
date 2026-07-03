public enum Hand: String, Codable, Sendable {
    case left, right
}

public enum FingerID: String, Codable, Sendable, CaseIterable {
    case thumb, index, middle, ring, pinky
}

/// Fingertip in normalized [0,1] camera-or-zone space.
public struct RawFingertip: Sendable {
    public var x: Double
    public var y: Double
    public var hand: Hand
    public var finger: FingerID

    public init(x: Double, y: Double, hand: Hand, finger: FingerID) {
        self.x = x
        self.y = y
        self.hand = hand
        self.finger = finger
    }

    public var id: String { "\(hand.rawValue)-\(finger.rawValue)" }
}

public struct Point: Codable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct Rect: Codable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct TrackedFinger: Codable, Sendable {
    /// "hand-finger", e.g. "right-index".
    public var id: String
    public var x: Double
    public var y: Double
    /// Normalized units per second; positive vy = downward.
    public var vx: Double
    public var vy: Double
    public var lastSeenMs: Double

    public init(id: String, x: Double, y: Double, vx: Double, vy: Double, lastSeenMs: Double) {
        self.id = id
        self.x = x
        self.y = y
        self.vx = vx
        self.vy = vy
        self.lastSeenMs = lastSeenMs
    }
}

public enum GestureEvent: Equatable, Sendable {
    case strike(zoneId: String, velocity: Double, fingerId: String)
    case release(zoneId: String, fingerId: String)
}

/// Platform adapters (Vision, ARKit, MediaPipe, …) implement this.
public protocol HandPoseSource: AnyObject {
    /// Normalized, mirrored-for-the-user fingertips plus a monotonic timestamp.
    var onFrame: (([RawFingertip], _ timestampMs: Double) -> Void)? { get set }
    func start() throws
    func stop()
}
