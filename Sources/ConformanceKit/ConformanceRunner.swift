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
}
