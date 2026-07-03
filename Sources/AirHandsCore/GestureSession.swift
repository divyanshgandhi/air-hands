/// How much strike-confirmation latency to trade for stability.
public enum LatencyProfile: Sendable {
    /// Lowest latency: less smoothing, strikes confirm fast. May jitter.
    case crisp
    /// The reference tuning from air-music.
    case balanced
    /// Steadiest cursor, laziest strikes.
    case stable

    var filterParams: OneEuroParams {
        switch self {
        case .crisp: return OneEuroParams(minCutoff: 1.0, beta: 0.8, dCutoff: 1.0)
        case .balanced: return .default
        case .stable: return OneEuroParams(minCutoff: 0.3, beta: 0.5, dCutoff: 1.0)
        }
    }

    func apply(to config: inout GestureConfig) {
        switch self {
        case .crisp: config.maxDescentMs = 110
        case .balanced: break
        case .stable: config.maxDescentMs = 220
        }
    }
}

/// Plug-and-play pipeline: a HandPoseSource in, gesture events out.
///
/// ```swift
/// let session = GestureSession(
///     source: VisionHandPoseSource(),
///     zones: myZones,
///     config: .keys,
///     profile: .crisp
/// )
/// session.onEvent = { event in ... }
/// try session.start()
/// ```
public final class GestureSession {
    public var onEvent: ((GestureEvent) -> Void)?
    /// Filtered fingertips each frame, for cursors/visual feedback.
    public var onFingers: (([TrackedFinger]) -> Void)?

    private let source: HandPoseSource
    private let tracker: FingertipTracker
    private let fsm: StrikeFSM
    private let strum: StrumDetector?
    private let pruneMs: Double = 500

    public init(
        source: HandPoseSource,
        zones: [Zone],
        config: GestureConfig = .keys,
        strumConfig: StrumConfig? = nil,
        profile: LatencyProfile = .balanced
    ) {
        var tuned = config
        profile.apply(to: &tuned)
        let index = ZoneIndex(zones)
        self.source = source
        self.tracker = FingertipTracker(params: profile.filterParams)
        self.fsm = StrikeFSM(zones: index, config: tuned)
        self.strum = strumConfig.map { StrumDetector(zones: index, config: $0) }

        source.onFrame = { [weak self] tips, tsMs in
            self?.process(tips, tsMs: tsMs)
        }
    }

    public func start() throws {
        try source.start()
    }

    public func stop() {
        source.stop()
        fsm.reset()
        strum?.reset()
    }

    private func process(_ tips: [RawFingertip], tsMs: Double) {
        let tracked = tracker.update(tips, timestampMs: tsMs)
        tracker.prune(olderThanMs: pruneMs, nowMs: tsMs)
        onFingers?(tracked)

        for event in fsm.processFrame(tracked, nowMs: tsMs) {
            onEvent?(event)
        }
        if let strum {
            for event in strum.processFrame(tracked, nowMs: tsMs) {
                onEvent?(event)
            }
        }
    }
}
