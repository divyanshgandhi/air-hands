// Standard test entry point for environments with Xcode. Command Line
// Tools-only machines have neither XCTest nor Swift Testing — use
// `swift run airhands-conformance` there instead; it runs the same suite.
#if canImport(Testing)
import AirHandsCore
import Foundation
import Testing

@testable import ConformanceKit

@Test func engineMatchesTypeScriptReference() throws {
    let vectors = try #require(
        Bundle.module.url(forResource: "Vectors", withExtension: nil),
        "missing bundled vectors"
    )
    let failures = try ConformanceRunner.runAll(vectorsDir: vectors)
    #expect(failures.isEmpty, "\(failures)")
}

@Test func pointerSelfTestsPass() {
    let failures = ConformanceRunner.runSelfTests()
    #expect(failures.isEmpty, "\(failures)")
}

@Test func pinchDetectorDebouncesAndEndsWithHysteresis() {
    let detector = PinchDetector()
    #expect(detector.process([testHand(distance: 0.3)], timestampMs: 0).isEmpty)
    #expect(detector.process([testHand(distance: 0.3)], timestampMs: 39).isEmpty)

    let began = detector.process([testHand(distance: 0.3)], timestampMs: 40)
    #expect(began.count == 1)
    if let first = began.first, case .pinchBegan(hand: .right, at: _) = first {
        #expect(true)
    } else {
        #expect(Bool(false), "expected pinchBegan, got \(began)")
    }

    let moved = detector.process([testHand(distance: 0.45)], timestampMs: 80)
    #expect(moved.count == 1)
    if let first = moved.first, case .pinchMoved(hand: .right, at: _) = first {
        #expect(true)
    } else {
        #expect(Bool(false), "expected pinchMoved, got \(moved)")
    }

    let ended = detector.process([testHand(distance: 0.55)], timestampMs: 120)
    #expect(ended.count == 1)
    if let first = ended.first, case .pinchEnded(hand: .right, at: _) = first {
        #expect(true)
    } else {
        #expect(Bool(false), "expected pinchEnded, got \(ended)")
    }
}

private func testHand(distance: Double, scale: Double = 1) -> RawHand {
    RawHand(
        hand: .right,
        fingertips: [
            RawFingertip(x: 0.2, y: 0.5, hand: .right, finger: .thumb),
            RawFingertip(x: 0.2 + distance, y: 0.5, hand: .right, finger: .index),
        ],
        palmCenter: Point(x: 0.4, y: 0.6),
        handScale: scale
    )
}
#endif
