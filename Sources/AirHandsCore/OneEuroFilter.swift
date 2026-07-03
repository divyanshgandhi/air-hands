import Foundation

// One Euro filter (Casiez, Roussel, Vogel — CHI 2012).
// Adaptive low-pass: smooth when slow, responsive when fast.

public struct OneEuroParams: Codable, Sendable {
    public var minCutoff: Double
    public var beta: Double
    public var dCutoff: Double

    public init(minCutoff: Double = 0.5, beta: Double = 0.6, dCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }

    /// Tuned for normalized [0,1] coordinates where hand speeds run ~0.5–3 units/s.
    public static let `default` = OneEuroParams()
}

private func smoothingFactor(cutoff: Double, dtSec: Double) -> Double {
    let tau = 1 / (2 * Double.pi * cutoff)
    return 1 / (1 + tau / dtSec)
}

public final class OneEuroFilter {
    private let params: OneEuroParams
    private var prev: Double?
    private var prevDeriv: Double = 0
    private var prevTimeMs: Double?

    public init(params: OneEuroParams = .default) {
        self.params = params
    }

    public func filter(_ value: Double, timestampMs: Double) -> Double {
        guard let prev, let prevTimeMs, timestampMs > prevTimeMs else {
            self.prev = value
            self.prevDeriv = 0
            self.prevTimeMs = timestampMs
            return value
        }

        let dtSec = (timestampMs - prevTimeMs) / 1000
        let rawDeriv = (value - prev) / dtSec
        let alphaD = smoothingFactor(cutoff: params.dCutoff, dtSec: dtSec)
        let deriv = prevDeriv + alphaD * (rawDeriv - prevDeriv)

        let cutoff = params.minCutoff + params.beta * abs(deriv)
        let alpha = smoothingFactor(cutoff: cutoff, dtSec: dtSec)
        let filtered = prev + alpha * (value - prev)

        self.prev = filtered
        self.prevDeriv = deriv
        self.prevTimeMs = timestampMs
        return filtered
    }

    public func reset() {
        prev = nil
        prevDeriv = 0
        prevTimeMs = nil
    }
}
