import AirHandsCore
import Foundation

// Replays golden vectors exported from the TypeScript reference implementation
// (air-music/scripts/export-gesture-vectors.ts). Every port must reproduce
// these event streams exactly — this suite IS the definition of "the feel".

public struct ConformanceFailure: CustomStringConvertible, Sendable {
    public let scenario: String
    public let detail: String

    public var description: String { "\(scenario): \(detail)" }
}

struct VectorFrame: Decodable {
    let t: Double
    let fingers: [TrackedFinger]
}

struct ExpectedEvent: Decodable {
    let frame: Int
    let kind: String
    let zoneId: String
    let fingerId: String
    let velocity: Double?
}

struct FsmScenario: Decodable {
    let name: String
    let config: GestureConfig
    let zones: [Zone]
    let frames: [VectorFrame]
    let expected: [ExpectedEvent]
}

struct StrumScenario: Decodable {
    let name: String
    let config: StrumConfig
    let zones: [Zone]
    let frames: [VectorFrame]
    let expected: [ExpectedEvent]
}

struct EuroSample: Decodable {
    let t: Double
    let v: Double
}

struct EuroScenario: Decodable {
    let name: String
    let params: OneEuroParams
    let samples: [EuroSample]
    let expected: [Double]
}

struct EmittedEvent {
    let frame: Int
    let kind: String
    let zoneId: String
    let fingerId: String
    let velocity: Double?
}

private func collect(_ event: GestureEvent, frame: Int) -> EmittedEvent {
    switch event {
    case let .strike(zoneId, velocity, fingerId):
        return EmittedEvent(frame: frame, kind: "strike", zoneId: zoneId, fingerId: fingerId, velocity: velocity)
    case let .release(zoneId, fingerId):
        return EmittedEvent(frame: frame, kind: "release", zoneId: zoneId, fingerId: fingerId, velocity: nil)
    }
}

private func sortKey(_ frame: Int, _ fingerId: String, _ zoneId: String) -> String {
    String(format: "%06d|%@|%@", frame, fingerId, zoneId)
}

private func compare(
    _ emitted: [EmittedEvent], _ expected: [ExpectedEvent], scenario: String,
    into failures: inout [ConformanceFailure]
) {
    let sorted = emitted.sorted {
        sortKey($0.frame, $0.fingerId, $0.zoneId) < sortKey($1.frame, $1.fingerId, $1.zoneId)
    }
    guard sorted.count == expected.count else {
        failures.append(
            ConformanceFailure(
                scenario: scenario,
                detail: "expected \(expected.count) events, got \(sorted.count)"
            ))
        return
    }
    for (got, want) in zip(sorted, expected) {
        var mismatches: [String] = []
        if got.frame != want.frame { mismatches.append("frame \(got.frame) != \(want.frame)") }
        if got.kind != want.kind { mismatches.append("kind \(got.kind) != \(want.kind)") }
        if got.zoneId != want.zoneId { mismatches.append("zone \(got.zoneId) != \(want.zoneId)") }
        if got.fingerId != want.fingerId {
            mismatches.append("finger \(got.fingerId) != \(want.fingerId)")
        }
        if let wantVelocity = want.velocity {
            if let gotVelocity = got.velocity {
                if abs(gotVelocity - wantVelocity) >= 1e-9 {
                    mismatches.append("velocity \(gotVelocity) != \(wantVelocity)")
                }
            } else {
                mismatches.append("missing velocity")
            }
        }
        if !mismatches.isEmpty {
            failures.append(
                ConformanceFailure(scenario: scenario, detail: mismatches.joined(separator: "; ")))
        }
    }
}

public enum ConformanceRunner {
    /// Runs all vector suites found in `vectorsDir`. Empty result = full conformance.
    public static func runAll(vectorsDir: URL) throws -> [ConformanceFailure] {
        var failures: [ConformanceFailure] = []
        let decoder = JSONDecoder()

        func load<T: Decodable>(_ file: String) throws -> [T] {
            let url = vectorsDir.appendingPathComponent("\(file).json")
            return try decoder.decode([T].self, from: Data(contentsOf: url))
        }

        let fsmScenarios: [FsmScenario] = try load("strike-fsm")
        for scenario in fsmScenarios {
            let fsm = StrikeFSM(zones: ZoneIndex(scenario.zones), config: scenario.config)
            var emitted: [EmittedEvent] = []
            for (index, frame) in scenario.frames.enumerated() {
                for event in fsm.processFrame(frame.fingers, nowMs: frame.t) {
                    emitted.append(collect(event, frame: index))
                }
            }
            compare(emitted, scenario.expected, scenario: "strike-fsm/\(scenario.name)", into: &failures)
        }

        let strumScenarios: [StrumScenario] = try load("strum")
        for scenario in strumScenarios {
            let strum = StrumDetector(zones: ZoneIndex(scenario.zones), config: scenario.config)
            var emitted: [EmittedEvent] = []
            for (index, frame) in scenario.frames.enumerated() {
                for event in strum.processFrame(frame.fingers, nowMs: frame.t) {
                    emitted.append(collect(event, frame: index))
                }
            }
            compare(emitted, scenario.expected, scenario: "strum/\(scenario.name)", into: &failures)
        }

        let euroScenarios: [EuroScenario] = try load("one-euro")
        for scenario in euroScenarios {
            let filter = OneEuroFilter(params: scenario.params)
            for (index, pair) in zip(scenario.samples, scenario.expected).enumerated() {
                let got = filter.filter(pair.0.v, timestampMs: pair.0.t)
                if abs(got - pair.1) >= 1e-12 {
                    failures.append(
                        ConformanceFailure(
                            scenario: "one-euro/\(scenario.name)",
                            detail: "sample \(index): \(got) != \(pair.1)"
                        ))
                }
            }
        }

        let total = fsmScenarios.count + strumScenarios.count + euroScenarios.count
        print("ran \(total) scenarios (\(fsmScenarios.count) fsm, \(strumScenarios.count) strum, \(euroScenarios.count) one-euro)")
        return failures
    }

    /// Runs pure Swift smoke tests for APIs that are not part of the TypeScript golden vectors.
    public static func runSelfTests() -> [ConformanceFailure] {
        let scenarios: [(String, () -> String?)] = [
            ("pinch begin/end hysteresis", testPinchHysteresis),
            ("pinch begin debounce", testPinchDebounce),
            ("pinch scale normalization", testPinchScaleNormalization),
            ("raw hand session plumbing", testRawHandSessionPlumbing),
        ]

        var failures: [ConformanceFailure] = []
        for (name, test) in scenarios {
            if let detail = test() {
                print("self-test/\(name): FAIL — \(detail)")
                failures.append(ConformanceFailure(scenario: "self-test/\(name)", detail: detail))
            } else {
                print("self-test/\(name): PASS")
            }
        }
        print("ran \(scenarios.count) self-test scenarios")
        return failures
    }
}

private func rawHand(
    _ hand: Hand = .right,
    thumb: Point,
    index: Point,
    handScale: Double? = 1
) -> RawHand {
    RawHand(
        hand: hand,
        fingertips: [
            RawFingertip(x: thumb.x, y: thumb.y, hand: hand, finger: .thumb),
            RawFingertip(x: index.x, y: index.y, hand: hand, finger: .index),
        ],
        palmCenter: Point(x: 0.5, y: 0.6),
        handScale: handScale
    )
}

private func eventKind(_ event: PinchEvent) -> String {
    switch event {
    case .pinchBegan: return "began"
    case .pinchMoved: return "moved"
    case .pinchEnded: return "ended"
    }
}

private func requireKinds(_ got: [PinchEvent], _ expected: [String]) -> String? {
    let kinds = got.map(eventKind)
    return kinds == expected ? nil : "expected events \(expected), got \(kinds)"
}

private func testPinchHysteresis() -> String? {
    let detector = PinchDetector()
    var events: [PinchEvent] = []

    events += detector.process(
        [rawHand(thumb: Point(x: 0, y: 0.5), index: Point(x: 0.3, y: 0.5))],
        timestampMs: 0
    )
    if let failure = requireKinds(events, []) { return "t0: \(failure)" }

    events = detector.process(
        [rawHand(thumb: Point(x: 0, y: 0.5), index: Point(x: 0.3, y: 0.5))],
        timestampMs: 40
    )
    if let failure = requireKinds(events, ["began"]) { return "t40: \(failure)" }

    events = detector.process(
        [rawHand(thumb: Point(x: 0, y: 0.5), index: Point(x: 0.45, y: 0.5))],
        timestampMs: 80
    )
    if let failure = requireKinds(events, ["moved"]) { return "t80: \(failure)" }

    events = detector.process(
        [rawHand(thumb: Point(x: 0, y: 0.5), index: Point(x: 0.56, y: 0.5))],
        timestampMs: 120
    )
    if let failure = requireKinds(events, ["ended"]) { return "t120: \(failure)" }

    return nil
}

private func testPinchDebounce() -> String? {
    let detector = PinchDetector()
    let pinched = rawHand(thumb: Point(x: 0, y: 0.5), index: Point(x: 0.3, y: 0.5))
    let open = rawHand(thumb: Point(x: 0, y: 0.5), index: Point(x: 0.4, y: 0.5))

    if let failure = requireKinds(detector.process([pinched], timestampMs: 0), []) {
        return "t0: \(failure)"
    }
    if let failure = requireKinds(detector.process([pinched], timestampMs: 39), []) {
        return "t39: \(failure)"
    }
    if let failure = requireKinds(detector.process([open], timestampMs: 50), []) {
        return "t50 reset: \(failure)"
    }
    if let failure = requireKinds(detector.process([pinched], timestampMs: 100), []) {
        return "t100: \(failure)"
    }
    if let failure = requireKinds(detector.process([pinched], timestampMs: 140), ["began"]) {
        return "t140: \(failure)"
    }

    return nil
}

private func testPinchScaleNormalization() -> String? {
    let config = PinchConfig(minHoldMs: 0)
    let fullScale = PinchDetector(config: config)
    let halfScale = PinchDetector(config: config)

    let fullEvents = fullScale.process(
        [rawHand(thumb: Point(x: 0, y: 0.5), index: Point(x: 0.1, y: 0.5), handScale: 0.3)],
        timestampMs: 0
    )
    if let failure = requireKinds(fullEvents, ["began"]) {
        return "full scale: \(failure)"
    }

    let halfEvents = halfScale.process(
        [rawHand(thumb: Point(x: 0, y: 0.5), index: Point(x: 0.05, y: 0.5), handScale: 0.15)],
        timestampMs: 0
    )
    if let failure = requireKinds(halfEvents, ["began"]) {
        return "half scale: \(failure)"
    }

    return nil
}

private final class SelfTestHandSource: HandFrameSource {
    var onFrame: (([RawFingertip], Double) -> Void)?
    var onHands: (([RawHand], Double) -> Void)?
    let hands: [RawHand]

    init(hands: [RawHand]) {
        self.hands = hands
    }

    func start() throws {
        onFrame?(hands.flatMap(\.fingertips), 123)
        onHands?(hands, 123)
    }

    func stop() {}
}

private func testRawHandSessionPlumbing() -> String? {
    let expected = rawHand(
        thumb: Point(x: 0.1, y: 0.2),
        index: Point(x: 0.2, y: 0.2),
        handScale: 0.4
    )
    let source = SelfTestHandSource(hands: [expected])
    let session = GestureSession(source: source, zones: [])
    var received: ([RawHand], Double)?
    session.onHands = { hands, timestampMs in
        received = (hands, timestampMs)
    }

    do {
        try session.start()
    } catch {
        return "start threw \(error)"
    }

    guard let received else {
        return "session did not forward onHands"
    }
    guard received.1 == 123 else {
        return "expected timestamp 123, got \(received.1)"
    }
    guard received.0.count == 1 else {
        return "expected 1 hand, got \(received.0.count)"
    }
    guard received.0[0].hand == expected.hand,
          received.0[0].palmCenter == expected.palmCenter,
          received.0[0].handScale == expected.handScale,
          received.0[0].fingertips.count == expected.fingertips.count
    else {
        return "forwarded RawHand did not match source frame"
    }

    return nil
}
