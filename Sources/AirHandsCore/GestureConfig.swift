public struct GestureConfig: Codable, Sendable {
    /// Downward speed (units/s) that starts a DESCENT.
    public var strikeVelocity: Double
    /// Descent speed mapped to velocity 1.0.
    public var vMax: Double
    /// Upward speed (units/s) that releases a held note.
    public var releaseVelocity: Double
    /// Zone rect inflation (fraction of size) for the exit test.
    public var hysteresisMargin: Double
    /// Keep a held note alive this long after the finger is lost.
    public var lostGraceMs: Double
    /// A descent this old fires its strike even without deceleration.
    public var maxDescentMs: Double
    /// Auto-release held notes after this long (percussion); nil = sustain.
    public var autoReleaseMs: Double?
    /// Only these fingers can play; nil = all ten.
    public var fingers: [FingerID]?

    public init(
        strikeVelocity: Double = 0.5,
        vMax: Double = 3.0,
        releaseVelocity: Double = 0.3,
        hysteresisMargin: Double = 0.15,
        lostGraceMs: Double = 120,
        maxDescentMs: Double = 180,
        autoReleaseMs: Double? = nil,
        fingers: [FingerID]? = nil
    ) {
        self.strikeVelocity = strikeVelocity
        self.vMax = vMax
        self.releaseVelocity = releaseVelocity
        self.hysteresisMargin = hysteresisMargin
        self.lostGraceMs = lostGraceMs
        self.maxDescentMs = maxDescentMs
        self.autoReleaseMs = autoReleaseMs
        self.fingers = fingers
    }

    /// Sustained keys — the piano profile from the reference implementation.
    public static let keys = GestureConfig()

    /// Percussion — stricter strike threshold, index+middle only, auto-release.
    public static let percussion = GestureConfig(
        strikeVelocity: 0.9,
        autoReleaseMs: 150,
        fingers: [.index, .middle]
    )
}
